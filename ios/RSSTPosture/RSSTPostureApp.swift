import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@main
struct RSSTPostureApp: App {
    var body: some Scene {
        WindowGroup { PostureView() }
    }
}

private struct PostureView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = Camera()
    @State private var live = false
    @State private var capture: Frame?
    @State private var photo: PhotosPickerItem?
    @State private var masks: [CGRect] = []
    @State private var selectedMask: Int?
    @State private var dragOrigin: CGRect?
    @State private var profile = true
    @State private var left = true
    @State private var privacy = true
    @State private var blocks = 10
    @State private var reviewed = false
    @State private var report = ObservationReport()
    @State private var errorMessage: String?
    @State private var exportedDocument: ExportDocument?
    @State private var exportType: UTType = .jpeg
    @State private var exporting = false

    private var frame: Frame? { live ? camera.frame : capture }
    private var values: [Measure] { frame.map { measures($0, profile: profile, left: left) } ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label("Importer une photo", systemImage: "photo")
                    }
                    Button(live ? "Arrêter la caméra" : "Démarrer la caméra",
                           systemImage: live ? "stop.circle" : "camera") {
                        if live {
                            stopCamera()
                        } else {
                            photo = nil
                            live = true
                            camera.start()
                        }
                    }
                    if live {
                        Button("Capturer", systemImage: "camera.shutter.button") {
                            if let frame = camera.frame { setCapture(frame) }
                        }
                        .disabled(camera.frame == nil)
                        Text(camera.status).foregroundStyle(.secondary)
                    }
                    if let frame {
                        preview(frame)
                    }
                } header: {
                    if let logo = UIImage(named: "logo_rsst") {
                        Image(uiImage: logo).resizable().scaledToFit()
                            .frame(maxWidth: 125, maxHeight: 38)
                            .accessibilityHidden(true)
                    }
                }
                Section("Mesures") {
                    Picker("Vue", selection: $profile) {
                        Text("Profil").tag(true)
                        Text("Face / Dos").tag(false)
                    }
                    if profile {
                        Picker("Côté", selection: $left) {
                            Text("Gauche").tag(true)
                            Text("Droit").tag(false)
                        }
                    }
                    ForEach(values, id: \.title) { measure in
                        HStack {
                            Circle().fill(Color(uiColor: measure.color)).frame(width: 10, height: 10)
                            Text(measure.title)
                            Spacer()
                            Text(measure.display).monospacedDigit()
                        }
                    }
                    Text("Angles projetés en 2D. Repères indicatifs inspirés de RULA.")
                        .font(.footnote)
                }
                Section("Masquage des visages") {
                    Toggle("Appliquer la mosaïque", isOn: $privacy)
                    if privacy {
                        Picker("Mosaïque", selection: $blocks) {
                            Text("Fin").tag(14)
                            Text("Moyen").tag(10)
                            Text("Fort").tag(6)
                        }
                        if let capture, !live { maskControls(capture) }
                    }
                }
                if capture != nil && !live {
                    Section("Rapport d’observation") {
                        TextField("Entreprise", text: $report.company)
                        TextField("Poste de travail", text: $report.job)
                        TextField("Tâche observée", text: $report.task)
                        TextField("Charge et effort", text: $report.load)
                        TextField("Fréquence", text: $report.frequency)
                        TextField("Observations", text: $report.notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    Section("Export") {
                        Text("Vérifiez tous les visages sur la capture. La détection automatique peut en manquer.")
                            .font(.footnote)
                        Toggle("J’ai vérifié la capture", isOn: $reviewed)
                        Group {
                            Button("Exporter le JPG") { export(.jpeg) }
                            Button("Exporter le PDF") { export(.pdf) }
                        }
                        .disabled(!reviewed)
                        Button("Nouvelle analyse") {
                            capture = nil
                            photo = nil
                            masks = []
                            selectedMask = nil
                            reviewed = false
                            report = ObservationReport()
                        }
                    }
                }
            }
            .navigationTitle("RSST Posture")
        }
        .task(id: photo) {
            guard let photo else { return }
            await importPhoto(photo)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { stopCamera() }
        }
        .onChange(of: masks) { _, _ in reviewed = false }
        .onChange(of: privacy) { _, _ in reviewed = false }
        .onChange(of: blocks) { _, _ in reviewed = false }
        .onChange(of: profile) { _, _ in reviewed = false }
        .onChange(of: left) { _, _ in reviewed = false }
        .fileExporter(isPresented: $exporting, document: exportedDocument,
                      contentType: exportType, defaultFilename: "RSST-Posture") { result in
            exportedDocument = nil
            if case let .failure(error) = result { errorMessage = error.localizedDescription }
        }
        .alert("RSST Posture", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func preview(_ frame: Frame) -> some View {
        let activeMasks = privacy ? (live ? frame.faces : masks) : []
        if let image = annotated(frame, masks: activeMasks, blocks: blocks, values: values) {
            GeometryReader { geometry in
                let scale = min(geometry.size.width / CGFloat(image.width),
                                geometry.size.height / CGFloat(image.height))
                let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
                ZStack(alignment: .topLeading) {
                    Image(decorative: image, scale: 1).resizable()
                    if !live && privacy && size.width > 0 && size.height > 0 {
                        ForEach(masks.indices, id: \.self) { index in
                            let rect = masks[index]
                            Rectangle().fill(.clear)
                                .overlay(Rectangle().strokeBorder(selectedMask == index ? Color.orange : Color.white,
                                                                  lineWidth: 2))
                                .frame(width: rect.width * size.width, height: rect.height * size.height)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedMask = index }
                                .highPriorityGesture(DragGesture().onChanged { drag in
                                    guard masks.indices.contains(index) else { return }
                                    if dragOrigin == nil { dragOrigin = masks[index] }
                                    selectedMask = index
                                    if let start = dragOrigin {
                                        masks[index] = bounded(start.offsetBy(dx: drag.translation.width / size.width,
                                                                              dy: -drag.translation.height / size.height))
                                    }
                                }.onEnded { _ in dragOrigin = nil })
                                .position(x: rect.midX * size.width, y: (1 - rect.midY) * size.height)
                        }
                    }
                }
                .frame(width: size.width, height: size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 300)
            .background(.black)
            .accessibilityLabel("Aperçu de la posture")
        }
    }

    @ViewBuilder
    private func maskControls(_ capture: Frame) -> some View {
        Text("Touchez un cadre pour le sélectionner. Faites-le glisser pour le déplacer.")
            .font(.footnote)
        Button("Ajouter un masque") {
            masks.append(CGRect(x: 0.42, y: 0.42, width: 0.16, height: 0.16))
            selectedMask = masks.indices.last
        }
        if let index = selectedMask, masks.indices.contains(index) {
            Slider(value: Binding(get: {
                guard masks.indices.contains(index) else { return 0.02 }
                return Double(max(masks[index].width, masks[index].height))
            }, set: { value in
                guard masks.indices.contains(index) else { return }
                let rect = masks[index]
                let scale = CGFloat(value) / max(rect.width, rect.height)
                let width = rect.width * scale
                let height = rect.height * scale
                masks[index] = bounded(CGRect(x: rect.midX - width / 2, y: rect.midY - height / 2,
                                              width: width, height: height))
            }), in: 0.02...1) {
                Text("Taille du masque")
            }
            Button("Supprimer le masque sélectionné", role: .destructive) {
                selectedMask = nil
                if masks.indices.contains(index) { masks.remove(at: index) }
            }
        }
        Button("Rétablir les masques automatiques") {
            selectedMask = nil
            masks = capture.faces.filter { !$0.isEmpty }
        }
    }

    private func bounded(_ rect: CGRect) -> CGRect {
        CGRect(x: min(max(rect.minX, 0), 1 - rect.width), y: min(max(rect.minY, 0), 1 - rect.height),
               width: rect.width, height: rect.height)
    }

    private func stopCamera() {
        live = false
        camera.stop()
    }

    private func setCapture(_ frame: Frame) {
        stopCamera()
        capture = frame
        masks = frame.faces.filter { !$0.isEmpty }
        selectedMask = nil
        dragOrigin = nil
        reviewed = false
    }

    @MainActor
    private func importPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let frame = try await Task.detached(priority: .userInitiated) {
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: 2000
                      ] as CFDictionary) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                return try Frame.analyze(image)
            }.value
            guard !Task.isCancelled, photo == item else { return }
            photo = nil
            setCapture(frame)
        } catch {
            guard !Task.isCancelled, photo == item else { return }
            photo = nil
            errorMessage = "Impossible d’analyser la photo."
        }
    }

    private func export(_ type: UTType) {
        guard reviewed, !live, let capture,
              let image = annotated(capture, masks: privacy ? masks : [], blocks: blocks, values: values) else {
            errorMessage = "Impossible de préparer la capture."
            return
        }
        let uiImage = UIImage(cgImage: image)
        let view = profile ? (left ? "Profil gauche" : "Profil droit") : "Face / Dos"
        let data = type == .jpeg ? uiImage.jpegData(compressionQuality: 0.92)
            : report.pdf(image: uiImage, view: view, measures: values, masked: privacy)
        guard let data else {
            errorMessage = "Impossible de préparer le fichier."
            return
        }
        exportType = type
        exportedDocument = ExportDocument(data: data)
        exporting = true
    }
}
