import Foundation
import AVFoundation
import MediaPipeTasksVision

struct FaceFrame {
    var blendshapes: [String: Double]
    var contour: [Float]
    var imageWidth: Int
    var imageHeight: Int
    var yaw: Double
    var rollDegrees: Double
    var mouthOpenRatio: Double
    var mouthWidthRatio: Double
}

protocol FaceLandmarkerServiceDelegate: AnyObject {
    func faceLandmarkerService(_ service: FaceLandmarkerService, didProduce frame: FaceFrame?)
}

final class FaceLandmarkerService: NSObject {

    weak var delegate: FaceLandmarkerServiceDelegate?
    private var landmarker: FaceLandmarker?

    private static let mouthKeys: Set<String> = [
        "jawOpen", "jawForward", "jawLeft", "jawRight",
        "mouthClose", "mouthFunnel", "mouthPucker",
        "mouthLeft", "mouthRight",
        "mouthSmileLeft", "mouthSmileRight",
        "mouthFrownLeft", "mouthFrownRight",
        "mouthDimpleLeft", "mouthDimpleRight",
        "mouthStretchLeft", "mouthStretchRight",
        "mouthRollLower", "mouthRollUpper",
        "mouthShrugLower", "mouthShrugUpper",
        "mouthPressLeft", "mouthPressRight",
        "mouthLowerDownLeft", "mouthLowerDownRight",
        "mouthUpperUpLeft", "mouthUpperUpRight",
        "cheekPuff", "cheekSquintLeft", "cheekSquintRight",
        "tongueOut"
    ]

    static let outerLip = [61, 146, 91, 181, 84, 17, 314, 405, 321, 375,
                           291, 409, 270, 269, 267, 0, 37, 39, 40, 185]
    static let innerLip = [78, 95, 88, 178, 87, 14, 317, 402, 318, 324,
                           308, 415, 310, 311, 312, 13, 82, 81, 80, 191]
    static let faceEdges = [234, 454]

    static let upperCheekA = [50, 101, 118, 123, 147]
    static let upperCheekB = [280, 330, 347, 352, 376]

    static let lowerCheekA = [187, 205, 206, 207, 213, 216, 212, 214, 210, 192]
    static let lowerCheekB = [411, 425, 426, 427, 433, 436, 432, 434, 430, 416]

    static let anchors = [1, 6, 152, 93, 323, 172, 397]

    static let ovalA = [132, 58, 172, 136]
    static let ovalB = [361, 288, 397, 365]

    static var contourIndices: [Int] {
        outerLip + innerLip + faceEdges + upperCheekA + upperCheekB + lowerCheekA + lowerCheekB + anchors + ovalA + ovalB
    }

    private var imageWidth = 0
    private var imageHeight = 0

    init?(modelPath: String) {
        super.init()

        let options = FaceLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .liveStream
        options.numFaces = 1
        options.outputFaceBlendshapes = true
        options.minFaceDetectionConfidence = 0.5
        options.minFacePresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5
        options.faceLandmarkerLiveStreamDelegate = self

        do {
            landmarker = try FaceLandmarker(options: options)
        } catch {
            NSLog("[face_mesh] FaceLandmarker 建立失敗: \(error)")
            return nil
        }
    }

    func detect(sampleBuffer: CMSampleBuffer, timestampMs: Int) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            imageWidth = CVPixelBufferGetWidth(pixelBuffer)
            imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        }
        guard let landmarker = landmarker,
              let image = try? MPImage(sampleBuffer: sampleBuffer) else { return }
        try? landmarker.detectAsync(image: image, timestampInMilliseconds: timestampMs)
    }
}

extension FaceLandmarkerService: FaceLandmarkerLiveStreamDelegate {

    func faceLandmarker(_ faceLandmarker: FaceLandmarker,
                        didFinishDetection result: FaceLandmarkerResult?,
                        timestampInMilliseconds: Int,
                        error: Error?) {

        guard let result = result,
              let landmarks = result.faceLandmarks.first,
              landmarks.count > 454 else {
            delegate?.faceLandmarkerService(self, didProduce: nil)
            return
        }

        var shapes: [String: Double] = [:]
        if let categories = result.faceBlendshapes.first?.categories {
            for category in categories {
                guard let name = category.categoryName,
                      Self.mouthKeys.contains(name) else { continue }
                shapes[name] = Double(category.score)
            }
        }

        var contour = [Float]()
        contour.reserveCapacity(Self.contourIndices.count * 2)
        for index in Self.contourIndices {
            contour.append(landmarks[index].x)
            contour.append(landmarks[index].y)
        }

        let aspect = imageWidth > 0 ? Double(imageHeight) / Double(imageWidth) : 1.0

        let frame = FaceFrame(blendshapes: shapes,
                              contour: contour,
                              imageWidth: imageWidth,
                              imageHeight: imageHeight,
                              yaw: Self.yaw(landmarks),
                              rollDegrees: Self.rollDegrees(landmarks, aspect),
                              mouthOpenRatio: Self.ratio(landmarks, 13, 14, aspect),
                              mouthWidthRatio: Self.ratio(landmarks, 61, 291, aspect))

        delegate?.faceLandmarkerService(self, didProduce: frame)
    }

    private static func yaw(_ pts: [NormalizedLandmark]) -> Double {
        let nose = Double(pts[1].x)
        let leftEdge = Double(pts[234].x)
        let rightEdge = Double(pts[454].x)
        let span = rightEdge - leftEdge
        guard abs(span) > 1e-6 else { return 0 }
        return ((nose - leftEdge) - (rightEdge - nose)) / span
    }

    private static func rollDegrees(_ pts: [NormalizedLandmark], _ aspect: Double) -> Double {
        let dx = Double(pts[263].x - pts[33].x)
        let dy = Double(pts[263].y - pts[33].y) * aspect
        return atan2(dy, dx) * 180 / .pi
    }

    private static func ratio(_ pts: [NormalizedLandmark], _ a: Int, _ b: Int, _ aspect: Double) -> Double {
        let faceWidth = distance(pts, 234, 454, aspect)
        guard faceWidth > 1e-6 else { return 0 }
        return distance(pts, a, b, aspect) / faceWidth
    }

    private static func distance(_ pts: [NormalizedLandmark], _ a: Int, _ b: Int, _ aspect: Double) -> Double {
        let dx = Double(pts[a].x - pts[b].x)
        let dy = Double(pts[a].y - pts[b].y) * aspect
        return (dx * dx + dy * dy).squareRoot()
    }
}
