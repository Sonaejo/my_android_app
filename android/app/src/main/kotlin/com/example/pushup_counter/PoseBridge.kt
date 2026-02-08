package com.example.pushup_counter

import android.content.Context
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.UseCase
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseDetector
import com.google.mlkit.vision.pose.PoseLandmark
import com.google.mlkit.vision.pose.accurate.AccuratePoseDetectorOptions
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class PoseBridge(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private val channel: MethodChannel
) {
    private var cameraProvider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null
    private var preview: Preview? = null
    private var previewView: PreviewView? = null
    private var executor: ExecutorService = Executors.newSingleThreadExecutor()

    private var isFront: Boolean = false

    private val poseClient: PoseDetector by lazy {
        val opts = AccuratePoseDetectorOptions.Builder()
            .setDetectorMode(AccuratePoseDetectorOptions.STREAM_MODE)
            .build()
        PoseDetection.getClient(opts)
    }

    /** PlatformView（PreviewView生成側）から渡される */
    fun attachPreview(view: PreviewView) {
        previewView = view
        // すでに preview があれば SurfaceProvider を即接続
        preview?.setSurfaceProvider(previewView?.surfaceProvider)
    }

    fun start() {
        // 停止後の再開で executor が終了済みなら作り直す
        if (executor.isShutdown) executor = Executors.newSingleThreadExecutor()

        try {
            val providerFuture = ProcessCameraProvider.getInstance(context)
            providerFuture.addListener({
                try {
                    cameraProvider = providerFuture.get()

                    // ---- Preview（16:9に統一）----
                    preview = Preview.Builder()
                        .setTargetResolution(Size(1280, 720))
                        .build().also { p ->
                            previewView?.let { p.setSurfaceProvider(it.surfaceProvider) }
                        }

                    // ---- Analysis（16:9に統一 / 最新フレームのみ解析）----
                    analysis = ImageAnalysis.Builder()
                        .setTargetResolution(Size(1280, 720))
                        .setImageQueueDepth(1)
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build().also { a ->
                            a.setAnalyzer(executor) { imageProxy ->
                                val mediaImage = imageProxy.image
                                if (mediaImage == null) {
                                    imageProxy.close()
                                    return@setAnalyzer
                                }
                                val image = InputImage.fromMediaImage(
                                    mediaImage,
                                    imageProxy.imageInfo.rotationDegrees
                                )

                                poseClient.process(image)
                                    .addOnSuccessListener { pose ->
                                        val map = HashMap<String, Any?>()

                                        fun add(which: Int, name: String) {
                                            val lm = pose.getPoseLandmark(which) ?: return
                                            val w = mediaImage.width.toFloat()
                                            val h = mediaImage.height.toFloat()
                                            map[name] = mapOf(
                                                "x" to (lm.position.x / w),
                                                "y" to (lm.position.y / h)
                                            )
                                        }

                                        add(PoseLandmark.LEFT_SHOULDER, "leftShoulder")
                                        add(PoseLandmark.RIGHT_SHOULDER, "rightShoulder")
                                        add(PoseLandmark.LEFT_ELBOW, "leftElbow")
                                        add(PoseLandmark.RIGHT_ELBOW, "rightElbow")
                                        add(PoseLandmark.LEFT_WRIST, "leftWrist")
                                        add(PoseLandmark.RIGHT_WRIST, "rightWrist")
                                        add(PoseLandmark.LEFT_HIP, "leftHip")
                                        add(PoseLandmark.RIGHT_HIP, "rightHip")
                                        add(PoseLandmark.LEFT_KNEE, "leftKnee")
                                        add(PoseLandmark.RIGHT_KNEE, "rightKnee")
                                        add(PoseLandmark.LEFT_ANKLE, "leftAnkle")
                                        add(PoseLandmark.RIGHT_ANKLE, "rightAnkle")

                                        channel.invokeMethod("onPose", map)
                                    }
                                    .addOnFailureListener { e ->
                                        channel.invokeMethod(
                                            "onPoseError",
                                            e.message ?: "pose process failed"
                                        )
                                    }
                                    .addOnCompleteListener { imageProxy.close() }
                            }
                        }

                    // ---- バインド：バック優先→フロントへフォールバック ----
                    if (!bind(CameraSelector.DEFAULT_BACK_CAMERA)) {
                        if (!bind(CameraSelector.DEFAULT_FRONT_CAMERA)) {
                            channel.invokeMethod("onPoseError", "bind lifecycle failed")
                        }
                    }
                } catch (e: Exception) {
                    channel.invokeMethod("onPoseError", "provider error: ${e.message}")
                }
            }, ContextCompat.getMainExecutor(context))
        } catch (e: SecurityException) {
            channel.invokeMethod("onPoseError", "camera permission missing")
        } catch (e: Exception) {
            channel.invokeMethod("onPoseError", e.message ?: "unknown start error")
        }
    }

    /** Preview + Analysis を同時にバインド（vararg） */
    private fun bind(selector: CameraSelector): Boolean {
        return try {
            val useCases = mutableListOf<UseCase>()
            preview?.let { useCases.add(it) }
            analysis?.let { useCases.add(it) }

            cameraProvider?.unbindAll()
            cameraProvider?.bindToLifecycle(
                lifecycleOwner,
                selector,
                *useCases.toTypedArray()
            )
            isFront = (selector == CameraSelector.DEFAULT_FRONT_CAMERA)
            // Flutter へカメラ向きを通知（鏡像補正用）
            channel.invokeMethod("onCameraFacing", if (isFront) "front" else "back")
            true
        } catch (_: Exception) {
            false
        }
    }

    fun stop() {
        try { analysis?.clearAnalyzer(); cameraProvider?.unbindAll() } catch (_: Exception) {}
        try { executor.shutdownNow() } catch (_: Exception) {}
    }
}
