package com.example.pushup_counter

import android.Manifest
import android.content.pm.PackageManager
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var channel: MethodChannel
    private var bridge: PoseBridge? = null

    private val REQ_CAMERA = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel: Flutter <-> Android ネイティブ
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pose/native"
        )

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    ensureCameraPermission {
                        if (bridge == null) {
                            // ActivityはLifecycleOwnerなのでそのまま渡せる
                            bridge = PoseBridge(this, this, channel)
                        }
                        bridge?.start()
                    }
                    result.success(null)
                }
                "stop" -> {
                    bridge?.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ★ Flutter側で AndroidView(viewType: 'posePreview') を使えるように登録
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory("posePreview", PosePreviewFactory { ensureBridge() })
    }

    private fun ensureBridge(): PoseBridge {
        if (bridge == null) {
            bridge = PoseBridge(this, this, channel)
        }
        return bridge!!
    }

    /** 実行時カメラ権限の確認＆リクエスト */
    private fun ensureCameraPermission(onGranted: () -> Unit) {
        val granted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        if (granted) {
            onGranted()
            return
        }
        ActivityCompat.requestPermissions(
            this, arrayOf(Manifest.permission.CAMERA), REQ_CAMERA
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_CAMERA) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Toast.makeText(this, "Camera permission granted", Toast.LENGTH_SHORT).show()
                // 許可後に開始（すでにstart要求済み想定）
                bridge?.start() ?: run {
                    bridge = PoseBridge(this, this, channel)
                    bridge?.start()
                }
            } else {
                Toast.makeText(this, "Camera permission denied", Toast.LENGTH_LONG).show()
                channel.invokeMethod("onPoseError", "camera permission denied")
            }
        }
    }
}
