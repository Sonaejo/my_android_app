// lib/services/app_settings.dart
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings._();
  static final AppSettings I = AppSettings._();

  // Keys（単位と目標は削除）
  static const _kMirror     = 'mirror_preview';   // bool
  static const _kCamera     = 'camera_default';   // 'front' | 'back'
  static const _kResolution = 'resolution';       // '720p' | '1080p'
  static const _kFps        = 'fps_cap';          // int
  static const _kHaptics    = 'haptics_enabled';  // bool
  static const _kSound      = 'sound_enabled';    // bool
  static const _kLanguage   = 'language';         // 'ja' | 'en'

  late SharedPreferences _p;

  // Notifiers（単位・目標の Notifier も削除）
  final ValueNotifier<bool>   mirror     = ValueNotifier(true);
  final ValueNotifier<String> camera     = ValueNotifier('front');
  final ValueNotifier<String> resolution = ValueNotifier('720p');
  final ValueNotifier<int>    fps        = ValueNotifier(30);

  final ValueNotifier<bool>   haptics    = ValueNotifier(true);
  final ValueNotifier<bool>   sound      = ValueNotifier(false);
  final ValueNotifier<Locale> locale     = ValueNotifier(const Locale('ja'));

  // 初期化
  static Future<void> init() async {
    I._p = await SharedPreferences.getInstance();
    I._loadAll();
  }

  void _loadAll() {
    mirror.value     = _p.getBool(_kMirror) ?? true;
    camera.value     = _p.getString(_kCamera) ?? 'front';
    resolution.value = _p.getString(_kResolution) ?? '720p';
    fps.value        = _p.getInt(_kFps) ?? 30;

    haptics.value    = _p.getBool(_kHaptics) ?? true;
    sound.value      = _p.getBool(_kSound) ?? false;

    final lang = _p.getString(_kLanguage) ?? 'ja';
    locale.value = (lang == 'ja') ? const Locale('ja') : const Locale('en');
  }

  // Setter
  Future<void> setMirror(bool v) async { await _p.setBool(_kMirror, v); mirror.value = v; }
  Future<void> setCamera(String v) async { await _p.setString(_kCamera, v); camera.value = v; }
  Future<void> setResolution(String v) async { await _p.setString(_kResolution, v); resolution.value = v; }
  Future<void> setFps(int v) async { await _p.setInt(_kFps, v); fps.value = v; }

  Future<void> setHaptics(bool v) async { await _p.setBool(_kHaptics, v); haptics.value = v; }
  Future<void> setSound(bool v) async { await _p.setBool(_kSound, v); sound.value = v; }

  Future<void> setLanguage(String v) async {
    await _p.setString(_kLanguage, v);
    locale.value = (v == 'ja') ? const Locale('ja') : const Locale('en');
  }

  // 便利関数
  Future<void> haptic() async { 
    if (haptics.value) await HapticFeedback.selectionClick(); 
  }

  Future<void> soundClick() async { 
    if (sound.value) await SystemSound.play(SystemSoundType.click); 
  }

  // カメラ向けヘルパ
  Size get targetResolution {
    switch (resolution.value) {
      case '1080p': return const Size(1920, 1080);
      case '720p':
      default:      return const Size(1280, 720);
    }
  }

  int get targetFps {
    final v = fps.value;
    if (v < 15) return 15;
    if (v > 60) return 60;
    return v;
  }
}
