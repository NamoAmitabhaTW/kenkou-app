import Flutter
import UIKit
import AVFoundation

/// 相機預覽。直接讓 UIView 的 backing layer 就是 AVCaptureVideoPreviewLayer,
/// 不必自己搬影格到 Flutter texture — 預覽這條路完全不經過 Dart。
final class PreviewUIView: UIView {

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    private var connectionConfigured = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        previewLayer.session = CameraSession.shared.session
        previewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // connection 要等 session 真的開始設定後才拿得到,所以在這裡補上而不是 init。
        guard !connectionConfigured, let connection = previewLayer.connection else { return }
        CameraSession.applyPortrait(to: connection)
        // 預覽鏡像:使用者看到的是照鏡子的自己,不然做嘴型時左右相反很不直覺。
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        connectionConfigured = true
    }
}

final class PreviewPlatformView: NSObject, FlutterPlatformView {
    private let previewView: PreviewUIView

    init(frame: CGRect) {
        previewView = PreviewUIView(frame: frame)
        super.init()
    }

    func view() -> UIView { previewView }
}

final class PreviewViewFactory: NSObject, FlutterPlatformViewFactory {
    func create(withFrame frame: CGRect,
                viewIdentifier viewId: Int64,
                arguments args: Any?) -> FlutterPlatformView {
        return PreviewPlatformView(frame: frame)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
