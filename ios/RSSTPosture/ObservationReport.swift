import CoreText
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.jpeg, .pdf]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ObservationReport {
    var company = ""
    var job = ""
    var task = ""
    var load = ""
    var frequency = ""
    var notes = ""

    func pdf(image: UIImage, view: String, measures: [Measure], masked: Bool) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 40
        let textWidth = page.width - 2 * margin
        let scale = min(textWidth / image.size.width, 340 / image.size.height)
        let imageSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let details = NSMutableAttributedString(string: "")

        func append(_ text: String, bold: Bool = false) {
            details.append(NSAttributedString(string: text, attributes: [
                .font: bold ? UIFont.boldSystemFont(ofSize: 12) : UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.black
            ]))
        }

        append("Entreprise : \(company)\nPoste : \(job)\nTâche : \(task)\nVue : \(view)\n")
        append("Mosaïque : \(masked ? "activée" : "désactivée")\n\n")
        append("Mesures\n", bold: true)
        for measure in measures { append("\(measure.title) : \(measure.display)\n") }
        append("\nCharge et effort : \(load)\nFréquence : \(frequency)\n\n")
        append("Observations\n", bold: true)
        append("\(notes)\n\n")
        append("Angles projetés en 2D. Repères indicatifs inspirés de RULA (McAtamney et Corlett, 1993). "
               + "Gris : segment non évalué. Le masquage automatique peut manquer un visage.\n\nwww.rsst.fr")

        let framesetter = CTFramesetterCreateWithAttributedString(details as CFAttributedString)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { renderer in
            var offset = 0
            repeat {
                renderer.beginPage()
                let firstPage = offset == 0
                let title = firstPage ? "RSST Posture · Rapport d’observation" : "RSST Posture · Rapport (suite)"
                (title as NSString).draw(at: CGPoint(x: margin, y: margin), withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 19), .foregroundColor: UIColor.black
                ])
                var top = margin + 36
                if firstPage {
                    image.draw(in: CGRect(x: (page.width - imageSize.width) / 2, y: top,
                                          width: imageSize.width, height: imageSize.height))
                    top += imageSize.height + 20
                }
                let context = renderer.cgContext
                context.saveGState()
                context.translateBy(x: 0, y: page.height)
                context.scaleBy(x: 1, y: -1)
                context.textMatrix = .identity
                let textBounds = CGRect(x: margin, y: margin, width: textWidth, height: page.height - top - margin)
                let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0),
                                                     CGPath(rect: textBounds, transform: nil), nil)
                CTFrameDraw(frame, context)
                context.restoreGState()
                let length = CTFrameGetVisibleStringRange(frame).length
                guard length > 0 else { break }
                offset += length
            } while offset < details.length
        }
    }
}
