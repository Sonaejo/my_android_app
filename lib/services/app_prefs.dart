import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart' as cam;

/// UIに出す解像度の選択肢（必要なら増やせます）
enum AppResolution { p480, p720, p1080 }

/// FPSの上限（処理側でサンプリングして制限）
enum AppMaxFps { fps15, fps30, fps60 }

extension AppResolutionX on AppResolution {
  String get label => switch (this) {
        AppResolution.p480 => '480p',
        AppResolution.p720 => '720p',
        AppResolution.p1080 => '1080p',
      };

  /// cameraプラグイン向けのマッピング（Android/iOS）
  cam.ResolutionPreset get toCameraPreset => switch (this) {
        AppResolution.p480 => cam.ResolutionPreset.medium, // おおむね 480p
        AppResolution.p720 => cam.ResolutionPreset.high,   // おおむね 720p
        AppResolution.p1080 => cam.ResolutionPreset.veryHigh, // おおむね 1080p
      };

  /// Webの getUserMedia 向け数値（目安）
  (int width, int height) get webSize => switch (this) {
        AppResolution.p480 => (640, 480),
        AppResolution.p720 => (1280, 720),
        AppResolution.p1080 => (1920, 1080),
      };
}

extension AppMaxFpsX on AppMaxFps {
  String get label => switch (this) {
        AppMaxFps.fps15 => '15 FPS',
        AppMaxFps.fps30 => '30 FPS',
        AppMaxFps.fps60 => '60 FPS',
      };

  int get value => switch (this) {
        AppMaxFps.fps15 => 15,
        AppMaxFps.fps30 => 30,
        AppMaxFps.fps60 => 60,
      };

  /// Webは getUserMedia で理想/最大を指定、モバイルは処理側で間引き
  num get webIdeal => value;
}

/// アプリで使う設定の保存/取得
class AppPrefs {
  static const _kResolution = 'camera_resolution';
  static const _kMaxFps = 'camera_max_fps';

  static Future<(AppResolution, AppMaxFps)> load() async {
    final p = await SharedPreferences.getInstance();
    final resIndex = p.getInt(_kResolution) ?? AppResolution.p720.index;
    final fpsIndex = p.getInt(_kMaxFps) ?? AppMaxFps.fps30.index;
    return (AppResolution.values[resIndex], AppMaxFps.values[fpsIndex]);
  }

  static Future<void> saveResolution(AppResolution r) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kResolution, r.index);
  }

  static Future<void> saveMaxFps(AppMaxFps f) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kMaxFps, f.index);
  }
}
