import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BmiStore {
  BmiStore._();
  static const _kHeight = 'user_height_cm';
  static const _kWeight = 'user_weight_kg';

  static const double defaultHeightCm = 165.0;
  static const double defaultWeightKg = 60.0;

  /// 画面間で共有するリアクティブ値
  static final ValueNotifier<double> heightCm = ValueNotifier(defaultHeightCm);
  static final ValueNotifier<double> weightKg = ValueNotifier(defaultWeightKg);

  static bool _inited = false;

  /// アプリ起動時に1度だけ呼ぶ
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    final p = await SharedPreferences.getInstance();
    heightCm.value = p.getDouble(_kHeight) ?? defaultHeightCm;
    weightKg.value = p.getDouble(_kWeight) ?? defaultWeightKg;
  }

  static Future<void> setHeightCm(double v) async {
    final p = await SharedPreferences.getInstance();
    heightCm.value = v;
    await p.setDouble(_kHeight, v);
  }

  static Future<void> setWeightKg(double v) async {
    final p = await SharedPreferences.getInstance();
    weightKg.value = v;
    await p.setDouble(_kWeight, v);
  }
}
