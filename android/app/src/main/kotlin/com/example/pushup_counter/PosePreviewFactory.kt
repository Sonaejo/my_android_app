package com.example.pushup_counter

import android.content.Context
import android.view.View
import androidx.camera.view.PreviewView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class PosePreviewFactory(
    private val bridgeProvider: () -> PoseBridge
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
      val pv = PreviewView(context).apply {
          implementationMode = PreviewView.ImplementationMode.COMPATIBLE
      }
      // PoseBridge にプレビューをアタッチ
      bridgeProvider().attachPreview(pv)
      return object : PlatformView {
          override fun getView(): View = pv
          override fun dispose() {}
      }
    }
}
