// lib/screens/others_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_bottom_nav.dart';
import '../services/reminder_service.dart';

class OthersScreen extends StatelessWidget {
  const OthersScreen({super.key});

  static const _accentBlue = Color(0xFF2962FF);

  // SettingsScreen と同じキーを再利用（文字列は必ず同じ）
  static const _kReminderEnabled = 'reminder_enabled';
  static const _kReminderHour = 'reminder_hour';
  static const _kReminderMinute = 'reminder_minute';

  @override
  Widget build(BuildContext context) {
    final items = <_LinkItem>[
      _LinkItem(
        title: 'レポート',
        icon: Icons.bar_chart,
        onTap: () => Navigator.pushNamed(context, '/report'),
      ),
    ];

    // Web 以外（Android/iOS）のみリマインダーを出す
    if (!kIsWeb) {
      items.add(
        _LinkItem(
          title: 'リマインダー',
          icon: Icons.alarm,
          onTap: () => _openReminderSheet(context),
        ),
      );
    }

    // 公式サイト系（Web/Android/iOS 全部に出す）
    items.addAll([
      _LinkItem(
        title: '公式サイト',
        icon: Icons.public,
        onTap: () => _openUrl(
          context,
          'https://yukimira25811.github.io/official_site',
        ),
      ),
      _LinkItem(
        title: 'お問い合わせ',
        icon: Icons.mail,
        onTap: () => _openUrl(
          context,
          'https://yukimira25811.github.io/official_site/contact.html',
        ),
      ),
      _LinkItem(
        title: 'プライバシー',
        icon: Icons.privacy_tip_outlined,
        onTap: () => _openUrl(
          context,
          'https://yukimira25811.github.io/official_site/privacy.html',
        ),
      ),
    ]);

    const sidePad = 16.0;
    const spacing = 12.0;

    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final cols = width < 360 ? 1 : 2;
    final gridUsableW = width - sidePad * 2 - spacing * (cols - 1);
    final tileW = gridUsableW / cols;
    final tileH = cols == 1 ? 120.0 : 148.0;
    final aspect = tileW / tileH;
    final clampedTextScale = mq.textScaleFactor.clamp(1.0, 1.2);

    return MediaQuery(
      data: mq.copyWith(textScaleFactor: clampedTextScale),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'その他',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: true,
          child: LayoutBuilder(
            builder: (context, c) {
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(sidePad, 12, sidePad, 12),
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: aspect,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final it = items[i];
                  final base = _accentBlue;
                  final colorA = base;
                  final colorB = HSLColor.fromColor(base)
                      .withLightness(
                        (HSLColor.fromColor(base).lightness + 0.18)
                            .clamp(0.0, 1.0),
                      )
                      .toColor();

                  final Widget bottomLeft = (it.title == 'カウンター')
                      ? _buildCounterBadge()
                      : Icon(it.icon, color: Colors.white, size: 34);

                  return _Tile(
                    title: it.title,
                    icon: it.icon,
                    onTap: it.onTap,
                    colorA: colorA,
                    colorB: colorB,
                    bottomLeft: bottomLeft,
                  );
                },
              );
            },
          ),
        ),
        bottomNavigationBar: const AppBottomNav(active: AppTab.others),
      ),
    );
  }

  // URL/メール
  static Future<void> _openUrl(BuildContext context, String url) async {
    final uri = _normalizeUri(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('リンクを開けませんでした: $url')));
    }
  }

  // カウンター選択（※今は items に出してないけど、必要ならタイル追加で使える）
  static Future<void> _openCounterPicker(BuildContext context) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              const ListTile(
                title: Text(
                  'カウンターを選択',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.directions_run),
                title: const Text('スクワット'),
                onTap: () => Navigator.pop(ctx, 'squat'),
              ),
              ListTile(
                leading: const Icon(Icons.fitness_center),
                title: const Text('腕立て伏せ'),
                onTap: () => Navigator.pop(ctx, 'pushup'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (mode != null && context.mounted) {
      Navigator.pushNamed(context, '/counter', arguments: {'mode': mode});
    }
  }

  /// ─────────────────────────────────────────────
  /// リマインダー設定シート（Settings と同じ感じのUI）
  /// ─────────────────────────────────────────────
  static Future<void> _openReminderSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        bool loading = true;
        bool enabled = false;
        TimeOfDay time = const TimeOfDay(hour: 20, minute: 0);

        Future<void> loadPrefs(StateSetter setModalState) async {
          final prefs = await SharedPreferences.getInstance();
          final e = prefs.getBool(_kReminderEnabled) ?? false;
          final h = prefs.getInt(_kReminderHour) ?? 20;
          final m = prefs.getInt(_kReminderMinute) ?? 0;
          setModalState(() {
            loading = false;
            enabled = e;
            time = TimeOfDay(hour: h, minute: m);
          });
        }

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (loading) {
              // 初回だけロード開始
              loadPrefs(setModalState);
            }

            Future<void> toggle(bool v) async {
              setModalState(() => enabled = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(_kReminderEnabled, v);
              await prefs.setInt(_kReminderHour, time.hour);
              await prefs.setInt(_kReminderMinute, time.minute);
              await ReminderService.updateDailyReminder(
                enabled: v,
                time: time,
              );
            }

            Future<void> pickTime() async {
              final picked = await _showReminderTimePickerSheet(ctx, time);
              if (picked == null) return;

              setModalState(() => time = picked);

              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt(_kReminderHour, picked.hour);
              await prefs.setInt(_kReminderMinute, picked.minute);

              await ReminderService.updateDailyReminder(
                enabled: enabled,
                time: picked,
              );
            }

            String format(TimeOfDay t) {
              final hh = t.hour.toString().padLeft(2, '0');
              final mm = t.minute.toString().padLeft(2, '0');
              return '$hh:$mm';
            }

            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: SizedBox(
                    // 横画面でも入りやすいように最大高さを制限
                    height: 240,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ヘッダーバー
                        const SizedBox(height: 8),
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'リマインダー',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '毎日のトレーニング時間をお知らせします',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 0),

                        // 本体
                        Expanded(
                          child: loading
                              ? const Center(child: CircularProgressIndicator())
                              : Column(
                                  children: [
                                    SwitchListTile.adaptive(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      title: const Text('毎日のトレーニングリマインダー'),
                                      subtitle: const Text('指定した時刻に通知します'),
                                      value: enabled,
                                      onChanged: toggle,
                                    ),
                                    const Divider(height: 0),
                                    ListTile(
                                      enabled: enabled,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      title: const Text('リマインダー時刻'),
                                      subtitle: Text(format(time)),
                                      trailing: TextButton(
                                        onPressed: enabled ? pickTime : null,
                                        child: const Text('変更'),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// SettingsScreen と同じスタイルのホイールピッカー
  static Future<TimeOfDay?> _showReminderTimePickerSheet(
    BuildContext context,
    TimeOfDay initial,
  ) async {
    int displayHour = (initial.hour == 0) ? 24 : initial.hour; // 0 -> 24表記
    int selectedHour = displayHour.clamp(1, 24);
    int selectedMinute = initial.minute.clamp(0, 59);

    final hourController =
        FixedExtentScrollController(initialItem: selectedHour - 1);
    final minuteController =
        FixedExtentScrollController(initialItem: selectedMinute);

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 260,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
                      child: const Text('キャンセル'),
                    ),
                    const Spacer(),
                    const Text(
                      'リマインダー時刻',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        final hour24 = selectedHour % 24; // 24 -> 0
                        Navigator.of(ctx).pop(
                          TimeOfDay(hour: hour24, minute: selectedMinute),
                        );
                      },
                      child: const Text('完了'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 0),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: hourController,
                        itemExtent: 36,
                        onSelectedItemChanged: (index) {
                          selectedHour = index + 1;
                        },
                        children: List.generate(24, (i) {
                          final h = i + 1;
                          return Center(
                            child: Text(
                              h.toString().padLeft(2, '0'),
                              style: const TextStyle(fontSize: 20),
                            ),
                          );
                        }),
                      ),
                    ),
                    const Text(
                      '時',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: minuteController,
                        itemExtent: 36,
                        onSelectedItemChanged: (index) {
                          selectedMinute = index;
                        },
                        children: List.generate(60, (i) {
                          return Center(
                            child: Text(
                              i.toString().padLeft(2, '0'),
                              style: const TextStyle(fontSize: 20),
                            ),
                          );
                        }),
                      ),
                    ),
                    const Text(
                      '分',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Uri _normalizeUri(String raw) {
    final trimmed = raw.trim();
    final hasScheme =
        RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*:').hasMatch(trimmed);
    final looksLikeEmail = trimmed.contains('@') && !trimmed.contains('://');
    if (!hasScheme && looksLikeEmail) {
      return Uri.parse('mailto:$trimmed');
    }
    return Uri.parse(trimmed);
  }

  static Widget _buildCounterBadge() {
    return const SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        children: [
          Align(alignment: Alignment.bottomLeft, child: _BadgeBody()),
          Positioned(left: 4, bottom: 12, child: _BadgeWindow()),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 26),
              child: _BadgeKnob(),
            ),
          ),
          Positioned(left: 12, bottom: 22, child: _BadgeTopBtn()),
        ],
      ),
    );
  }
}

// ── バッジ関連 ─────────────────────────────
class _BadgeBody extends StatelessWidget {
  const _BadgeBody();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white70, width: 1.2),
      ),
    );
  }
}

class _BadgeWindow extends StatelessWidget {
  const _BadgeWindow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 7,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: const LinearGradient(
          colors: [Color(0xFF3D7DFF), Color(0xFF1B52E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white70, width: 0.8),
      ),
    );
  }
}

class _BadgeKnob extends StatelessWidget {
  const _BadgeKnob();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.white70, width: 1),
      ),
    );
  }
}

class _BadgeTopBtn extends StatelessWidget {
  const _BadgeTopBtn();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(1.5),
        border: Border.all(color: Colors.white70, width: 1),
      ),
    );
  }
}

// ── タイル / LinkItem ─────────────────────────
class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.icon,
    required this.onTap,
    required this.colorA,
    required this.colorB,
    required this.bottomLeft,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color colorA;
  final Color colorB;
  final Widget bottomLeft;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [colorA, colorB],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                blurRadius: 8,
                offset: Offset(0, 4),
                color: Color(0x1A000000),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: bottomLeft,
                ),
                const Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(
                    Icons.arrow_outward,
                    color: Colors.white70,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  _LinkItem({required this.title, required this.icon, required this.onTap});
}
