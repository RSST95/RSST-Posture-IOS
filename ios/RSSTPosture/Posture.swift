
import UIKit
import CoreImage
import Vision

typealias Joint = VNHumanBodyPoseObservation.JointName

struct Frame {
    let image: CGImage
    let joints: [Joint: VNRecognizedPoint]
    let faces: [CGRect]

    var bounds: CGRect {
        CGRect(x: 0, y: 0, width: image.width, height: image.height)
    }

    func point(_ joint: Joint) -> CGPoint? {
        guard let point = joints[joint], point.confidence >= 0.65 else { return nil }
        return CGPoint(x: point.location.x * bounds.width, y: point.location.y * bounds.height)
    }

    static func analyze(_ image: CGImage) throws -> Frame {
        let body = VNDetectHumanBodyPoseRequest()
        let face = VNDetectFaceRectanglesRequest()
        try VNImageRequestHandler(cgImage: image).perform([body, face])
        let poses = try (body.results ?? []).map { try $0.recognizedPoints(.all) }
        let joints = poses.max {
            $0.values.filter { $0.confidence >= 0.65 }.count <
            $1.values.filter { $0.confidence >= 0.65 }.count
        } ?? [:]
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        let observations: [VNFaceObservation] = face.results ?? []
        var faces: [CGRect] = observations.map { observation in
            let box = observation.boundingBox
            let dx: CGFloat = -(box.width * 0.18)
            let dy: CGFloat = -(box.height * 0.23)
            let expandedBox = box.insetBy(dx: dx, dy: dy)
            return expandedBox.intersection(unit)
        }
        if let nose = joints[.nose], nose.confidence >= 0.65,
           !faces.contains(where: { $0.contains(nose.location) }),
           let neck = joints[.neck], neck.confidence >= 0.65 {
            let height = max(0.08, abs(neck.location.y - nose.location.y) * 2.3)
            let width = height * CGFloat(image.height) / CGFloat(image.width) * 0.88
            faces.append(CGRect(x: nose.location.x - width / 2, y: nose.location.y - height * 0.42,
                                width: width, height: height).intersection(unit))
        }
        return Frame(image: image, joints: joints, faces: faces)
    }
}

struct Measure {
    let title: String
    let angle: Double?
    let level: Int
    let segment: (Joint, Joint)

    var display: String {
        angle.map { String(format: "%.0f°", $0) } ?? "Non mesuré"
    }

    var color: UIColor {
        [.systemGreen, .systemYellow, .systemOrange, .systemRed, .systemGray][level]
    }
}

func angle(_ a: CGPoint?, _ vertex: CGPoint?, _ c: CGPoint?) -> Double? {
    guard let a, let vertex, let c else { return nil }
    let ux = Double(a.x - vertex.x)
    let uy = Double(a.y - vertex.y)
    let vx = Double(c.x - vertex.x)
    let vy = Double(c.y - vertex.y)
    let norm = hypot(ux, uy) * hypot(vx, vy)
    guard norm > 1e-8 else { return nil }
    return acos(min(1, max(-1, (ux * vx + uy * vy) / norm))) * 180 / .pi
}

func measures(_ frame: Frame, profile: Bool, left: Bool) -> [Measure] {
    func arm(_ left: Bool, title: String) -> Measure {
        let hip: Joint = left ? .leftHip : .rightHip
        let shoulder: Joint = left ? .leftShoulder : .rightShoulder
        let elbow: Joint = left ? .leftElbow : .rightElbow
        let value = angle(frame.point(hip), frame.point(shoulder), frame.point(elbow))
        return Measure(title: title, angle: value,
                       level: value.map { angle in [20.0, 45, 90].filter { angle > $0 }.count } ?? 4,
                       segment: (shoulder, elbow))
    }
    if !profile {
        return [arm(true, title: "Bras gauche · Élévation latérale projetée"),
                arm(false, title: "Bras droit · Élévation latérale projetée")]
    }
    let hip: Joint = left ? .leftHip : .rightHip
    let shoulder: Joint = left ? .leftShoulder : .rightShoulder
    let elbow: Joint = left ? .leftElbow : .rightElbow
    let wrist: Joint = left ? .leftWrist : .rightWrist
    let vertical = frame.point(hip).map { CGPoint(x: $0.x, y: $0.y + frame.bounds.height) }
    let trunk = angle(frame.point(shoulder), frame.point(hip), vertical)
    let bend = angle(frame.point(shoulder), frame.point(elbow), frame.point(wrist))
    return [
        Measure(title: "Tronc · Inclinaison projetée", angle: trunk,
                level: trunk.map { value in [10.0, 20, 60].filter { value > $0 }.count } ?? 4,
                segment: (shoulder, hip)),
        arm(left, title: "Bras · Angle avec le tronc"),
        Measure(title: "Coude · Angle interne", angle: bend,
                level: bend.map { (60.0...100.0).contains($0) ? 0 : 2 } ?? 4, segment: (elbow, wrist))
    ]
}

let imageContext = CIContext()

func annotated(_ frame: Frame, masks: [CGRect], blocks: Int, values: [Measure]) -> CGImage? {
    guard let context = CGContext(data: nil, width: frame.image.width, height: frame.image.height,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    context.draw(frame.image, in: frame.bounds)
    let original = CIImage(cgImage: frame.image)
    for mask in masks {
        let rect = CGRect(x: mask.minX * frame.bounds.width, y: mask.minY * frame.bounds.height,
                          width: mask.width * frame.bounds.width, height: mask.height * frame.bounds.height)
            .integral.intersection(frame.bounds)
        guard rect.width > 0, rect.height > 0 else { continue }
        let filtered = original.applyingFilter("CIPixellate", parameters: [
            kCIInputScaleKey: max(2, max(rect.width, rect.height) / CGFloat(blocks)),
            kCIInputCenterKey: CIVector(x: rect.midX, y: rect.midY)
        ])
        guard let tile = imageContext.createCGImage(filtered, from: rect) else {
            context.setFillColor(UIColor.black.cgColor)
            context.fill(rect)
            continue
        }
        context.draw(tile, in: rect)
    }
    let bones: [(Joint, Joint)] = [
        (.leftShoulder, .rightShoulder), (.leftHip, .rightHip),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftShoulder, .leftElbow), (.rightShoulder, .rightElbow),
        (.leftElbow, .leftWrist), (.rightElbow, .rightWrist),
        (.leftHip, .leftKnee), (.rightHip, .rightKnee),
        (.leftKnee, .leftAnkle), (.rightKnee, .rightAnkle)
    ]
    context.setLineWidth(max(3, frame.bounds.width / 210))
    context.setLineCap(.round)
    for (a, b) in bones {
        guard let start = frame.point(a), let end = frame.point(b) else { continue }
        let color = values.first {
            ($0.segment.0 == a && $0.segment.1 == b) || ($0.segment.0 == b && $0.segment.1 == a)
        }?.color ?? .systemGray
        context.setStrokeColor(color.cgColor)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
    }
    return context.makeImage()
}


