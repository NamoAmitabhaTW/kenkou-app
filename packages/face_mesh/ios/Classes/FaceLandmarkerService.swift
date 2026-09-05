import Foundation
import AVFoundation
import MediaPipeTasksVision

struct FaceFrame {
    var blendshapes: [String: Double]
    /// 嘴唇輪廓 + 臉寬錨點,交錯成 [x0,y0,x1,y1,...] 的正規化座標。
    /// 只送 42 個點而不是全部 478 個 — 畫嘴型提示用不到臉頰和額頭,
    /// 少送 436 個點就少一份每秒 30 次的序列化成本。
    var contour: [Float]
    /// 影格的像素尺寸。Dart 端要靠它把正規化座標換算回畫面座標。
    var imageWidth: Int
    var imageHeight: Int
    /// 頭部左右轉動,-1(轉向一側)~ 1,0 表示正對鏡頭。
    var yaw: Double
    /// 頭部傾斜角度。
    var rollDegrees: Double
    /// 以臉寬正規化過的嘴巴幾何,拿來跟 blendshape 互相驗證。
    var mouthOpenRatio: Double
    var mouthWidthRatio: Double
}

protocol FaceLandmarkerServiceDelegate: AnyObject {
    func faceLandmarkerService(_ service: FaceLandmarkerService, didProduce frame: FaceFrame?)
}

/// 包住 MediaPipe FaceLandmarker,只暴露「一張影格進、一個結果出」。
final class FaceLandmarkerService: NSObject {

    weak var delegate: FaceLandmarkerServiceDelegate?
    private var landmarker: FaceLandmarker?

    /// 只往 Dart 送嘴巴 / 下顎 / 臉頰相關的 blendshape。
    /// 健口操用不到眉毛和眼睛,少送 28 個 key 就少一份每秒 30 次的序列化成本。
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
        // 舌頭訓練要看舌頭有沒有伸出來。
        "tongueOut"
    ]

    /// MediaPipe canonical face mesh 的嘴唇輪廓索引,按照沿著輪廓的順序排列,
    /// 所以 Dart 端可以直接依序連線成封閉路徑。
    static let outerLip = [61, 146, 91, 181, 84, 17, 314, 405, 321, 375,
                           291, 409, 270, 269, 267, 0, 37, 39, 40, 185]
    static let innerLip = [78, 95, 88, 178, 87, 14, 317, 402, 318, 324,
                           308, 415, 310, 311, 312, 13, 82, 81, 80, 191]
    /// 左右臉緣,Dart 端用這兩點算臉寬來縮放目標框。
    static let faceEdges = [234, 454]

    /// 上臉頰(顴骨下方)的點。舌頭頂不到這裡,它只跟著頭轉動,
    /// 舌壓訓練拿它當「剛性參考」抵銷轉頭造成的左右不對稱。
    /// A 在影像的左半邊(x 較小),B 在右半邊;預覽是鏡像的,
    /// 哪一邊是使用者的左臉由 Dart 端依投影後的 x 決定,這裡不替它命名。
    static let upperCheekA = [50, 101, 118, 123, 147]
    static let upperCheekB = [280, 330, 347, 352, 376]

    /// 下臉頰(嘴角旁邊到下顎)的點,舌頭頂臉頰時鼓起來的就是這一帶。
    static let lowerCheekA = [187, 205, 206, 207, 213, 216, 212, 214, 210, 192]
    static let lowerCheekB = [411, 425, 426, 427, 433, 436, 432, 434, 430, 416]

    /// 錨點:鼻尖、鼻樑、下巴、耳前(A/B)、下顎線(A/B)。
    /// 唾液腺按摩與舌頭訓練用來在臉上標位置。
    static let anchors = [1, 6, 152, 93, 323, 172, 397]

    /// 臉部外輪廓在臉頰到下顎那一段的點。鼓頰時網格表面的點幾乎不動,
    /// 但輪廓線會往外撐,鼓頰要看這個。A 在影像左半邊、B 在右半邊。
    static let ovalA = [132, 58, 172, 136]
    static let ovalB = [361, 288, 397, 365]

    /// 送去 Dart 的順序。Dart 端 FaceFrame 的切片位置要跟這裡一致:
    ///   0..19 外唇、20..39 內唇、40..41 臉緣、42..46 upperA、47..51 upperB、
    ///   52..61 lowerA、62..71 lowerB、72..78 錨點、79..82 ovalA、83..86 ovalB
    static var contourIndices: [Int] {
        outerLip + innerLip + faceEdges + upperCheekA + upperCheekB + lowerCheekA + lowerCheekB + anchors + ovalA + ovalB
    }

    /// 幾組點的平均深度(z,單位跟 x 一樣是正規化座標,越小越靠近鏡頭)。
    /// 鼓頰時下臉頰會往鏡頭凸,上臉頰不會。順序:lowerA、lowerB、upperA、upperB。
    /// 影格尺寸在 detect 時記下來,landmarker 的 callback 拿不到原始 buffer。
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

    /// 非同步送檢。MediaPipe 要求 timestamp 嚴格遞增,晚到的影格它會自己丟掉。
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

// MARK: - 結果轉換

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

        // 正規化座標的 x 除以影像寬、y 除以影像高,兩個軸的單位不一樣。
        // 直接拿去算距離會讓垂直方向被系統性壓縮,所以先換算成同一套單位。
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

    // MARK: 幾何輔助
    //
    // 以下都用 landmark 直接算,刻意不動 facialTransformationMatrixes。
    // 頭部姿態在這裡只是「有沒有正對鏡頭」的閘門,不需要精確的歐拉角。

    /// 鼻尖到左右臉緣的水平距離差,正規化到 -1 ~ 1。
    private static func yaw(_ pts: [NormalizedLandmark]) -> Double {
        let nose = Double(pts[1].x)
        let leftEdge = Double(pts[234].x)
        let rightEdge = Double(pts[454].x)
        let span = rightEdge - leftEdge
        guard abs(span) > 1e-6 else { return 0 }
        // 正對鏡頭時鼻尖落在正中央 → 0
        return ((nose - leftEdge) - (rightEdge - nose)) / span
    }

    /// 兩眼外眼角連線的傾角。
    private static func rollDegrees(_ pts: [NormalizedLandmark], _ aspect: Double) -> Double {
        let dx = Double(pts[263].x - pts[33].x)
        let dy = Double(pts[263].y - pts[33].y) * aspect
        return atan2(dy, dx) * 180 / .pi
    }

    /// 兩點距離除以臉寬。除掉臉寬之後,使用者離鏡頭遠近就不會影響數值。
    ///
    /// 回傳的是真正的幾何比例(以臉寬為單位),Dart 端可以直接乘上
    /// 畫面上的臉寬像素數,得到目標框該有多大。
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
