// lib/services/bmi_store.dart
import 'package:shared_preferences/shared_preferences.dart';

class BmiStore {
  static const _kHeightCm = 'height_cm';
  static const _kWeightKg = 'weight_kg';

  /// 値が未保存の場合のデフォルト
  static const defaultHeightCm = 165.0;
  static const defaultWeightKg = 60.0;

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static Future<double> getHeightCm() async {
    final p = await _prefs();
    return p.getDouble(_kHeightCm) ?? defaultHeightCm;
    // 旧来int保存していた場合も考慮するなら:
    // return (p.getDouble(_kHeightCm) ?? p.getInt(_kHeightCm)?.toDouble()) ?? defaultHeightCm;
  }

  static Future<double> getWeightKg() async {
    final p = await _prefs();
    return p.getDouble(_kWeightKg) ?? defaultWeightKg;
  }

  static Future<void> setHeightCm(double v) async {
    final p = await _prefs();
    await p.setDouble(_kHeightCm, v);
  }

  static Future<void> setWeightKg(double v) async {
    final p = await _prefs();
    await p.setDouble(_kWeightKg, v);
  }

  static Future<void> setBoth({required double heightCm, required double weightKg}) async {
    final p = await _prefs();
    await p.setDouble(_kHeightCm, heightCm);
    await p.setDouble(_kWeightKg, weightKg);
  }
}
