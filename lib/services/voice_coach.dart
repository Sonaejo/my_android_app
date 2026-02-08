// lib/services/voice_coach.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// モチベーション用の音声コーチ（TTS）
///
/// 使い方：
///   - main.dart で
///       await VoiceCoach.instance.init();
///   - 設定画面で ON/OFF
///       VoiceCoach.instance.setEnabled(true/false);
///   - カウンター画面から
///       VoiceCoach.instance.onStart();
///       VoiceCoach.instance.onRep(reps);
///       VoiceCoach.instance.onNearGoal(reps, goal);
///       VoiceCoach.instance.onGoalReached(goal);
///       VoiceCoach.instance.onDailyGoalReached(goal);
///       VoiceCoach.instance.resetSession();   // セッション開始/リセット時
///       VoiceCoach.instance.stop();           // 強制停止したいとき
class VoiceCoach {
  VoiceCoach._internal();
  static final VoiceCoach instance = VoiceCoach._internal();

  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _enabled = true;

  // セッションごとの状態（必要なら増やす）
  int _lastRepSpoken = 0;

  /// 初期化（main.dart から1回だけ呼べばOK）
  Future<void> init() async {
    if (_initialized) return;

    try {
      await _tts.setLanguage('ja-JP');
    } catch (_) {}
    try {
      await _tts.setSpeechRate(0.9); // 少しゆっくりめ
    } catch (_) {}
    try {
      await _tts.setPitch(1.0);
    } catch (_) {}

    _initialized = true;
  }

  /// 有効 / 無効 を切り替え（SettingsScreen から呼ばれる）
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      // OFF にしたタイミングで読み上げ中なら止める
      _tts.stop();
    }
  }

  /// 現在しゃべっている音声を止める（PoseCounterScreen.dispose などから呼ばれる）
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('VoiceCoach stop error: $e');
    }
  }

  /// 1 セッション分の内部状態をリセット
  /// （リセットボタンやカウンター画面再入場時に呼ぶ）
  void resetSession() {
    _lastRepSpoken = 0;
  }

  /// 内部用：実際にしゃべる処理
  Future<void> _speak(String text) async {
    if (!_enabled) return;
    if (text.trim().isEmpty) return;

    try {
      await _tts.stop(); // 前の読み上げを一旦停止（かぶらないように）
      await _tts.speak(text);
    } catch (e) {
      debugPrint('VoiceCoach speak error: $e');
    }
  }

  // ─────────────────────────────────────────
  // カウンター画面から呼ぶイベント群
  // ─────────────────────────────────────────

  /// 人が映ったときに最初の1回だけ呼ばれる（PoseCounterScreen側で制御済み）
  void onStart() {
    _speak('よし、フォームを確認しながら一緒にやっていきましょう。');
  }

  /// 回数が増えたときに呼ぶ
  /// ※毎回しゃべるとうるさいので、節目だけしゃべるようにしている
  void onRep(int reps) {
    if (!_enabled) return;
    if (reps <= 0) return;

    // 同じ回数で何度も呼ばれても一度だけしゃべるように
    if (reps <= _lastRepSpoken) return;
    _lastRepSpoken = reps;

    if (reps == 1) {
      _speak('ナイス、1回目です。');
      return;
    }

    // 5回刻みで声がけ
    if (reps % 5 == 0) {
      _speak('$reps 回達成、いいペースです。');
    }
  }

  /// ゴールまであと少しになったとき（PoseCounterScreen側で remain<=3 のときに呼ぶ）
  void onNearGoal(int currentReps, int goalReps) {
    final remain = goalReps - currentReps;
    if (remain <= 0) return;

    if (remain == 3) {
      _speak('あと3回です、そのまま頑張りましょう。');
    } else if (remain == 2) {
      _speak('あと2回です、ラストスパートです。');
    } else if (remain == 1) {
      _speak('ラスト1回です、全力でいきましょう。');
    }
  }

  /// ロジック内のゴールを達成した瞬間に呼ばれる
  void onGoalReached(int goalReps) {
    _speak('目標の $goalReps 回を達成しました。お疲れさまでした。');
  }

  /// 「設定画面の今日の目標回数」を達成したときに呼ばれる
  void onDailyGoalReached(int goalReps) {
    _speak('今日の目標回数、$goalReps 回を達成しました。とてもよく頑張りました。');
  }
}
