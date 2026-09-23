import AVFoundation

final class CameraSession: NSObject {

    static let shared = CameraSession()

    let session = AVCaptureSession()

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "face_mesh.session")
    private let bufferQueue = DispatchQueue(label: "face_mesh.buffer")
    private var configured = false

    var onFrame: ((CMSampleBuffer) -> Void)?

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

    private func configure() -> String? {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

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
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }

        return nil
    }

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
