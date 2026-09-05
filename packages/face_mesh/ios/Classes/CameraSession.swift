import AVFoundation

/// 單例:整個 app 共用一個 AVCaptureSession。
/// 偵測用的 video data output 與畫面預覽的 preview layer 都掛在同一條 session 上,
/// 避免兩者各自開一台相機(iOS 不允許,而且很耗電)。
final class CameraSession: NSObject {

    static let shared = CameraSession()

    let session = AVCaptureSession()

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "face_mesh.session")
    private let bufferQueue = DispatchQueue(label: "face_mesh.buffer")
    private var configured = false

    /// 每張影格會在 bufferQueue 上呼叫這個 closure(不是 main thread)。
    var onFrame: ((CMSampleBuffer) -> Void)?

    // MARK: - 生命週期

    func start(completion: @escaping (String?) -> Void) {
        requestPermission { granted in
            guard granted else {
                completion("使用者未授權相機權限")
                return
            }
            self.sessionQueue.async {
                if !self.configured {
                    if let error = self.configure() {
                        DispatchQueue.main.async { completion(error) }
                        return
                    }
                    self.configured = true
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func requestPermission(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    // MARK: - 設定

    private func configure() -> String? {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // 640x480 對 face mesh 綽綽有餘,解析度拉高只會白燒 CPU 跟電。
        session.sessionPreset = .vga640x480

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return "找不到可用的前鏡頭"
        }
        session.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: bufferQueue)

        guard session.canAddOutput(videoOutput) else {
            return "無法建立影像輸出"
        }
        session.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video) {
            Self.applyPortrait(to: connection)
            // 刻意「不」鏡像偵測用的影格:鏡像會把 blendshape 的左右語意對調。
            // 預覽層自己會鏡像,使用者看到的仍然是照鏡子的效果。
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }

        return nil
    }

    /// 讓輸出的影格已經是「直立」的,這樣送進 MediaPipe 時可以直接用 .up,
    /// 不必自己換算裝置方向與 EXIF orientation。
    static func applyPortrait(to connection: AVCaptureConnection) {
        if #available(iOS 17.0, *) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        onFrame?(sampleBuffer)
    }
}
