// lib/services/cue_speech_web.dart
//
// Web ブラウザ用: SpeechSynthesis API を使って日本語で読み上げます。

import 'dart:html' as html;
import 'cue_speech_service.dart';

CueSpeaker createCueSpeaker() => _WebCueSpeaker();

class _WebCueSpeaker implements CueSpeaker {
  html.SpeechSynthesis? get _synth => html.window.speechSynthesis;

  @override
  Future<void> speak(String text) async {
    final synth = _synth;
    if (synth == null) return;

    // 前の読み上げを止める
    synth.cancel();

    if (text.trim().isEmpty) return;

    final utter = html.SpeechSynthesisUtterance(text)
      ..lang = 'ja-JP'
      ..rate = 1.0
      ..pitch = 1.0;

    synth.speak(utter);
  }

  @override
  Future<void> stop() async {
    final synth = _synth;
    if (synth == null) return;
    synth.cancel();
  }
}
