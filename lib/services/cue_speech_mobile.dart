// lib/services/cue_speech_mobile.dart
//
// Android / iOS 用: flutter_tts を使って日本語で読み上げます。

import 'package:flutter_tts/flutter_tts.dart';
import 'cue_speech_service.dart';

CueSpeaker createCueSpeaker() => _MobileCueSpeaker();

class _MobileCueSpeaker implements CueSpeaker {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  // ★ PC(Web)と近い体感になるよう、少し遅めのレートに調整
  //   0.0 ~ 1.0 の範囲で、Androidでは 1.0 がかなり早口なので 0.6 前後にしています。
  static const double _mobileSpeechRate = 0.6;
  static const double _mobilePitch = 1.0;

  Future<void> _ensureInit() async {
    if (_initialized) return;

    await _tts.setLanguage('ja-JP');
    await _tts.setSpeechRate(_mobileSpeechRate);
    await _tts.setPitch(_mobilePitch);

    _initialized = true;
  }

  @override
  Future<void> speak(String text) async {
    await _ensureInit();
    // 前の読み上げを止めてから再生
    await _tts.stop();

    if (text.trim().isEmpty) return;

    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _ensureInit();
    await _tts.stop();
  }
}
