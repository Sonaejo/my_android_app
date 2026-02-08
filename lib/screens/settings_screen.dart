// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // （将来の拡張用に残してOK）
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/app_bottom_nav.dart';
import '../widgets/number_dial_sheet.dart';
import '../services/bmi_store.dart';
import '../services/voice_coach.dart'; // ★ 音声ガイドON/OFFと連動

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _accentBlue = Color(0xFF2962FF);

  // 既存キー
  static const _kMirror     = 'mirror_preview';
  static const _kCamera     = 'camera_default';
  static const _kResolution = 'resolution';
  static const _kFps        = 'fps_cap';

  // ★ 音声ガイド設定キー
  static const _kVoiceGuide = 'voice_guide_enabled';

  // ★ 今日の目標回数キー
  static const _kDailyGoal  = 'daily_goal_reps';

  bool _loading = true;

  // 一般設定
  bool _mirror = true;
  String _camera = 'front';
  String _resolution = '720p';
  int _fps = 30;

  // 音声ガイド
  bool _voiceGuideEnabled = true;

  // ★ 今日の目標回数（初期値 30 回）
  int _dailyGoal = 30;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    final mirror     = prefs.getBool(_kMirror) ?? true;
    final camera     = prefs.getString(_kCamera) ?? 'front';
    final resolution = prefs.getString(_kResolution) ?? '720p';
    final fps        = prefs.getInt(_kFps) ?? 30;

    final voiceGuideEnabled = prefs.getBool(_kVoiceGuide) ?? true;
    final dailyGoal         = prefs.getInt(_kDailyGoal) ?? 30;

    setState(() {
      _mirror     = mirror;
      _camera     = camera;
      _resolution = resolution;
      _fps        = fps;

      _voiceGuideEnabled = voiceGuideEnabled;
      _dailyGoal         = dailyGoal;

      _loading = false;
    });

    // ★ VoiceCoach（音声ガイドON/OFF）を設定に合わせる
    VoiceCoach.instance.setEnabled(_voiceGuideEnabled);
  }

  Future<void> _savePref<T>(String key, T value) async {
    final p = await SharedPreferences.getInstance();
    if (value is String) await p.setString(key, value);
    if (value is int)    await p.setInt(key, value);
    if (value is bool)   await p.setBool(key, value);
  }

  // ---- BMI編集（ダイヤルのまま） --------------------------------------
  Future<void> _editHeight() async {
    final result = await showNumberDialEditor(
      context: context,
      title: 'BMIを編集（身長）',
      unit: 'cm',
      initial: BmiStore.heightCm.value,
      min: 120.0,
      max: 220.0,

      // ★ 修正：身長も小数点1桁まで編集できるようにする
      step: 0.1,
      labelBuilder: (v) => v.toStringAsFixed(1),
    );
    if (result != null) await BmiStore.setHeightCm(result);
  }

  Future<void> _editWeight() async {
    final result = await showNumberDialEditor(
      context: context,
      title: 'BMIを編集（体重）',
      unit: 'kg',
      initial: BmiStore.weightKg.value,
      min: 20.0,
      max: 200.0,
      step: 0.1,
      labelBuilder: (v) => v.toStringAsFixed(1),
    );
    if (result != null) await BmiStore.setWeightKg(result);
  }

  // ---- 今日の目標回数編集 ---------------------------------------------
  Future<void> _editDailyGoal() async {
    final result = await showNumberDialEditor(
      context: context,
      title: '今日の目標回数',
      unit: '回',
      initial: _dailyGoal.toDouble(),
      min: 1.0,
      max: 300.0,
      step: 1.0,
      labelBuilder: (v) => v.toStringAsFixed(0),
    );
    if (result != null) {
      final value = result.round().clamp(1, 300);
      await _savePref(_kDailyGoal, value);
      setState(() {
        _dailyGoal = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      bottomNavigationBar: const AppBottomNav(active: AppTab.settings),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── BMI 基本情報 ──────────────────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader('BMI 基本情報'),
                  ValueListenableBuilder<double>(
                    valueListenable: BmiStore.heightCm,
                    builder: (_, h, __) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('身長'),
                      // ★ 表示は元から小数1桁になっているのでOK
                      subtitle: Text('${h.toStringAsFixed(1)} cm'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        color: _accentBlue,
                        onPressed: _editHeight,
                        tooltip: '身長を編集',
                      ),
                    ),
                  ),
                  const Divider(height: 0),
                  ValueListenableBuilder<double>(
                    valueListenable: BmiStore.weightKg,
                    builder: (_, w, __) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('体重'),
                      subtitle: Text('${w.toStringAsFixed(1)} kg'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        color: _accentBlue,
                        onPressed: _editWeight,
                        tooltip: '体重を編集',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── 表示設定 ─────────────────────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader('表示設定'),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('プレビューをミラー表示'),
                    value: _mirror,
                    onChanged: (v) async {
                      setState(() => _mirror = v);
                      await _savePref(_kMirror, v);
                    },
                  ),
                  const Divider(height: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('デフォルトカメラ'),
                    subtitle: Text(_camera == 'front' ? 'フロント' : 'バック'),
                    trailing: DropdownButton<String>(
                      value: _camera,
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _camera = v);
                        await _savePref(_kCamera, v);
                      },
                      items: const [
                        DropdownMenuItem(
                          value: 'front',
                          child: Text('フロント'),
                        ),
                        DropdownMenuItem(
                          value: 'back',
                          child: Text('バック'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('解像度'),
                    subtitle: Text(_resolution),
                    trailing: DropdownButton<String>(
                      value: _resolution,
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _resolution = v);
                        await _savePref(_kResolution, v);
                      },
                      items: const [
                        DropdownMenuItem(
                          value: '720p',
                          child: Text('720p'),
                        ),
                        DropdownMenuItem(
                          value: '1080p',
                          child: Text('1080p'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('FPS制限'),
                    subtitle: Text('$_fps fps'),
                    trailing: DropdownButton<int>(
                      value: _fps,
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _fps = v);
                        await _savePref(_kFps, v);
                      },
                      items: const [
                        DropdownMenuItem(value: 30, child: Text('30')),
                        DropdownMenuItem(value: 60, child: Text('60')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── トレーニング目標 ────────────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader('トレーニング目標'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('今日の目標回数'),
                    subtitle: const Text('カウンター画面のゴール判定に使われます'),
                    trailing: Text(
                      '$_dailyGoal 回',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _accentBlue,
                      ),
                    ),
                    onTap: _editDailyGoal,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── 音声 ────────────────────────────────────────────────────
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader('音声'),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('フォーム指示の音声ガイド'),
                    subtitle: Text(
                      _voiceGuideEnabled
                          ? 'カウント画面の左下の指示を自動で読み上げます'
                          : '音声読み上げをオフにします',
                    ),
                    value: _voiceGuideEnabled,
                    onChanged: (v) async {
                      setState(() => _voiceGuideEnabled = v);
                      await _savePref(_kVoiceGuide, v);
                      // ★ VoiceCoach にも反映
                      VoiceCoach.instance.setEnabled(v);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
      ),
    );
  }
}
