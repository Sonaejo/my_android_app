// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav.dart';
import '../services/weekly_goal_store.dart';
import 'workout_history_screen.dart'; // 履歴画面

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const accentBlue = Color(0xFF2962FF);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _filter = '腹筋'; // 初期タブ
  String _query = '';

  // ─────────────────────────────────────────────────────────────────────
  // フォームチェック用 ワークアウト一覧（カメラでフォーム判定）
  // ─────────────────────────────────────────────────────────────────────
  final List<_Workout> _workouts = const [
    _Workout(
      title: '腹筋',
      route: '/counter',
      tags: {'腹筋'},
      keywords: {'シットアップ', 'クランチ', 'core', 'beginner'},
      mode: 'crunch',
      thumbnail: AssetImage('assets/images/abs_beginner.png'),
    ),

    // ✅ 腕 + 胸部 を統合
    _Workout(
      title: '腕&胸部',
      route: '/counter',
      tags: {'腕&胸部'},
      keywords: {
        '腕',
        '胸部',
        '胸',
        '大胸筋',
        'プッシュアップ',
        '腕立て伏せ',
        '膝つきプッシュアップ',
        'インクラインプッシュアップ',
        'デクラインプッシュアップ',
        '上腕三頭筋',
        '上腕二頭筋',
        'beginner',
      },
      mode: 'pushup',
      // 画像は好みで arm/chest どっちでもOK
      thumbnail: AssetImage('assets/images/chest_beginner.png'),
    ),

    _Workout(
      title: '脚',
      route: '/counter',
      tags: {'脚'},
      keywords: {'スクワット', 'カーフレイズ', 'beginner', '下半身'},
      mode: 'squat',
      thumbnail: AssetImage('assets/images/leg_beginner.png'),
    ),
    _Workout(
      title: '体幹',
      route: '/counter',
      tags: {'体幹'},
      keywords: {'プランク', 'バードドッグ', 'isometric', 'beginner'},
      mode: 'plank',
      thumbnail: AssetImage('assets/images/core_beginner.png'),
    ),
  ];

  // ---- 絞り込み（フォームチェック） ----------------------------------------
  // ※ 検索文字列が空のときだけタブで絞る。
  //   1文字でも入力されたらタブ無視で「全ワークアウト」から検索。
  List<_Workout> get _filteredForm {
    final q = _normalize(_query);
    if (q.isEmpty) {
      // 検索なし：タブで絞り込み
      return _workouts.where((w) => w.tags.contains(_filter)).toList();
    }

    // 検索あり：タブ無視で全件から検索
    return _workouts.where((w) {
      final haystacks = <String>{
        w.title,
        ...w.tags,
        ...w.keywords,
      }.map(_normalize).toList();
      return haystacks.any((h) => h.contains(q));
    }).toList();
  }

  // ---- 軽量な日本語向け正規化 ----------------------------------------------
  String _normalize(String s) {
    final trimmed = s.trim().replaceAll(RegExp(r'\s+'), '');
    final lower = trimmed.toLowerCase();
    final sb = StringBuffer();
    for (final rune in lower.runes) {
      // カタカナ → ひらがな
      if (rune >= 0x30A1 && rune <= 0x30F6) {
        sb.writeCharCode(rune - 0x60);
      } else {
        sb.writeCharCode(rune);
      }
    }
    return sb.toString();
  }

  void _clearQuery() => setState(() => _query = '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '自宅トレーニング',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 72),
        children: [
          _SearchBar(
            value: _query,
            onChanged: (q) => setState(() => _query = q),
            onClear: _clearQuery,
          ),
          const SizedBox(height: 16),

          // ── 週の目標（保存内容に追従） → 曜日タップで履歴へ
          _WeeklyGoal(onEditTap: () async {
            final changed = await Navigator.pushNamed(context, '/weekly_goal');
            if (changed != null) setState(() {}); // 再描画で反映
          }),

          const SizedBox(height: 16),

          // ★ ここを入れ替え：チュートリアルを先に
          _ChallengeCard(
            title: 'チュートリアル',
            subtitle: 'アプリの使い方とフォームチェックの基本を学びましょう！',
            ctaText: '開始',
            onPressedRoute: '/tutorial_welcome',
            mode: 'pushup',
            image: const AssetImage('assets/images/tutorial_training.png'),
          ),
          const SizedBox(height: 16),

          // ★ 「全身7日間…」→「【初心者向け】定番トレーニングメニュー」系に変更
          _ChallengeCard(
            title: '【初心者向け】定番トレーニングメニュー',
            subtitle: '全身をバランスよく鍛える基本メニュー。まずはここから始めよう！',
            ctaText: '開始',
            onPressedRoute: '/beginner_menu', // ←ここ
            mode: 'squat', // ここはもう使わなくてもOK（カード定義都合なら残してOK）
            image: const AssetImage('assets/images/gym_squat.png'),
          ),

          const SizedBox(height: 20),

          // ───────────────── フォームチェックモード ─────────────────
          const _SectionHeader(title: 'フォームチェックモード'),
          const SizedBox(height: 8),

          // 検索中でもタブUIはそのまま出すが、
          // 実際の絞り込みは _filteredForm が「検索優先」でやってくれる。
          _TargetChips(
            tabs: const ['腹筋', '腕&胸部', '脚', '体幹'],
            onChanged: (tab) => setState(() => _filter = tab),
          ),
          const SizedBox(height: 12),
          ..._filteredForm.map(
            (w) => _WorkoutTile(
              title: w.title,
              route: w.route,
              mode: w.mode,
              thumbnail: w.thumbnail,
            ),
          ),

          const SizedBox(height: 24),

          // ───────────────── トレーニング一覧（解説） ────────────────
          const _SectionHeader(title: 'トレーニング一覧'),
          const SizedBox(height: 8),
          // ★ 検索クエリと normalize 関数を渡して、
          //   「検索ありならタブ無視で全カテゴリ検索」にする
          _TrainingGuideTabbedGrid(
            query: _query,
            normalize: _normalize,
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(active: AppTab.training),
    );
  }
}

// ============================================================================
// モデル
// ============================================================================
class _Workout {
  final String title;
  final String route;
  final Set<String> tags;
  final Set<String> keywords;
  final String mode; // 'squat' | 'pushup' | 'plank' | 'crunch'
  final ImageProvider? thumbnail;

  const _Workout({
    required this.title,
    required this.route,
    required this.tags,
    this.keywords = const {},
    required this.mode,
    this.thumbnail,
  });
}

// ============================================================================
// 共通ウィジェット
// ============================================================================
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController.fromValue(
        TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        ),
      ),
      onChanged: onChanged,
      style: const TextStyle(color: Colors.black87),
      cursorColor: HomeScreen.accentBlue,
      decoration: InputDecoration(
        hintText: 'ワークアウト名・タグで検索（例: 腹筋 / 脚 / プッシュアップ）',
        hintStyle: const TextStyle(color: Colors.black45),
        prefixIcon: const Icon(Icons.search, color: Colors.black54),
        suffixIcon: value.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, color: Colors.black45),
                onPressed: onClear,
                tooltip: 'クリア',
              ),
        filled: true,
        fillColor: const Color(0xFFF2F3F5),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// === 一週間の目標 ===========================================================
class _WeeklyGoal extends StatefulWidget {
  const _WeeklyGoal({required this.onEditTap});
  final VoidCallback onEditTap;

  @override
  State<_WeeklyGoal> createState() => _WeeklyGoalState();
}

class _WeeklyGoalState extends State<_WeeklyGoal> {
  @override
  Widget build(BuildContext context) {
    final weekDays = WeeklyGoalStore.currentWeekDays();
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Color(0x14000000),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── タイトル & 編集ボタン ─────────────────────
          Row(
            children: [
              const Text(
                '一週間の目標',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // 右上の「✎ 0/4」（タップで設定画面へ）
              InkWell(
                onTap: widget.onEditTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: ValueListenableBuilder<int>(
                    valueListenable: WeeklyGoalStore.targetDays,
                    builder: (_, target, __) {
                      return ValueListenableBuilder<int>(
                        valueListenable: WeeklyGoalStore.completedThisWeek,
                        builder: (_, done, __) {
                          return Row(
                            children: [
                              const Icon(Icons.edit,
                                  size: 18, color: Colors.black54),
                              const SizedBox(width: 6),
                              Text(
                                '$done/$target',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ── 週の並び（開始曜日を反映） / 曜日セルはボタン化 → 履歴へ ─────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekDays.map((d) {
              final isToday = d.year == now.year &&
                  d.month == now.month &&
                  d.day == now.day;
              final isDone = WeeklyGoalStore.isDone(d); // その日が達成済みか

              final bgColor = isToday
                  ? HomeScreen.accentBlue
                  : (isDone
                      ? HomeScreen.accentBlue.withOpacity(0.2)
                      : Colors.transparent);

              final textColor = isToday ? Colors.white : Colors.black87;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${d.day}',
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  // ★ 曜日チップ = ボタン：タップで履歴画面へ
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WorkoutHistoryScreen(
                            initialDate: d, // この日をフォーカス
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.black26),
                      ),
                      child: Text(
                        WeeklyGoalStore.labelFromWeekday(d.weekday),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// === チャレンジカード =======================================================
class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.onPressedRoute,
    required this.mode,
    this.image,
  });

  final String title;
  final String subtitle;
  final String ctaText;
  final String onPressedRoute;
  final String mode; // 'squat' | 'pushup'
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2962FF), Color(0xFF5C85FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 112,
              height: 112,
              color: Colors.white.withOpacity(0.18),
              child: image != null
                  ? Image(image: image!, fit: BoxFit.cover)
                  : const Icon(Icons.fitness_center,
                      color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, height: 1.2),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2962FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(96, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        onPressedRoute,
                        arguments: {'mode': mode},
                      );
                    },
                    child: Text(ctaText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// === ターゲットチップ =======================================================
class _TargetChips extends StatefulWidget {
  const _TargetChips({required this.tabs, this.onChanged});
  final List<String> tabs;
  final ValueChanged<String>? onChanged;

  @override
  State<_TargetChips> createState() => _TargetChipsState();
}

class _TargetChipsState extends State<_TargetChips> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(widget.tabs.length, (i) {
            final selected = i == index;
            return Padding(
              padding: EdgeInsets.only(
                  right: i == widget.tabs.length - 1 ? 0 : 8),
              child: ChoiceChip(
                label: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 56),
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -1),
                      child: Text(
                        widget.tabs[i],
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.black87,
                          height: 1.0,
                        ),
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                      ),
                    ),
                  ),
                ),
                labelPadding: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                selected: selected,
                onSelected: (_) {
                  setState(() => index = i);
                  widget.onChanged?.call(widget.tabs[i]);
                },
                selectedColor: HomeScreen.accentBlue,
                backgroundColor: const Color(0xFFF2F3F5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.black26),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
        ),
      ),
    );
  }
}

// === フォームチェック用 ワークアウトタイル ================================
class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({
    required this.title,
    required this.route,
    required this.mode,
    this.thumbnail,
  });

  final String title;
  final String route;
  final String mode; // 'squat' | 'pushup' ...
  final ImageProvider? thumbnail;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF7F8FA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pushNamed(
            context,
            route,
            arguments: {'mode': mode},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(
                  image: thumbnail ??
                      const AssetImage('assets/images/placeholder.png'),
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Colors.black38),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === セクションヘッダ =======================================================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFE5E7EB),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

// === ガイド一覧（既存）＋検索対応 ==========================================
class _GuideEntry {
  final String label;
  final String topic;
  final String category; // どのタブ（部位）か

  const _GuideEntry({
    required this.label,
    required this.topic,
    required this.category,
  });
}

class _TrainingGuideTabbedGrid extends StatefulWidget {
  const _TrainingGuideTabbedGrid({
    super.key,
    required this.query,
    required this.normalize,
  });

  final String query;
  final String Function(String) normalize;

  @override
  State<_TrainingGuideTabbedGrid> createState() =>
      _TrainingGuideTabbedGridState();
}

class _TrainingGuideTabbedGridState extends State<_TrainingGuideTabbedGrid> {
  static const _tabs = <String>[
    '腹筋',
    '腕',
    '全身',
    '胸',
    '脚',
    'お尻',
    '体幹',
    '背中',
    '肩',
  ];

  late final Map<String, List<_GuideEntry>> _catalog = {
    '肩': [
      _e('レスラーブリッジ', 'wrestler_bridge', '肩'),
      _e('パイクプッシュアップ', 'pike_pushup', '肩'),
      _e('壁倒立', 'wall_handstand', '肩'),
    ],
    '胸': [
      _e('腕立て伏せ', 'pushup', '胸'),
      _e('インクラインプッシュアップ', 'incline_pushup', '胸'),
      _e('デクラインプッシュアップ', 'decline_pushup', '胸'),
      _e('膝つき腕立て伏せ', 'knee_pushup', '胸'),
    ],
    '背中': [
      _e('ボディアーチ', 'body_arch', '背中'),
      _e('懸垂', 'pullup', '背中'),
    ],
    '腹筋': [
      _e('上体起こし(腹筋)', 'situp', '腹筋'),
      _e('レッグレイズ', 'leg_raise', '腹筋'),
      _e('V字クランチ', 'v_crunch', '腹筋'),
    ],
    '体幹': [
      _e('プランク', 'plank', '体幹'),
      _e('リバースプランク', 'reverse_plank', '体幹'),
      _e('サイドプランク', 'side_plank', '体幹'),
      _e('ハイプランク', 'high_plank', '体幹'),
      _e('マウンテンクライマー', 'mountain_climber', '体幹'),
    ],
    '腕': [
      _e('リバースプッシュアップ', 'reverse_pushup', '腕'),
      _e('ナロープッシュアップ', 'narrow_pushup', '腕'),
    ],
    'お尻': [
      _e('プランクレッグレイズ', 'plank_leg_raise', 'お尻'),
      _e('バックキック', 'back_kick', 'お尻'),
      _e('ブルガリアンスクワット', 'bulgarian_split_squat', 'お尻'),
    ],
    '脚': [
      _e('スクワット', 'squat', '脚'),
      _e('サイドランジ', 'side_lunge', '脚'),
      _e('リバースランジ', 'reverse_lunge', '脚'),
      _e('フロントランジ', 'front_lunge', '脚'),
      _e('ワイドスクワット', 'wide_squat', '脚'),
    ],
    '全身': [
      _e('バービージャンプ', 'burpee_jump', '全身'),
    ],
  };

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final qNorm = widget.normalize(widget.query);
    final hasQuery = qNorm.isNotEmpty;

    // ───── 検索あり：全カテゴリ横断検索モード ─────
    if (hasQuery) {
      final List<_GuideEntry> filtered = [];
      _catalog.forEach((category, list) {
        filtered.addAll(
          list.where((e) {
            final haystacks = <String>{
              e.label,
              e.topic,
              e.category,
            }.map(widget.normalize).toList();
            return haystacks.any((h) => h.contains(qNorm));
          }),
        );
      });

      if (filtered.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            '検索に一致するトレーニングが見つかりませんでした。',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '検索結果 (${filtered.length}件)',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final aspect = isNarrow ? 2.5 : 10.0;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: aspect,
                  mainAxisExtent: 56,
                ),
                itemBuilder: (_, i) => _GuideTile(item: filtered[i]),
              );
            },
          ),
        ],
      );
    }

    // ───── 検索なし：従来どおり「タブ＋カテゴリごとのグリッド」 ─────
    final currentTab = _tabs[_index];
    final items = _catalog[currentTab] ?? const <_GuideEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GuideTabs(
          tabs: _tabs,
          index: _index,
          onChanged: (i) => setState(() => _index = i),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 360;
            final aspect = isNarrow ? 2.5 : 10.0;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: aspect,
                mainAxisExtent: 56,
              ),
              itemBuilder: (_, i) => _GuideTile(item: items[i]),
            );
          },
        ),
      ],
    );
  }

  _GuideEntry _e(String label, String topic, String category) =>
      _GuideEntry(label: label, topic: topic, category: category);
}

class _GuideTabs extends StatelessWidget {
  const _GuideTabs({
    required this.tabs,
    required this.index,
    required this.onChanged,
  });
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, i) {
          final selected = i == index;
          return ChoiceChip(
            label: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 56),
              child: Center(
                child: Text(
                  tabs[i],
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.black87,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            labelPadding: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
            selected: selected,
            onSelected: (_) => onChanged(i),
            selectedColor: HomeScreen.accentBlue,
            backgroundColor: const Color(0xFFF2F3F5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.black26),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: tabs.length,
      ),
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({
    required this.item,
    super.key,
  });

  final _GuideEntry item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.pushNamed(
          context,
          '/guide',
          arguments: {'topic': item.topic},
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E3E7)),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Icon(
                _iconForTab(item.category),
                size: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  fontSize: 13,
                  height: 1.0,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 14, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  IconData _iconForTab(String tab) {
    switch (tab) {
      case '肩':
        return Icons.accessibility_new;
      case '胸':
        return Icons.fitness_center;
      case '背中':
        return Icons.airline_seat_recline_extra;
      case '腹筋':
        return Icons.grid_view_rounded;
      case '体幹':
        return Icons.self_improvement;
      case '腕':
        return Icons.pan_tool_alt;
      case 'お尻':
        return Icons.directions_walk;
      case '脚':
        return Icons.directions_run;
      case '全身':
        return Icons.bolt;
      default:
        return Icons.circle;
    }
  }
}
