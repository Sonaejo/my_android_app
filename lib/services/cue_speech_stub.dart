// lib/services/cue_speech_stub.dart
//
// Web でもモバイルでもない (例: テスト環境など) のとき用のスタブ。

import 'cue_speech_service.dart';

CueSpeaker createCueSpeaker() => _NoopCueSpeaker();

class _NoopCueSpeaker implements CueSpeaker {
  @override
  Future<void> speak(String text) async {
    // 何もしない
  }

  @override
  Future<void> stop() async {
    // 何もしない
  }
}
