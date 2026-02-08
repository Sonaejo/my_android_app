// lib/services/face_service.dart
import 'dart:async';

// ---- 条件付きインポートは「宣言より前」に置く＆package: パスで統一 ----
import 'package:android_app/services/face_service_impl_stub.dart'
    if (dart.library.html) 'package:android_app/services/face_service_impl_web.dart'
    if (dart.library.io) 'package:android_app/services/face_service_impl_android.dart' as impl;

// 共通の結果
class FaceResult {
  final bool hasFace;
  const FaceResult({required this.hasFace});
}

// 共通IF
abstract class FaceService {
  Stream<FaceResult> get stream;

  /// 推論の初期化と開始（多重呼び出しは安全に無視されるべき）
  Future<void> start();

  /// 推論の一時停止（リソースは保持してよい／再開可能）
  Future<void> stop();

  /// サービスを完全に破棄（再利用不可）
  void dispose();
}

/// 画面側は常にこれを呼べばOK（Web/Android/iOSで適切な実装が返る）
FaceService createFaceService() => impl.createPlatformFaceService();
