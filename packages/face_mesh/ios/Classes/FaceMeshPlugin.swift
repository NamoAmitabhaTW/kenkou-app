import Flutter
import UIKit
import AVFoundation

public class FaceMeshPlugin: NSObject, FlutterPlugin {

    private var eventSink: FlutterEventSink?
    private var service: FaceLandmarkerService?
    private var running = false
    /// 目前這一輪是不是有跑臉部偵測。
    /// 兩種模式共用同一台相機,切換模式時必須先關掉再重開,
    /// 否則從 preview-only 切回偵測模式會因為 running 已經是 true 而跳過模型初始化。
    private var detecting = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FaceMeshPlugin()

        // MethodChannel:一次性的指令(開始 / 停止)。
        let methodChannel = FlutterMethodChannel(name: "face_mesh/method",
                                                 binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        // EventChannel:原生端持續推的偵測結果串流。
        let eventChannel = FlutterEventChannel(name: "face_mesh/events",
                                               binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)

        registrar.register(PreviewViewFactory(), withId: "face_mesh/preview")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            // detect = false 只開相機預覽,不載入 MediaPipe。
            // 快問快答只需要看得到自己,跑臉部偵測是白燒 CPU 跟電。
            let detect = (call.arguments as? [String: Any])?["detect"] as? Bool ?? true
            start(detect: detect, result: result)
        case "stop":
            stop()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - 啟動 / 停止

    private func start(detect: Bool, result: @escaping FlutterResult) {
        if running && detecting == detect {
            result(nil)
            return
        }
        if running { stop() }

        if !detect {
            CameraSession.shared.onFrame = nil
            CameraSession.shared.start { error in
                if let error = error {
                    result(FlutterError(code: "camera_failed", message: error, details: nil))
                } else {
                    self.running = true
                    self.detecting = false
                    result(nil)
                }
            }
            return
        }

        guard let modelPath = Self.modelPath() else {
            result(FlutterError(code: "no_model",
                                message: "找不到 face_landmarker.task,請確認 pod 資源有被打包進去",
                                details: nil))
            return
        }

        guard let service = FaceLandmarkerService(modelPath: modelPath) else {
            result(FlutterError(code: "landmarker_failed",
                                message: "MediaPipe FaceLandmarker 初始化失敗",
                                details: nil))
            return
        }
        service.delegate = self
        self.service = service

        CameraSession.shared.onFrame = { [weak self] sampleBuffer in
            guard let self = self else { return }
            let seconds = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            self.service?.detect(sampleBuffer: sampleBuffer,
                                 timestampMs: Int(seconds * 1000))
        }

        CameraSession.shared.start { error in
            if let error = error {
                result(FlutterError(code: "camera_failed", message: error, details: nil))
            } else {
                self.running = true
                self.detecting = true
                result(nil)
            }
        }
    }

    private func stop() {
        running = false
        detecting = false
        CameraSession.shared.onFrame = nil
        CameraSession.shared.stop()
        service = nil
    }

    /// 模型檔透過 podspec 的 resource_bundles 打包,實際落點會因為
    /// static / dynamic framework 而不同,所以三個位置都找一遍。
    private static func modelPath() -> String? {
        let container = Bundle(for: FaceMeshPlugin.self)

        if let bundleURL = container.url(forResource: "face_mesh_assets", withExtension: "bundle"),
           let assets = Bundle(url: bundleURL),
           let path = assets.path(forResource: "face_landmarker", ofType: "task") {
            return path
        }
        if let path = container.path(forResource: "face_landmarker", ofType: "task") {
            return path
        }
        return Bundle.main.path(forResource: "face_landmarker", ofType: "task")
    }
}

// MARK: - 偵測結果 → Dart

extension FaceMeshPlugin: FaceLandmarkerServiceDelegate {

    func faceLandmarkerService(_ service: FaceLandmarkerService, didProduce frame: FaceFrame?) {
        // MediaPipe 的 callback 不在 main thread,但 FlutterEventSink 必須在 main thread 呼叫。
        DispatchQueue.main.async {
            guard let sink = self.eventSink else { return }

            guard let frame = frame else {
                sink(["hasFace": false])
                return
            }

            // 輪廓走 Float32List 而不是 List<Double>。
            // 84 個浮點數如果包成 Dart List,每秒 30 次要配置 84 個 NSNumber;
            // typed data 是整塊記憶體直接過去,差距在持續串流下很明顯。
            let contourData = frame.contour.withUnsafeBufferPointer { Data(buffer: $0) }

            sink([
                "hasFace": true,
                "blendshapes": frame.blendshapes,
                "yaw": frame.yaw,
                "rollDegrees": frame.rollDegrees,
                "mouthOpenRatio": frame.mouthOpenRatio,
                "mouthWidthRatio": frame.mouthWidthRatio,
                "contour": FlutterStandardTypedData(float32: contourData),
                "imageWidth": frame.imageWidth,
                "imageHeight": frame.imageHeight
            ])
        }
    }
}

// MARK: - EventChannel

extension FaceMeshPlugin: FlutterStreamHandler {

    public func onListen(withArguments arguments: Any?,
                         eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
