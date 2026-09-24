package tw.aarontsai.screen_capture

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.Surface
import java.io.File
import kotlin.math.min

internal class ScreenRecorder(private val context: Context) {

    private val mainHandler = Handler(Looper.getMainLooper())

    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var recorder: MediaRecorder? = null

    private var surface: Surface? = null
    private var outputPath: String? = null

    private var endedEarly: Result<String>? = null

    var isStarting = false
        private set

    private var cancelled = false

    val isRecording: Boolean get() = recorder != null

    var inForeground = true
        set(value) {
            field = value
            display?.surface = if (value) surface else null
        }

    fun start(
        activity: Activity,
        resultCode: Int,
        data: Intent,
        outputPath: String,
        microphone: Boolean,
        completion: (String?) -> Unit,
    ) {
        isStarting = true
        cancelled = false
        endedEarly = null
        ScreenCaptureService.start(context) { serviceError ->
            isStarting = false
            val error = when {
                serviceError != null -> "前景服務開不起來:$serviceError"
                cancelled -> {
                    release()
                    "錄影已經取消"
                }
                else -> try {
                    begin(activity, resultCode, data, outputPath, microphone)
                    null
                } catch (e: Exception) {
                    release()
                    File(outputPath).delete()
                    e.message ?: e.toString()
                }
            }
            completion(error)
        }
    }

    fun stop(): Result<String> {
        endedEarly?.let {
            endedEarly = null
            return it
        }
        if (recorder == null) return Result.failure(IllegalStateException("目前沒有在錄製"))
        return finish()
    }

    fun discard() {
        if (isStarting) cancelled = true
        val result = if (recorder != null) finish() else endedEarly
        endedEarly = null
        result?.getOrNull()?.let { File(it).delete() }
    }

    private fun begin(activity: Activity, resultCode: Int, data: Intent, path: String, microphone: Boolean) {
        val manager = context.getSystemService(MediaProjectionManager::class.java)
        val projection = manager.getMediaProjection(resultCode, data)
            ?: throw IllegalStateException("拿不到 MediaProjection")
        this.projection = projection
        projection.registerCallback(projectionCallback, mainHandler)

        outputPath = path
        File(path).delete()

        val size = CaptureSize.of(activity)
        val recorder = createRecorder(path, size, microphone && hasMicrophonePermission())
        this.recorder = recorder
        recorder.prepare()
        surface = recorder.surface

        display = projection.createVirtualDisplay(
            "screen_capture",
            size.width,
            size.height,
            size.dpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            if (inForeground) surface else null,
            null,
            null,
        )
        recorder.start()
    }

    private fun createRecorder(path: String, size: CaptureSize, withAudio: Boolean): MediaRecorder {
        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        if (withAudio) recorder.setAudioSource(MediaRecorder.AudioSource.MIC)
        recorder.setVideoSource(MediaRecorder.VideoSource.SURFACE)
        recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        recorder.setOutputFile(path)
        recorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
        recorder.setVideoSize(size.width, size.height)
        recorder.setVideoFrameRate(FRAME_RATE)
        recorder.setVideoEncodingBitRate(size.width * size.height * 4)
        if (withAudio) {
            recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            recorder.setAudioChannels(1)
            recorder.setAudioSamplingRate(44_100)
            recorder.setAudioEncodingBitRate(64_000)
        }
        return recorder
    }

    private fun hasMicrophonePermission() =
        context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun finish(): Result<String> {
        val path = outputPath
        display?.surface = null
        val stopped = try {
            recorder?.stop()
            true
        } catch (e: RuntimeException) {
            false
        }
        release()

        if (stopped && path != null) return Result.success(path)
        path?.let { File(it).delete() }
        return Result.failure(IllegalStateException("沒有錄到任何畫面"))
    }

    private fun release() {
        display?.release()
        display = null
        recorder?.release()
        recorder = null
        surface = null
        outputPath = null
        projection?.let {
            it.unregisterCallback(projectionCallback)
            it.stop()
        }
        projection = null
        ScreenCaptureService.stop(context)
    }

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            if (recorder != null) endedEarly = finish()
        }
    }

    private class CaptureSize(val width: Int, val height: Int, val dpi: Int) {

        fun isEncodable(): Boolean {
            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height)
            return MediaCodecList(MediaCodecList.REGULAR_CODECS).findEncoderForFormat(format) != null
        }

        companion object {
            fun of(activity: Activity): CaptureSize {
                val (width, height) = screenSize(activity)
                val dpi = activity.resources.displayMetrics.densityDpi
                val candidates = SHORT_SIDES.map { scaled(width, height, it, dpi) }
                return candidates.firstOrNull { it.isEncodable() } ?: candidates.last()
            }

            private fun scaled(width: Int, height: Int, shortSide: Int, dpi: Int): CaptureSize {
                val screenShortSide = min(width, height)
                val target = min(shortSide, screenShortSide)
                return CaptureSize(
                    align16(width * target / screenShortSide),
                    align16(height * target / screenShortSide),
                    dpi,
                )
            }

            private fun align16(value: Int) = value / 16 * 16

            private fun screenSize(activity: Activity): Pair<Int, Int> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val bounds = activity.windowManager.maximumWindowMetrics.bounds
                    return bounds.width() to bounds.height()
                }
                val metrics = DisplayMetrics()
                @Suppress("DEPRECATION")
                activity.windowManager.defaultDisplay.getRealMetrics(metrics)
                return metrics.widthPixels to metrics.heightPixels
            }
        }
    }

    private companion object {
        const val FRAME_RATE = 30

        val SHORT_SIDES = listOf(720, 480)
    }
}
