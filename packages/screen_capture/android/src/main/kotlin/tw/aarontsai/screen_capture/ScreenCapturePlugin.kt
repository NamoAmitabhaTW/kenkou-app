package tw.aarontsai.screen_capture

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlin.concurrent.thread

class ScreenCapturePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var recorder: ScreenRecorder
    private val mainHandler = Handler(Looper.getMainLooper())

    private var activityBinding: ActivityPluginBinding? = null

    private var pendingConsent: ((Int, Intent?) -> Unit)? = null

    private val lifecycleObserver = LifecycleEventObserver { _, event ->
        when (event) {
            Lifecycle.Event.ON_RESUME -> recorder.inForeground = true
            Lifecycle.Event.ON_PAUSE -> recorder.inForeground = false
            else -> Unit
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        recorder = ScreenRecorder(binding.applicationContext)
        channel = MethodChannel(binding.binaryMessenger, "screen_capture/method")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        recorder.discard()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)

            "start" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "缺少輸出路徑", null)
                    return
                }
                val microphone = call.argument<Boolean>("microphone") ?: true
                start(path, microphone, result)
            }

            "stop" -> recorder.stop().fold(
                onSuccess = { result.success(it) },
                onFailure = { result.error("stop_failed", it.message, null) },
            )

            "merge" -> {
                val video = call.argument<String>("video")
                val audio = call.argument<String>("audio")
                val output = call.argument<String>("output")
                if (video == null || audio == null || output == null) {
                    result.error("bad_args", "缺少合成路徑", null)
                    return
                }
                merge(video, audio, output, result)
            }

            else -> result.notImplemented()
        }
    }

    private fun start(path: String, microphone: Boolean, result: MethodChannel.Result) {
        if (recorder.isRecording) {
            result.success(null)
            return
        }
        if (pendingConsent != null || recorder.isStarting) {
            result.error("start_failed", "上一次的錄影詢問還沒結束", null)
            return
        }
        val activity = activityBinding?.activity
        if (activity == null) {
            result.error("start_failed", "找不到可以跳出錄影詢問的畫面", null)
            return
        }

        pendingConsent = { resultCode, data ->
            if (resultCode != Activity.RESULT_OK || data == null) {
                result.error("start_failed", "使用者沒有允許錄製螢幕", null)
            } else {
                recorder.start(activity, resultCode, data, path, microphone) { error ->
                    if (error == null) {
                        result.success(null)
                    } else {
                        result.error("start_failed", error, null)
                    }
                }
            }
        }
        try {
            activity.startActivityForResult(consentIntent(activity), CONSENT_REQUEST_CODE)
        } catch (e: ActivityNotFoundException) {
            pendingConsent = null
            result.error("start_failed", "這台裝置叫不出錄影的同意畫面", e.message)
        }
    }

    private fun consentIntent(activity: Activity): Intent {
        val manager = activity.getSystemService(MediaProjectionManager::class.java)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            manager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay())
        } else {
            manager.createScreenCaptureIntent()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != CONSENT_REQUEST_CODE) return false
        val completion = pendingConsent ?: return true
        pendingConsent = null
        completion(resultCode, data)
        return true
    }

    private fun merge(video: String, audio: String, output: String, result: MethodChannel.Result) {
        thread(name = "screen_capture_merge") {
            val merged = runCatching { VideoAudioMerger.merge(video, audio, output) }
            mainHandler.post {
                merged.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("merge_failed", it.message ?: it.toString(), null) },
                )
            }
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
        (binding.activity as? LifecycleOwner)?.lifecycle?.addObserver(lifecycleObserver)
    }

    override fun onDetachedFromActivity() {
        val binding = activityBinding ?: return
        binding.removeActivityResultListener(this)
        (binding.activity as? LifecycleOwner)?.lifecycle?.removeObserver(lifecycleObserver)
        activityBinding = null
        recorder.inForeground = false

        val completion = pendingConsent
        pendingConsent = null
        completion?.invoke(Activity.RESULT_CANCELED, null)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    private companion object {
        const val CONSENT_REQUEST_CODE = 0x5C2E
    }
}
