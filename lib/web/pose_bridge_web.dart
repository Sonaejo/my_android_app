// lib/web/pose_bridge_web.dart
//
// Web（dart.library.html がある環境）で使う実装。
// window へ dispatch される CustomEvent('pose', {detail: {...}}) を受け取り、
// Dart 側コールバックに橋渡しする。start/stop は window.poseStart/poseStop を呼ぶ。

import 'dart:async';
import 'dart:convert' show json;
import 'dart:html' as html;
import 'dart:js_util' as jsu;

typedef PoseCallback = void Function(Map<String, dynamic> landmarks);
typedef TextCallback = void Function(String text);

class PoseWebBridge {
  PoseCallback? _onPose;
  TextCallback? _onFacing;
  TextCallback? _onError;

  StreamSubscription<html.Event>? _poseSub;

  void init({
    required PoseCallback onPose,
    required TextCallback onFacing,
    required TextCallback onError,
  }) {
    _onPose = onPose;
    _onFacing = onFacing;
    _onError = onError;

    // 既存の購読があれば解除
    _poseSub?.cancel();

    // CustomEvent('pose', { detail: { type: 'pose'|'facing'|'error', ... } })
    _poseSub = html.EventStreamProvider<html.Event>('pose')
        .forTarget(html.window)
        .listen((html.Event e) {
      // CustomEvent として扱う
      final ce = e is html.CustomEvent ? e : null;
      final detail = ce?.detail;

      if (detail is Map) {
        final type = (detail['type'] ?? 'pose').toString();

        if (type == 'facing') {
          final v = (detail['value'] ?? 'front').toString();
          _onFacing?.call(v);
          return;
        }

        if (type == 'error') {
          final msg = (detail['message'] ?? 'Unknown error').toString();
          _onError?.call(msg);
          return;
        }

        // type == 'pose' 想定。{ landmarks: {key:{x,y},...} }
        final raw = detail['landmarks'];
        if (raw is Map) {
          // Map<dynamic,dynamic> → Map<String,dynamic>
          final converted = raw.map(
            (k, v) => MapEntry(k.toString(), v is Map ? Map<String, dynamic>.from(v) : v),
          );
          _onPose?.call(Map<String, dynamic>.from(converted));
          return;
        }
      }
    });
  }

  /// JS 側の window.poseStart() を呼ぶ（ここでカメラ許可ダイアログが出る想定）
  Future<void> start() async {
    try {
      if (jsu.hasProperty(html.window, 'poseStart')) {
        jsu.callMethod(html.window, 'poseStart', const []);
      } else {
        _onError?.call('pose_web.js not loaded or poseStart not defined.');
      }
    } catch (e) {
      _onError?.call('poseStart failed: $e');
    }
  }

  /// JS 側の window.poseStop() を呼ぶ
  Future<void> stop() async {
    try {
      if (jsu.hasProperty(html.window, 'poseStop')) {
        jsu.callMethod(html.window, 'poseStop', const []);
      }
    } catch (_) {
      // noop
    }
  }

  void dispose() {
    _poseSub?.cancel();
    _poseSub = null;
  }
}
