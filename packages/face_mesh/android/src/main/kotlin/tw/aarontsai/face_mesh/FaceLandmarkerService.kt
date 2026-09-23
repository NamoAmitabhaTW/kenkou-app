package tw.aarontsai.face_mesh

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import androidx.camera.core.ImageProxy
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.sqrt

internal class FaceFrame(
    val blendshapes: Map<String, Double>,
    val contour: FloatArray,
    val imageWidth: Int,
    val imageHeight: Int,
    val yaw: Double,
    val rollDegrees: Double,
    val mouthOpenRatio: Double,
    val mouthWidthRatio: Double,
)

internal class FaceLandmarkerService private constructor(
    private val landmarker: FaceLandmarker,
) {

    class ModelMissing : Exception()

    var onResult: ((FaceFrame?) -> Unit)? = null

    private var lastTimestampMs = -1L
    private var closed = false

    @Synchronized
    fun detect(image: ImageProxy) {
        if (closed) {
            image.close()
            return
        }

        val timestampMs = image.imageInfo.timestamp / 1_000_000
        if (timestampMs <= lastTimestampMs) {
            image.close()
            return
        }
        lastTimestampMs = timestampMs

        val rotation = image.imageInfo.rotationDegrees
        val raw = image.use { it.toBitmap() }

        try {
            landmarker.detectAsync(upright(raw, rotation), timestampMs)
        } catch (e: Exception) {
            Log.w(TAG, "detectAsync 失敗: $e")
        }
    }

    @Synchronized
    fun close() {
        if (closed) return
        closed = true
        onResult = null
        landmarker.close()
    }

    private fun upright(bitmap: Bitmap, rotationDegrees: Int): MPImage {
        val rotated = if (rotationDegrees == 0) {
            bitmap
        } else {
            val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        }
        return BitmapImageBuilder(rotated).build()
    }

    private fun handle(result: FaceLandmarkerResult, input: MPImage) {
        val callback = onResult ?: return

        val landmarks = result.faceLandmarks().firstOrNull()
        if (landmarks == null || landmarks.size <= 454) {
            callback(null)
            return
        }

        val shapes = HashMap<String, Double>()
        val categories = result.faceBlendshapes().orElse(null)?.firstOrNull()
        categories?.forEach { category ->
            val name = category.categoryName()
            if (name in MOUTH_KEYS) shapes[name] = category.score().toDouble()
        }

        val contour = FloatArray(CONTOUR_INDICES.size * 2)
        CONTOUR_INDICES.forEachIndexed { i, index ->
            contour[i * 2] = landmarks[index].x()
            contour[i * 2 + 1] = landmarks[index].y()
        }

        val width = input.width
        val height = input.height
        val aspect = if (width > 0) height.toDouble() / width else 1.0

        callback(
            FaceFrame(
                blendshapes = shapes,
                contour = contour,
                imageWidth = width,
                imageHeight = height,
                yaw = yaw(landmarks),
                rollDegrees = rollDegrees(landmarks, aspect),
                mouthOpenRatio = ratio(landmarks, 13, 14, aspect),
                mouthWidthRatio = ratio(landmarks, 61, 291, aspect),
            )
        )
    }

    companion object {
        private const val TAG = "face_mesh"

        private const val MODEL_ASSET = "face_landmarker.task"

        private val MOUTH_KEYS = setOf(
            "jawOpen", "jawForward", "jawLeft", "jawRight",
            "mouthClose", "mouthFunnel", "mouthPucker",
            "mouthLeft", "mouthRight",
            "mouthSmileLeft", "mouthSmileRight",
            "mouthFrownLeft", "mouthFrownRight",
            "mouthDimpleLeft", "mouthDimpleRight",
            "mouthStretchLeft", "mouthStretchRight",
            "mouthRollLower", "mouthRollUpper",
            "mouthShrugLower", "mouthShrugUpper",
            "mouthPressLeft", "mouthPressRight",
            "mouthLowerDownLeft", "mouthLowerDownRight",
            "mouthUpperUpLeft", "mouthUpperUpRight",
            "cheekPuff", "cheekSquintLeft", "cheekSquintRight",
            "tongueOut",
        )

        private val OUTER_LIP = intArrayOf(
            61, 146, 91, 181, 84, 17, 314, 405, 321, 375,
            291, 409, 270, 269, 267, 0, 37, 39, 40, 185,
        )
        private val INNER_LIP = intArrayOf(
            78, 95, 88, 178, 87, 14, 317, 402, 318, 324,
            308, 415, 310, 311, 312, 13, 82, 81, 80, 191,
        )
        private val FACE_EDGES = intArrayOf(234, 454)
        private val UPPER_CHEEK_A = intArrayOf(50, 101, 118, 123, 147)
        private val UPPER_CHEEK_B = intArrayOf(280, 330, 347, 352, 376)
        private val LOWER_CHEEK_A = intArrayOf(187, 205, 206, 207, 213, 216, 212, 214, 210, 192)
        private val LOWER_CHEEK_B = intArrayOf(411, 425, 426, 427, 433, 436, 432, 434, 430, 416)
        private val ANCHORS = intArrayOf(1, 6, 152, 93, 323, 172, 397)
        private val OVAL_A = intArrayOf(132, 58, 172, 136)
        private val OVAL_B = intArrayOf(361, 288, 397, 365)

        private val CONTOUR_INDICES = OUTER_LIP + INNER_LIP + FACE_EDGES +
            UPPER_CHEEK_A + UPPER_CHEEK_B + LOWER_CHEEK_A + LOWER_CHEEK_B +
            ANCHORS + OVAL_A + OVAL_B

        fun create(context: Context): FaceLandmarkerService {
            val model = loadModel(context) ?: throw ModelMissing()

            lateinit var service: FaceLandmarkerService
            val options = FaceLandmarker.FaceLandmarkerOptions.builder()
                .setBaseOptions(BaseOptions.builder().setModelAssetBuffer(model).build())
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumFaces(1)
                .setOutputFaceBlendshapes(true)
                .setMinFaceDetectionConfidence(0.5f)
                .setMinFacePresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setResultListener { result, input -> service.handle(result, input) }
                .setErrorListener { e -> Log.w(TAG, "FaceLandmarker 錯誤: $e") }
                .build()

            service = FaceLandmarkerService(FaceLandmarker.createFromOptions(context, options))
            return service
        }

        private fun loadModel(context: Context): ByteBuffer? = try {
            context.assets.open(MODEL_ASSET).use { input ->
                val bytes = input.readBytes()
                ByteBuffer.allocateDirect(bytes.size)
                    .order(ByteOrder.nativeOrder())
                    .put(bytes)
                    .apply { rewind() }
            }
        } catch (e: IOException) {
            null
        }

        private fun yaw(pts: List<NormalizedLandmark>): Double {
            val nose = pts[1].x().toDouble()
            val leftEdge = pts[234].x().toDouble()
            val rightEdge = pts[454].x().toDouble()
            val span = rightEdge - leftEdge
            if (abs(span) <= 1e-6) return 0.0
            return ((nose - leftEdge) - (rightEdge - nose)) / span
        }

        private fun rollDegrees(pts: List<NormalizedLandmark>, aspect: Double): Double {
            val dx = (pts[263].x() - pts[33].x()).toDouble()
            val dy = (pts[263].y() - pts[33].y()).toDouble() * aspect
            return Math.toDegrees(atan2(dy, dx))
        }

        private fun ratio(pts: List<NormalizedLandmark>, a: Int, b: Int, aspect: Double): Double {
            val faceWidth = distance(pts, 234, 454, aspect)
            if (faceWidth <= 1e-6) return 0.0
            return distance(pts, a, b, aspect) / faceWidth
        }

        private fun distance(pts: List<NormalizedLandmark>, a: Int, b: Int, aspect: Double): Double {
            val dx = (pts[a].x() - pts[b].x()).toDouble()
            val dy = (pts[a].y() - pts[b].y()).toDouble() * aspect
            return sqrt(dx * dx + dy * dy)
        }
    }
}
