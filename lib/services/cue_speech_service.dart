// lib/services/cue_speech_service.dart
//
// フォーム指示の読み上げを行うための共通インターフェース。
// 実体はプラットフォームごとに
//   - cue_speech_web.dart   (Web: SpeechSynthesis API)
//   - cue_speech_mobile.dart(Android/iOS: flutter_tts)
//   - cue_speech_stub.dart  (その他: 何もしない)
// に分かれています。

import 'cue_speech_stub.dart'
    if (dart.library.html) 'cue_speech_web.dart'
    if (dart.library.io) 'cue_speech_mobile.dart';

/// フォーム指示読み上げ用の共通インターフェース
abstract class CueSpeaker {
  /// テキストを読み上げる
  Future<void> speak(String text);

  /// 再生中の音声を止める
  Future<void> stop();
}

/// プラットフォームごとの実装を返すグローバルインスタンス
final CueSpeaker cueSpeaker = createCueSpeaker();
