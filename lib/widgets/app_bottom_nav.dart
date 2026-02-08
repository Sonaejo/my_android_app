// lib/widgets/app_bottom_nav.dart
import 'package:flutter/material.dart';

enum AppTab { training, others, report, settings }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.active});
  final AppTab active;

  @override
  Widget build(BuildContext context) {
    const accentBlue = Color(0xFF2962FF);

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white, // 白背景に変更
          border: Border(
            top: BorderSide(color: Colors.black12), // 上部に薄い境界線
          ),
        ),
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _item(context, AppTab.training, Icons.fitness_center, 'トレーニング', '/', accentBlue),
            _item(context, AppTab.others, Icons.explore_outlined, 'その他', '/others', accentBlue),
            _item(context, AppTab.report, Icons.bar_chart, 'レポート', '/report', accentBlue),
            _item(context, AppTab.settings, Icons.settings, '設定', '/settings', accentBlue),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    AppTab tab,
    IconData icon,
    String label,
    String route,
    Color accentBlue,
  ) {
    final isActive = active == tab;

    void go() {
      if (isActive) return; // すでに表示中なら何もしない
      // スタックを積まずに切り替え（戻るで抜けないタブ式挙動）
      Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: go,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? accentBlue : Colors.black54,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? accentBlue : Colors.black54,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
