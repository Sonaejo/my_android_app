// lib/web/pose_bridge_stub.dart
//
// 非Web（Android/iOS/desktop）ビルド時に参照されるスタブ実装。
// 何もしないが、同じAPIでビルドを通すために存在する。

typedef PoseCallback = void Function(Map<String, dynamic> landmarks);
typedef TextCallback = void Function(String text);

class PoseWebBridge {
  void init({
    required PoseCallback onPose,
    required TextCallback onFacing,
    required TextCallback onError,
  }) {
    // 非Webでは何もしない
  }

  Future<void> start() async {
    // 非Webでは何もしない（ネイティブ側は MethodChannel で制御）
  }

  Future<void> stop() async {
    // 非Webでは何もしない
  }
}
