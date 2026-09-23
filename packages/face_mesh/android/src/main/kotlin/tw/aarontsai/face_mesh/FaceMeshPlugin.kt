package tw.aarontsai.face_mesh

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class FaceMeshPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var service: FaceLandmarkerService? = null
    private var running = false

    private var detecting = false

    private var pendingPermission: ((Boolean) -> Unit)? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "face_mesh/method")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "face_mesh/events")
        eventChannel.setStreamHandler(this)

        binding.platformViewRegistry.registerViewFactory("face_mesh/preview", PreviewViewFactory())
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stop()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val detect = call.argument<Boolean>("detect") ?: true
                start(detect, result)
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(detect: Boolean, result: MethodChannel.Result) {
        if (running && detecting == detect) {
            result.success(null)
            return
        }
        if (running) stop()

        val activity = activityBinding?.activity
        val owner = activity as? LifecycleOwner
        if (activity == null || owner == null) {
            result.error("camera_failed", "找不到可以綁定相機的畫面", null)
            return
        }

        requestCameraPermission(activity) { granted ->
            if (!granted) {
                result.error("camera_failed", "使用者未授權相機權限", null)
                return@requestCameraPermission
            }

            if (detect) {
                val service = try {
                    FaceLandmarkerService.create(activity)
                } catch (e: FaceLandmarkerService.ModelMissing) {
                    result.error("no_model", "找不到 face_landmarker.task,請確認 assets 有被打包進去", null)
                    return@requestCameraPermission
                } catch (e: Exception) {
                    result.error("landmarker_failed", "MediaPipe FaceLandmarker 初始化失敗", e.message)
                    return@requestCameraPermission
                }
                service.onResult = ::emit
                this.service = service
                CameraSession.onFrame = service::detect
            } else {
                CameraSession.onFrame = null
            }

            CameraSession.start(activity, owner, analyze = detect) { error ->
                if (error != null) {
                    stop()
                    result.error("camera_failed", error, null)
                } else {
                    running = true
                    detecting = detect
                    result.success(null)
                }
            }
        }
    }

    private fun stop() {
        running = false
        detecting = false
        CameraSession.onFrame = null
        CameraSession.stop()
        service?.close()
        service = null
    }

    private fun requestCameraPermission(activity: Activity, completion: (Boolean) -> Unit) {
        val permission = Manifest.permission.CAMERA
        if (ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED) {
            completion(true)
            return
        }
        if (pendingPermission != null) {
            completion(false)
            return
        }
        pendingPermission = completion
        ActivityCompat.requestPermissions(activity, arrayOf(permission), CAMERA_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != CAMERA_REQUEST_CODE) return false
        val completion = pendingPermission ?: return true
        pendingPermission = null
        completion(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        return true
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        stop()
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        pendingPermission = null
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    private fun emit(frame: FaceFrame?) {
        mainHandler.post {
            val sink = eventSink ?: return@post

            if (frame == null) {
                sink.success(mapOf("hasFace" to false))
                return@post
            }

            sink.success(
                mapOf(
                    "hasFace" to true,
                    "blendshapes" to frame.blendshapes,
                    "yaw" to frame.yaw,
                    "rollDegrees" to frame.rollDegrees,
                    "mouthOpenRatio" to frame.mouthOpenRatio,
                    "mouthWidthRatio" to frame.mouthWidthRatio,
                    "contour" to frame.contour,
                    "imageWidth" to frame.imageWidth,
                    "imageHeight" to frame.imageHeight,
                )
            )
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private companion object {
        const val CAMERA_REQUEST_CODE = 0xFACE
    }
}
