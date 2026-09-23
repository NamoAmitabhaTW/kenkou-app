package tw.aarontsai.face_mesh

import android.content.Context
import android.util.Size
import android.view.Surface
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.UseCase
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import java.util.concurrent.Executors

internal object CameraSession {

    private val analysisExecutor = Executors.newSingleThreadExecutor()

    private var provider: ProcessCameraProvider? = null
    private var preview: Preview? = null
    private var previewView: PreviewView? = null

    private var generation = 0

    @Volatile
    var onFrame: ((ImageProxy) -> Unit)? = null

    fun start(
        context: Context,
        owner: LifecycleOwner,
        analyze: Boolean,
        completion: (String?) -> Unit,
    ) {
        val token = ++generation
        val future = ProcessCameraProvider.getInstance(context)

        future.addListener({
            if (token != generation) return@addListener

            val provider = try {
                future.get()
            } catch (e: Exception) {
                completion("相機初始化失敗:${e.message}")
                return@addListener
            }
            this.provider = provider

            val selector = CameraSelector.DEFAULT_FRONT_CAMERA
            val hasFrontCamera = try {
                provider.hasCamera(selector)
            } catch (e: Exception) {
                false
            }
            if (!hasFrontCamera) {
                completion("找不到可用的前鏡頭")
                return@addListener
            }

            val useCases = mutableListOf<UseCase>(buildPreview())
            if (analyze) useCases += buildAnalysis()

            try {
                provider.unbindAll()
                provider.bindToLifecycle(owner, selector, *useCases.toTypedArray())
            } catch (e: Exception) {
                completion("無法開啟前鏡頭:${e.message}")
                return@addListener
            }
            completion(null)
        }, ContextCompat.getMainExecutor(context))
    }

    fun stop() {
        generation++
        provider?.unbindAll()
        preview = null
    }

    fun attach(view: PreviewView) {
        previewView = view
        preview?.setSurfaceProvider(view.surfaceProvider)
    }

    fun detach(view: PreviewView) {
        if (previewView !== view) return
        previewView = null
        preview?.setSurfaceProvider(null)
    }

    private val aspect4by3 = AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY

    private fun buildPreview(): Preview {
        val preview = Preview.Builder()
            .setResolutionSelector(
                ResolutionSelector.Builder().setAspectRatioStrategy(aspect4by3).build()
            )
            .setTargetRotation(Surface.ROTATION_0)
            .build()
        previewView?.let { preview.setSurfaceProvider(it.surfaceProvider) }
        this.preview = preview
        return preview
    }

    private fun buildAnalysis(): ImageAnalysis {
        val resolution = ResolutionSelector.Builder()
            .setAspectRatioStrategy(aspect4by3)
            .setResolutionStrategy(
                ResolutionStrategy(
                    Size(640, 480),
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                )
            )
            .build()

        return ImageAnalysis.Builder()
            .setResolutionSelector(resolution)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .setTargetRotation(Surface.ROTATION_0)
            .build()
            .also { analysis ->
                analysis.setAnalyzer(analysisExecutor) { image ->
                    val handler = onFrame
                    if (handler != null) handler(image) else image.close()
                }
            }
    }
}
