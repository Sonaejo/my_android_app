import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1日1レコードで体重を保存する履歴ストア（Web/モバイル両対応）
/// 内部保存形式：SharedPreferences の JSON 文字列（配列）
/// 例: [{"d":"2025-10-29","w":60.2}, ...]
class BmiHistoryStore {
  BmiHistoryStore._();

  static const _kHist = 'bmi.history.weight.v1';

  /// 観測用：履歴の変更をUIへ通知
  static final ValueNotifier<List<BmiEntry>> entries =
      ValueNotifier<List<BmiEntry>>(<BmiEntry>[]);

  static bool _inited = false;
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 起動時に一度だけ呼び出し。保存済み履歴をロード。
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    final p = await _ensurePrefs();
    final raw = p.getString(_kHist);
    if (raw == null || raw.isEmpty) {
      entries.value = <BmiEntry>[];
      return;
    }
    try {
      final List list = jsonDecode(raw) as List;
      entries.value = list
          .map((e) => BmiEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } catch (_) {
      entries.value = <BmiEntry>[];
    }
  }

  /// 本日分を upsert（存在すれば更新、なければ追加）
  static Future<void> upsertToday(double weightKg) =>
      upsertForDate(DateTime.now(), weightKg);

  /// 任意日付に upsert（ユニットテストやバックフィル用）
  static Future<void> upsertForDate(DateTime d, double weightKg) async {
    final key = _toDayKey(d);
    final list = List<BmiEntry>.from(entries.value);
    final idx = list.indexWhere((e) => e.key == key);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(weightKg: weightKg);
    } else {
      list.add(BmiEntry(date: _dateOnly(d), weightKg: weightKg));
    }
    list.sort((a, b) => a.date.compareTo(b.date));
    entries.value = list;
    await _persist(list);
  }

  /// 古い履歴を削除（最大保持日数を制限）
  static Future<void> prune({int keepDays = 365}) async {
    if (entries.value.isEmpty) return;
    final cutoff = _dateOnly(DateTime.now().subtract(Duration(days: keepDays)));
    final list = entries.value.where((e) => e.date.isAfter(cutoff) || e.date.isAtSameMomentAs(cutoff)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (list.length == entries.value.length) return;
    entries.value = list;
    await _persist(list);
  }

  /// 直近N日ぶんを取得（穴埋めはしない。記録した日のみ）
  static List<BmiEntry> recent({int days = 90}) {
    if (entries.value.isEmpty) return const <BmiEntry>[];
    final since = _dateOnly(DateTime.now().subtract(Duration(days: days)));
    return entries.value.where((e) => !e.date.isBefore(since)).toList();
  }

  /// 連続線で滑らかに見せたい場合の簡易バックフィル（任意）
  /// 記録のない日は直近の値を延長して埋める。
  static List<BmiEntry> recentFilled({int days = 90}) {
    final since = _dateOnly(DateTime.now().subtract(Duration(days: days - 1)));
    final map = {for (final e in entries.value) e.key: e};
    final out = <BmiEntry>[];

    BmiEntry? last;
    for (int i = 0; i < days; i++) {
      final d = _dateOnly(since.add(Duration(days: i)));
      final k = _toDayKey(d);
      if (map.containsKey(k)) {
        last = map[k];
        out.add(last!);
      } else if (last != null) {
        out.add(BmiEntry(date: d, weightKg: last.weightKg));
      }
    }
    // 全く記録なしなら空
    return out;
  }

  /// すべて削除（設定のリセット等）
  static Future<void> clearAll() async {
    entries.value = <BmiEntry>[];
    final p = await _ensurePrefs();
    await p.remove(_kHist);
  }

  // --------------------

  static Future<void> _persist(List<BmiEntry> list) async {
    final p = await _ensurePrefs();
    final arr = list.map((e) => e.toJson()).toList();
    await p.setString(_kHist, jsonEncode(arr));
  }

  static String _toDayKey(DateTime d) {
    final x = _dateOnly(d);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

class BmiEntry {
  final DateTime date;
  final double weightKg;

  BmiEntry({required this.date, required this.weightKg});

  String get key =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  BmiEntry copyWith({DateTime? date, double? weightKg}) =>
      BmiEntry(date: date ?? this.date, weightKg: weightKg ?? this.weightKg);

  Map<String, dynamic> toJson() => {
        'd': key,
        'w': weightKg,
      };

  static BmiEntry fromJson(Map<String, dynamic> json) {
    final d = (json['d'] as String).split('-').map(int.parse).toList();
    return BmiEntry(
      date: DateTime(d[0], d[1], d[2]),
      weightKg: (json['w'] as num).toDouble(),
    );
    }
}
