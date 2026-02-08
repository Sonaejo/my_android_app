// lib/services/workout_stats_store.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ワークアウト合計値（ワークアウト数 / 消費kcal / 実施時間）を
/// 永続化＋リアルタイム反映する共有ストア。
///
/// - ワークアウト数: int
/// - 合計カロリー: double（kcal）
/// - 合計時間: double（秒）
class WorkoutStatsStore {
  WorkoutStatsStore._();

  static const _kWorkoutsKey = 'ws_workouts_total';
  static const _kKcalKey     = 'ws_kcal_total_double';
  static const _kSecondsKey  = 'ws_seconds_total_double';

  /// 合計ワークアウト数（回）
  static final ValueNotifier<int> workouts = ValueNotifier<int>(0);

  /// 合計消費カロリー（kcal, 小数対応）
  static final ValueNotifier<double> kcal = ValueNotifier<double>(0.0);

  /// 合計実施時間（秒, 小数対応）
  static final ValueNotifier<double> seconds = ValueNotifier<double>(0.0);

  static bool _inited = false;
  static SharedPreferences? _prefs;

  /// 最初に一度だけ呼ぶ（main や レポート画面など）
  static Future<void> init() async {
    if (_inited) return;
    _prefs ??= await SharedPreferences.getInstance();

    workouts.value = _prefs!.getInt(_kWorkoutsKey) ?? 0;
    kcal.value     = _prefs!.getDouble(_kKcalKey) ?? 0.0;
    seconds.value  = _prefs!.getDouble(_kSecondsKey) ?? 0.0;

    _inited = true;
  }

  static Future<void> _saveAll() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setInt(_kWorkoutsKey, workouts.value);
    await p.setDouble(_kKcalKey,   kcal.value);
    await p.setDouble(_kSecondsKey, seconds.value);
  }

  /// 1セッション終了時に合計へ加算する。
  ///
  /// 例:
  ///   await WorkoutStatsStore.addSession(
  ///     seconds: secReal,
  ///     sessionKcal: kcalReal,
  ///   );
  static Future<void> addSession({
    required double seconds,
    required double sessionKcal,
  }) async {
    // 現在値をロード
    await init();

    // セッション数 +1
    workouts.value = workouts.value + 1;

    // 秒・カロリーをそのまま加算（小数OK）
    WorkoutStatsStore.seconds.value += seconds;
    WorkoutStatsStore.kcal.value    += sessionKcal;

    await _saveAll();
  }

  /// 必要なら「合計リセット」用
  static Future<void> resetAll() async {
    await init();
    workouts.value = 0;
    kcal.value     = 0.0;
    seconds.value  = 0.0;
    await _saveAll();
  }

  /// レポート表示用: 合計時間（分）を返すヘルパー
  static double get totalMinutes => seconds.value / 60.0;
}
