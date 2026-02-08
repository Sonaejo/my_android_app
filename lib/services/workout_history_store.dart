// lib/services/workout_history_store.dart
import 'dart:convert';
import 'package:flutter/foundation.dart'; // debugPrint
import 'package:shared_preferences/shared_preferences.dart';

/// 1件のワークアウト履歴
class WorkoutHistoryEntry {
  final int ts; // epoch millis
  final String mode; // 'squat' | 'pushup' | 'crunch' | 'plank' | 'beginner_fullbody_10min' など
  final int reps; // 回数（ルーチンは 1回 として扱う）
  final double sec; // 経過秒
  final double kcal; // 消費カロリー

  const WorkoutHistoryEntry({
    required this.ts,
    required this.mode,
    required this.reps,
    required this.sec,
    required this.kcal,
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(ts);

  Map<String, dynamic> toJson() => {
        'ts': ts,
        'mode': mode,
        'reps': reps,
        'sec': sec,
        'kcal': kcal,
      };

  static WorkoutHistoryEntry fromJson(Map<String, dynamic> j) {
    num _num(v) => (v is num) ? v : num.tryParse('$v') ?? 0;
    return WorkoutHistoryEntry(
      ts: _num(j['ts']).toInt(),
      mode: (j['mode'] ?? 'unknown').toString(),
      reps: _num(j['reps']).toInt(),
      sec: _num(j['sec']).toDouble(),
      kcal: _num(j['kcal']).toDouble(),
    );
  }
}

/// 種目ごとの集計
class WorkoutModeSummary {
  final String mode;
  final int workouts; // その種目を行った回数（セッション数）
  final int totalReps;
  final double totalSec;
  final double totalKcal;

  const WorkoutModeSummary({
    required this.mode,
    required this.workouts,
    required this.totalReps,
    required this.totalSec,
    required this.totalKcal,
  });
}

/// 期間トータルのサマリー（週間サマリー用）
class WorkoutPeriodSummary {
  final DateTime start; // 期間開始（日付）
  final DateTime end; // 期間終了（日付）※「含む」意味
  final int totalWorkouts;
  final int totalReps;
  final double totalSec;
  final double totalKcal;
  final Map<String, WorkoutModeSummary> byMode;

  const WorkoutPeriodSummary({
    required this.start,
    required this.end,
    required this.totalWorkouts,
    required this.totalReps,
    required this.totalSec,
    required this.totalKcal,
    required this.byMode,
  });
}

class WorkoutHistoryStore {
  static const _kKey = 'workout_history_v1';

  /// 起動時初期化（将来のマイグレーション用に確保）
  static Future<void> init() async {
    await SharedPreferences.getInstance();
  }

  // ─────────────────────────────────────────────────────────────
  // ✅ 共通の「安全に保存する」API
  // ─────────────────────────────────────────────────────────────

  /// どの種目でもこれを呼ぶ。reps=0 の保存を防ぎ、保存後に必ずログ出力。
  static Future<void> addWorkout({
    required String mode,
    required int reps,
    required double sec,
    required double kcal,
    DateTime? at,
    bool skipIfZeroReps = true,
  }) async {
    final safeMode = mode.trim().isEmpty ? 'unknown' : mode.trim();
    final safeReps = reps < 0 ? 0 : reps;
    final safeSec = sec.isNaN || sec.isInfinite ? 0.0 : sec;
    final safeKcal = kcal.isNaN || kcal.isInfinite ? 0.0 : kcal;

    if (skipIfZeroReps && safeReps == 0) {
      debugPrint(
          '[History] skip save because reps=0 (mode=$safeMode, sec=$safeSec, kcal=$safeKcal)');
      await debugDumpRaw(); // 何が入ってるかは出す
      return;
    }

    final entry = WorkoutHistoryEntry(
      ts: (at ?? DateTime.now()).millisecondsSinceEpoch,
      mode: safeMode,
      reps: safeReps,
      sec: safeSec,
      kcal: safeKcal,
    );

    await addEntry(entry);
    await debugDumpRaw(); // 保存後に必ず中身を出す
  }

  /// 履歴を1件追加保存（低レベルAPI）
  static Future<void> addEntry(WorkoutHistoryEntry e) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    final list = <Map<String, dynamic>>[];

    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final x in decoded) {
          if (x is Map) {
            list.add(Map<String, dynamic>.from(x));
          }
        }
      }
    }

    list.add(e.toJson());
    await p.setString(_kKey, jsonEncode(list));

    debugPrint(
        '[History] saved: mode=${e.mode}, reps=${e.reps}, sec=${e.sec}, kcal=${e.kcal}, ts=${e.ts}');
  }

  /// 期間で抽出（start <= d < end）
  static Future<List<WorkoutHistoryEntry>> listBetween(
      DateTime start, DateTime end) async {
    final all = await _loadAll();
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return all
        .where((it) {
          final d =
              DateTime(it.dateTime.year, it.dateTime.month, it.dateTime.day);
          return !d.isBefore(s) && d.isBefore(e);
        })
        .toList()
      ..sort((a, b) => b.ts.compareTo(a.ts)); // 新しい順
  }

  /// 期間内で「実施があった日」を ISO(yyyy-mm-dd) で返す
  static Future<Set<String>> daysWithWorkout(
      DateTime start, DateTime end) async {
    final list = await listBetween(start, end);
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    return list.map((e) => iso(e.dateTime)).toSet();
  }

  /// start〜end（どちらも「含む」）のサマリーを作成
  static Future<WorkoutPeriodSummary> summarizeInclusive(
      DateTime start, DateTime endInclusive) async {
    final list =
        await listBetween(start, endInclusive.add(const Duration(days: 1)));

    int totalWorkouts = list.length;
    int totalReps = 0;
    double totalSec = 0;
    double totalKcal = 0;

    final byMode = <String, WorkoutModeSummary>{};

    for (final e in list) {
      totalReps += e.reps;
      totalSec += e.sec;
      totalKcal += e.kcal;

      final prev = byMode[e.mode];
      if (prev == null) {
        byMode[e.mode] = WorkoutModeSummary(
          mode: e.mode,
          workouts: 1,
          totalReps: e.reps,
          totalSec: e.sec,
          totalKcal: e.kcal,
        );
      } else {
        byMode[e.mode] = WorkoutModeSummary(
          mode: e.mode,
          workouts: prev.workouts + 1,
          totalReps: prev.totalReps + e.reps,
          totalSec: prev.totalSec + e.sec,
          totalKcal: prev.totalKcal + e.kcal,
        );
      }
    }

    return WorkoutPeriodSummary(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(endInclusive.year, endInclusive.month, endInclusive.day),
      totalWorkouts: totalWorkouts,
      totalReps: totalReps,
      totalSec: totalSec,
      totalKcal: totalKcal,
      byMode: byMode,
    );
  }

  /// start〜end（どちらも「含む」）の履歴を日付ごとにグルーピング
  static Future<Map<DateTime, List<WorkoutHistoryEntry>>> groupByDayInclusive(
      DateTime start, DateTime endInclusive) async {
    final list =
        await listBetween(start, endInclusive.add(const Duration(days: 1)));
    final map = <DateTime, List<WorkoutHistoryEntry>>{};

    for (final e in list) {
      final d = DateTime(e.dateTime.year, e.dateTime.month, e.dateTime.day);
      final bucket = map[d] ?? <WorkoutHistoryEntry>[];
      bucket.add(e);
      map[d] = bucket;
    }

    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    final sortedMap = <DateTime, List<WorkoutHistoryEntry>>{};
    for (final k in sortedKeys) {
      final entries = map[k]!..sort((a, b) => b.ts.compareTo(a.ts));
      sortedMap[k] = entries;
    }
    return sortedMap;
  }

  /// モード → 日本語ラベル
  static String labelForMode(String mode) {
    switch (mode) {
      case 'squat':
        return 'スクワット';
      case 'pushup':
        return '腕立て伏せ';
      case 'crunch':
        return '腹筋';
      case 'plank':
        return 'プランク';

      // ✅ 追加：初心者メニュー（ルーチン）
      case 'beginner_fullbody_10min':
        return '初心者：全身ベーシック（10分）';

      default:
        return mode;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ✅ SharedPreferencesの生JSONを出す
  // ─────────────────────────────────────────────────────────────
  static Future<void> debugDumpRaw() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    debugPrint('==== $_kKey RAW ====');
    debugPrint(raw ?? '(null)');
    debugPrint('====================');
  }

  // ---- 内部: すべて取得
  static Future<List<WorkoutHistoryEntry>> _loadAll() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    if (raw == null || raw.isEmpty) return <WorkoutHistoryEntry>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <WorkoutHistoryEntry>[];
    return decoded
        .whereType<Map>()
        .map((m) => WorkoutHistoryEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}
