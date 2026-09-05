import Flutter
import ReplayKit
import UIKit

public class ScreenCapturePlugin: NSObject, FlutterPlugin {

    private let recorder = ScreenRecorder()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "screen_capture/method",
                                           binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(ScreenCapturePlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(RPScreenRecorder.shared().isAvailable)

        case "start":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(FlutterError(code: "bad_args", message: "缺少輸出路徑", details: nil))
                return
            }
            // 預設收麥克風:題目從喇叭出來會被一起收進去,
            // 長輩的聲音和題目就落在同一條音軌上。
            let microphone = (args["microphone"] as? Bool) ?? true
            recorder.start(outputPath: path, microphone: microphone) { error in
                if let error = error {
                    result(FlutterError(code: "start_failed", message: error, details: nil))
                } else {
                    result(nil)
                }
            }

        case "stop":
            recorder.stop { path, error in
                if let path = path {
                    result(path)
                } else {
                    result(FlutterError(code: "stop_failed", message: error, details: nil))
                }
            }

        case "merge":
            guard let args = call.arguments as? [String: Any],
                  let video = args["video"] as? String,
                  let audio = args["audio"] as? String,
                  let output = args["output"] as? String else {
                result(FlutterError(code: "bad_args", message: "缺少合成路徑", details: nil))
                return
            }
            VideoAudioMerger.merge(videoPath: video, audioPath: audio, outputPath: output) { path, error in
                if let path = path {
                    result(path)
                } else {
                    result(FlutterError(code: "merge_failed", message: error, details: nil))
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
