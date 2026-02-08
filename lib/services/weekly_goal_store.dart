// lib/services/weekly_goal_store.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 週目標の状態を管理するストア（永続化つき）
/// - 週の開始は「月曜」
/// - 達成済み日は yyyyMMdd 文字列で保存
/// - 週が切り替わったら自動でカウント/達成日のリセット
class WeeklyGoalStore {
  static SharedPreferences? _p;

  // 公開: 目標日数(例: 4回/週)、今週の達成数
  static final ValueNotifier<int> targetDays = ValueNotifier<int>(4);
  static final ValueNotifier<int> completedThisWeek = ValueNotifier<int>(0);

  // Keys
  static const _kTarget = 'weekly_goal_target_days';
  static const _kWeekStart = 'weekly_goal_week_start'; // yyyyMMdd(週の月曜)
  static const _kDoneDays = 'weekly_goal_done_days';   // List<String> yyyyMMdd

  // 初期化
  static Future<void> init() async {
    _p ??= await SharedPreferences.getInstance();

    // 目標読込
    targetDays.value = _p!.getInt(_kTarget) ?? 4;

    // 週の開始（月曜）を求める
    final now = DateTime.now();
    final monday = _mondayOf(now);
    final mondayStr = _fmtYmd(monday);

    final savedWeekStart = _p!.getString(_kWeekStart);
    if (savedWeekStart != mondayStr) {
      // 週が変わった → 達成リストをリセットして今週の開始を保存
      await _p!.setString(_kWeekStart, mondayStr);
      await _p!.setStringList(_kDoneDays, <String>[]);
      completedThisWeek.value = 0;
    } else {
      // 同じ週 → 達成配列を復元
      final done = _p!.getStringList(_kDoneDays) ?? <String>[];
      completedThisWeek.value = done.length;
    }
  }

  /// 週の目標日数を更新
  static Future<void> setTargetDays(int days) async {
    _p ??= await SharedPreferences.getInstance();
    targetDays.value = days.clamp(1, 7);
    await _p!.setInt(_kTarget, targetDays.value);
  }

  /// 今日を「達成」扱いにする（重複登録はしない）
  static Future<void> markTodayDone() async {
    _p ??= await SharedPreferences.getInstance();

    final now = DateTime.now();
    await _ensureWeek(now);

    final list = _p!.getStringList(_kDoneDays) ?? <String>[];
    final today = _fmtYmd(now);

    if (!list.contains(today)) {
      list.add(today);
      await _p!.setStringList(_kDoneDays, list);
      completedThisWeek.value = list.length;
    }
  }

  /// 指定日が今週の達成日に含まれるか
  static bool isDone(DateTime d) {
    if (_p == null) return false;

    // 今週でなければ false（今週表示の丸だけ色を付けたい想定）
    final mondayNow = _p!.getString(_kWeekStart);
    if (mondayNow == null) return false;
    final mondayOfD = _fmtYmd(_mondayOf(d));
    if (mondayOfD != mondayNow) return false;

    final done = _p!.getStringList(_kDoneDays) ?? <String>[];
    return done.contains(_fmtYmd(d));
  }

  /// 画面表示用：今週（月→日）の7日リスト
  static List<DateTime> currentWeekDays() {
    final m = _mondayOf(DateTime.now());
    return List.generate(7, (i) => DateTime(m.year, m.month, m.day + i));
  }

  /// 曜日ラベル（日本語1文字）
  /// Dartの weekday は 1=Mon .. 7=Sun
  static String labelFromWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday: return '月';
      case DateTime.tuesday: return '火';
      case DateTime.wednesday: return '水';
      case DateTime.thursday: return '木';
      case DateTime.friday: return '金';
      case DateTime.saturday: return '土';
      case DateTime.sunday: return '日';
      default: return '?';
    }
  }

  // ── 内部ヘルパ ──────────────────────────────────────────────────────────

  /// 渡した日の「週の月曜」を返す
  static DateTime _mondayOf(DateTime d) {
    // weekday: Mon=1 .. Sun=7
    final diff = d.weekday - DateTime.monday; // 0..6
    final monday = DateTime(d.year, d.month, d.day).subtract(Duration(days: diff));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// yyyyMMdd
  static String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y$m$da';
  }

  /// 週が変わっていたらストレージを今週に更新
  static Future<void> _ensureWeek(DateTime base) async {
    final monday = _fmtYmd(_mondayOf(base));
    final saved = _p!.getString(_kWeekStart);
    if (saved != monday) {
      await _p!.setString(_kWeekStart, monday);
      await _p!.setStringList(_kDoneDays, <String>[]);
      completedThisWeek.value = 0;
    }
  }
}
