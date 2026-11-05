import AVFoundation
import Combine
import CoreImage

final class Camera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var frame: Frame?
    @Published private(set) var status = ""

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "fr.rsst.posture.ios.camera")
    private var configured = false
    private var activeToken: UUID? // Camera queue only.
    private var requestedToken: UUID? // Main queue only.
    private var lastFrameTime: TimeInterval = 0

    func start() {
        let token = UUID()
        requestedToken = token
        frame = nil
        status = "Ouverture de la caméra…"
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self, self.requestedToken == token else { return }
                guard granted else {
                    self.status = "Autorisez l’accès à la caméra dans les réglages de l’iPhone."
                    return
                }
                self.queue.async { self.startSession(token: token) }
            }
        }
    }

    func stop() {
        requestedToken = nil
        frame = nil
        queue.async {
            self.activeToken = nil
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func startSession(token: UUID) {
        if !configured {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                publish(nil, status: "Caméra arrière indisponible. Essayez avec une photo.", token: token)
                return
            }
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            session.beginConfiguration()
            guard session.canAddInput(input), session.canAddOutput(output) else {
                session.commitConfiguration()
                publish(nil, status: "Impossible de configurer la caméra.", token: token)
                return
            }
            session.sessionPreset = .high
            session.addInput(input)
            session.addOutput(output)
            if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            output.setSampleBufferDelegate(self, queue: queue)
            session.commitConfiguration()
            configured = true
        }
        activeToken = token
        lastFrameTime = 0
        if !session.isRunning { session.startRunning() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sample: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        guard let token = activeToken, now - lastFrameTime >= 0.22,
              let buffer = CMSampleBufferGetImageBuffer(sample) else { return }
        lastFrameTime = now
        let input = CIImage(cvPixelBuffer: buffer)
        guard let image = imageContext.createCGImage(input, from: input.extent) else { return }
        do {
            let result = try Frame.analyze(image)
            let status = result.joints.isEmpty ? "Cadrez la personne en entier." : "Posture détectée."
            publish(result, status: status, token: token)
        } catch {
            publish(nil, status: "Analyse indisponible. Réessayez ou importez une photo.", token: token)
        }
    }

    private func publish(_ frame: Frame?, status: String, token: UUID) {
        DispatchQueue.main.async {
            guard self.requestedToken == token else { return }
            self.frame = frame
            self.status = status
        }
    }
}
