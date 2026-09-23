package tw.aarontsai.face_mesh

import android.content.Context
import android.graphics.Color
import android.view.View
import androidx.camera.view.PreviewView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class PreviewPlatformView(context: Context) : PlatformView {

    private val previewView = PreviewView(context).apply {
        setBackgroundColor(Color.BLACK)
        scaleType = PreviewView.ScaleType.FILL_CENTER
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    }

    init {
        CameraSession.attach(previewView)
    }

    override fun getView(): View = previewView

    override fun dispose() {
        CameraSession.detach(previewView)
    }
}

internal class PreviewViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        PreviewPlatformView(context)
}
