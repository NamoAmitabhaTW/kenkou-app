import Flutter
import UIKit
import AVFoundation

public class FaceMeshPlugin: NSObject, FlutterPlugin {

    private var eventSink: FlutterEventSink?
    private var service: FaceLandmarkerService?
    private var running = false
    private var detecting = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FaceMeshPlugin()

        let methodChannel = FlutterMethodChannel(name: "face_mesh/method",
                                                 binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(name: "face_mesh/events",
                                               binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)

        registrar.register(PreviewViewFactory(), withId: "face_mesh/preview")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            let detect = (call.arguments as? [String: Any])?["detect"] as? Bool ?? true
            start(detect: detect, result: result)
        case "stop":
            stop()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

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

extension FaceMeshPlugin: FaceLandmarkerServiceDelegate {

    func faceLandmarkerService(_ service: FaceLandmarkerService, didProduce frame: FaceFrame?) {
        DispatchQueue.main.async {
            guard let sink = self.eventSink else { return }

            guard let frame = frame else {
                sink(["hasFace": false])
                return
            }

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
