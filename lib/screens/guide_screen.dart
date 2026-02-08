// lib/screens/guide_screen.dart
import 'package:flutter/material.dart';
import 'guides_data.dart'; // ← データ

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments
            as Map<String, dynamic>? ??
        {};
    final topic = (args['topic'] as String?) ?? '';
    final content = guides[topic]; // ← データは guides から取得

    return Scaffold(
      appBar: AppBar(
        title: Text(content?.title ?? 'トレーニング解説'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: content == null
          ? const _ComingSoon()
          : _GuideBody(content: content),
    );
  }
}

class _GuideBody extends StatelessWidget {
  const _GuideBody({required this.content});
  final GuideContent content;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 720; // ← ブレークポイント（必要なら調整）

    if (isWide) {
      // ===== PC/タブレット：左右2カラム =====
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左：正方形GIF（コンテナの横幅に合わせて1:1）
            Expanded(
              flex: 1,
              child: _GuideMediaSquare(gifAsset: content.gifAsset),
            ),
            const SizedBox(width: 26),
            // 右：説明（スクロール可能にする）
            Expanded(
              flex: 1,
              child: _GuideDetails(content: content),
            ),
          ],
        ),
      );
    } else {
      // ===== スマホ：上下1カラム =====
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _GuideHeader(content: content),
          const SizedBox(height: 12),

          // 上：GIF（スマホは横長 4:3 推奨）
          if (content.gifAsset != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.asset(
                  content.gifAsset!,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 下：説明
          _GuideSections(content: content),
          const SizedBox(height: 24),

          // ★ 追加：開始＋戻るボタン
          _GuideActions(content: content),
        ],
      );
    }
  }
}

/* 省略：_ComingSoon, _Label, _Bullet, _Check, _Warn, _Note は今のままでOK */
class _ComingSoon extends StatelessWidget {
  const _ComingSoon();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pending, size: 48, color: Colors.black26),
              SizedBox(height: 12),
              Text(
                'このトピックの解説は準備中です',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext c) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _Check extends StatelessWidget {
  const _Check(this.text);
  final String text;
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle,
                size: 16, color: Colors.green),
            const SizedBox(width: 6),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _Warn extends StatelessWidget {
  const _Warn(this.text);
  final String text;
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: Colors.orange),
            const SizedBox(width: 6),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFECB3)),
        ),
        child: Text(text),
      );
}

class _GuideMediaSquare extends StatelessWidget {
  const _GuideMediaSquare({this.gifAsset});
  final String? gifAsset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final size = c.maxWidth * 0.85; // ← 幅の85%サイズに縮小
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: size,
              height: size, // ← 正方形のまま
              color: const Color(0xFFEFF3FF),
              child: (gifAsset != null)
                  ? Image.asset(
                      gifAsset!,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                      fit: BoxFit.cover,
                    )
                  : const Center(
                      child: Icon(
                        Icons.motion_photos_on,
                        size: 48,
                        color: Colors.black26,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _GuideDetails extends StatelessWidget {
  const _GuideDetails({required this.content});
  final GuideContent content;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        _GuideHeader(content: content),
        const SizedBox(height: 12),
        _GuideSections(content: content),
        const SizedBox(height: 24),

        // ★ 追加：開始＋戻るボタン
        _GuideActions(content: content),
      ],
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader({required this.content});
  final GuideContent content;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF3FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(content.icon, color: const Color(0xFF2962FF)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '難易度：${content.level}',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideSections extends StatelessWidget {
  const _GuideSections({required this.content});
  final GuideContent content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('主働筋'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: content.muscles
              .map(
                (m) => Chip(
                  label: Text(m),
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),

        const _Label('手順'),
        ...content.steps.map((s) => _Bullet(s)),
        const SizedBox(height: 16),

        const _Label('フォームのコツ'),
        ...content.cues.map((s) => _Check(s)),
        const SizedBox(height: 16),

        const _Label('よくあるミス'),
        ...content.mistakes.map((s) => _Warn(s)),

        if (content.caution != null) ...[
          const SizedBox(height: 16),
          const _Label('注意'),
          _Note(content.caution!),
        ],
      ],
    );
  }
}

/// ★ 追加：開始/戻るボタン共通ウィジェット
class _GuideActions extends StatelessWidget {
  const _GuideActions({required this.content});
  final GuideContent content;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 開始ボタン → シンプルタイマーへ遷移
        FilledButton(
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/simple_timer',
              arguments: {
                'title': content.title, // 画面上部に表示
                'workSeconds': 30, // ★ ここを変えれば秒数やセット数を調整できる
                'restSeconds': 10,
                'sets': 3,
                // 'readySeconds': 5, // 変えたい場合は追加
              },
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2962FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size.fromHeight(44),
          ),
          child: const Text('開始'),
        ),
        const SizedBox(height: 8),
        // 戻るボタン
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size.fromHeight(44),
          ),
          child: const Text('戻る'),
        ),
      ],
    );
  }
}
