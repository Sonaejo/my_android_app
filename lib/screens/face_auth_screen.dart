// lib/screens/face_auth_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;

import '../services/face_service.dart';

// --- 条件付きインポート（Web以外ではスタブを使う） ---
import '../web_stubs/html_stub.dart'
    if (dart.library.html) 'dart:html' as html;

import '../web_stubs/jsutil_stub.dart'
    if (dart.library.html) 'dart:js_util' as jsutil;

class FaceAuthScreen extends StatefulWidget {
  const FaceAuthScreen({super.key});
  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen> {
  static const _kFaceAuth = 'face_auth_enabled';

  bool _enabled = true; // 既定ON（必要ならfalseに）
  bool _running = false;
  bool _hasFace = false;
  String _status = '未開始';

  bool _verifyOn = false;

  bool _autoEnroll = true;
  int _maxFaces = 3;

  // 旧互換表示
  String? _stableName;
  int? _stablePct;
  double? _stableDist;
  String? _instantName;
  int? _instantPct;
  double? _instantDist;

  String? get _matchName => _stableName ?? _instantName;
  double? get _matchDist => _stableDist ?? _instantDist;
  int? get _matchPct => _stablePct ?? _instantPct;

  final _nameCtrl = TextEditingController();

  FaceService? _svc;
  StreamSubscription<FaceResult>? _sub;

  final List<({String type, void Function(html.Event) listener})> _webListeners = [];

  // 旧API: 名前一覧
  List<String> _enrolled = const [];

  // 新API: P#一覧 [{id,name,count,createdAt?, thumbs?}]
  List<Map<String, dynamic>> _persons = const [];

  // roster（画面に映ってる人）
  List<Map<String, dynamic>> _roster = const [];

  // P#ごとの最新一致率（0-100）
  final Map<String, int> _livePctByPerson = {};

  /* ---------- helpers ---------- */
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.transientCallbacks ||
        phase == SchedulerPhase.postFrameCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPref();

    if (kIsWeb) {
      // hasFace / verify互換
      void onFaceResult(html.Event evt) {
        final d = (evt as dynamic).detail;
        final hasFace = d?['hasFace'] == true;

        final stableName = d?['matchName'];
        final stablePct  = d?['stableConfidencePercent'];
        final stableDist = d?['distance'];

        final candName = d?['candidateName'];
        final candPct  = d?['confidencePercent'];
        final bestDist = d?['bestDist'];

        _safeSetState(() {
          _hasFace = hasFace;

          _stableName = (stableName is String && stableName.isNotEmpty) ? stableName : null;
          _stablePct  = (stablePct  is num) ? stablePct.toInt() : null;
          _stableDist = (stableDist is num) ? stableDist.toDouble() : null;

          _instantName = (candName is String && candName.isNotEmpty) ? candName : null;
          _instantPct  = (candPct  is num) ? candPct.toInt() : null;
          _instantDist = (bestDist is num) ? bestDist.toDouble() : null;

          if (!_hasFace) {
            _stableName = _stablePct = _stableDist = null;
            _instantName = _instantPct = _instantDist = null;
          }
        });
      }

      // roster
      void onRoster(html.Event evt) {
        final raw = (evt as dynamic).detail?['roster'];
        final list = <Map<String, dynamic>>[];

        try {
          final dartified = jsutil.dartify(raw);
          if (dartified is List) {
            for (final e in dartified) {
              if (e is Map) {
                list.add({
                  'trackId': e['trackId'],
                  'personId': e['personId'],
                  'name': e['name'],
                  'confidencePercent': e['confidencePercent'],
                  'bbox': e['bbox'],
                });
              } else {
                dynamic get(String k) { try { return jsutil.getProperty(e, k); } catch (_) { return null; } }
                list.add({
                  'trackId': get('trackId'),
                  'personId': get('personId'),
                  'name': get('name'),
                  'confidencePercent': get('confidencePercent'),
                  'bbox': get('bbox'),
                });
              }
            }
          }
        } catch (_) {/* noop */ }

        _livePctByPerson.clear();
        for (final r in list) {
          final pid = r['personId']?.toString();
          final pct = (r['confidencePercent'] is num) ? (r['confidencePercent'] as num).toInt() : null;
          if (pid != null && pct != null) {
            final cur = _livePctByPerson[pid];
            if (cur == null || pct > cur) _livePctByPerson[pid] = pct;
          }
        }

        _safeSetState(() => _roster = list);
      }

      // enroll(旧)完了
      void onEnroll(html.Event evt) async {
        final ok = (evt as dynamic).detail?['ok'] == true;
        final name = (evt as dynamic).detail?['name'];
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? '登録しました: $name' : '登録に失敗しました')),
        );
        await _refreshEnrollments();
        await _refreshPersons();
      }

      // 自動P#発行
      void onAutoEnroll(html.Event evt) async {
        final id = (evt as dynamic).detail?['id']?.toString();
        if (!mounted) return;
        if (id != null && id.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('自動登録: $id')));
        }
        await _refreshPersons();
      }

      // ★ サムネ（プレビュー）保存完了トースト
      void onPreviewSaved(html.Event evt) async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像が保存されました')),
        );
        await _refreshPersons(); // サムネ一覧も更新反映
      }

      void onFaceError(html.Event evt) {
        final msg = (evt as dynamic).detail?['message']?.toString() ?? 'エラーが発生しました';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }

      void onWindowError(html.Event evt) {
        final e = evt as dynamic;
        final msg = (e.message ?? e.error ?? e.filename ?? e.type ?? e.toString()).toString();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }

      void onUnhandled(html.Event evt) {
        final reason = (evt as dynamic).reason;
        final msg = (reason?.message ?? reason?.toString() ?? 'Unhandled promise rejection').toString();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }

      final pairs = <({String type, void Function(html.Event) listener})>[
        (type: 'face:onResult', listener: onFaceResult),
        (type: 'face:onRoster', listener: onRoster),
        (type: 'face:onEnroll', listener: onEnroll),
        (type: 'face:onAutoEnroll', listener: onAutoEnroll),
        (type: 'face:onPreviewSaved', listener: onPreviewSaved), // ★追加
        (type: 'face:onError', listener: onFaceError),
        (type: 'error', listener: onWindowError),
        (type: 'unhandledrejection', listener: onUnhandled),
      ];
      for (final p in pairs) {
        html.window.addEventListener(p.type, p.listener);
      }
      _webListeners.addAll(pairs);

      _refreshEnrollments();
      _refreshPersons();
      _applyJsRosterSettings();
    }
  }

  Future<void> _loadPref() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    _safeSetState(() => _enabled = p.getBool(_kFaceAuth) ?? _enabled);
  }

  Future<void> _savePref(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kFaceAuth, v);
  }

  /* ---------- JS bridge ---------- */
  dynamic _jsGet(String name) {
    try {
      return jsutil.getProperty(html.window, name);
    } catch (_) {
      return null;
    }
  }

  Future<T?> _jsCall<T>(String fnName, List args, {bool asPromise = true}) async {
    try {
      final res = jsutil.callMethod(html.window, fnName, args);
      if (asPromise && res != null) {
        try {
          return await jsutil.promiseToFuture(res) as T?;
        } catch (_) {
          if (res is Future) {
            final v = await res;
            return v as T?;
          }
        }
      }
      return res as T?;
    } catch (_) {
      return null;
    }
  }

  Future<void> _applyJsRosterSettings() async {
    if (!kIsWeb) return;
    // face_runtime.js 側が setMaxFacesConfig / setAutoEnrollEnabled を公開している前提
    _jsCall<void>('setMaxFacesConfig', [_maxFaces], asPromise: false);
    _jsCall<void>('setAutoEnrollEnabled', [_autoEnroll], asPromise: false);
  }

  Future<void> _initWebModuleOnce() async {
    if (!kIsWeb) return;
    await _jsCall<void>('initFaceModule', [
      {
        'fitMode': 'cover',
        'maxFaces': _maxFaces,
        'autoEnroll': _autoEnroll,
        'thresholds': {
          'distReject': 0.31,
          'safeMergeDist': 0.27,
          'createMinDist': 0.33,
          'marginMin': 0.05,
          'minSeenFramesForCreate': 3,
        },
      }
    ]);
  }

  /* ---------- ×カウント（サンプル数）取得 ---------- */
  Future<List<Map<String, dynamic>>> _fetchPersonCounts() async {
    if (!kIsWeb) return const [];
    // 拡張API（あれば詳しく出す）
    final f = _jsGet('listPersonsDetail'); // 追加済み
    if (f != null) {
      try {
        final res = jsutil.callMethod(html.window, 'listPersonsDetail', const []);
        final dartified = jsutil.dartify(res);
        if (dartified is List) {
          return dartified.map<Map<String, dynamic>>((e) {
            if (e is Map) {
              return {
                'id': e['id']?.toString(),
                'name': e['name']?.toString(),
                'count': (e['count'] is num) ? (e['count'] as num).toInt() : null,
                'createdAt': e['createdAt'],
                'thumbs': e['thumbs'],
              };
            } else {
              dynamic get(String k){ try { return jsutil.getProperty(e, k); } catch(_){ return null; } }
              return {
                'id': get('id')?.toString(),
                'name': get('name')?.toString(),
                'count': (get('count') is num) ? (get('count') as num).toInt() : null,
                'createdAt': get('createdAt'),
                'thumbs': get('thumbs'),
              };
            }
          }).toList();
        }
      } catch (_) {/* fallthrough */}
    }
    // フォールバック（listPersons のみ）
    final lp = _jsGet('listPersons');
    if (lp != null) {
      try {
        final res = jsutil.callMethod(html.window, 'listPersons', const []);
        final dartified = jsutil.dartify(res);
        if (dartified is List) {
          return dartified.map<Map<String, dynamic>>((e) {
            if (e is Map) {
              return {
                'id': e['id']?.toString(),
                'name': e['name']?.toString(),
                'count': (e['count'] is num) ? (e['count'] as num).toInt() : null,
                'createdAt': null,
                'thumbs': const [],
              };
            } else {
              dynamic get(String k){ try { return jsutil.getProperty(e, k); } catch(_){ return null; } }
              return {
                'id': get('id')?.toString(),
                'name': get('name')?.toString(),
                'count': (get('count') is num) ? (get('count') as num).toInt() : null,
                'createdAt': null,
                'thumbs': const [],
              };
            }
          }).toList();
        }
      } catch (_) {/* noop */}
    }
    return const [];
  }

  String _fmtCreatedAt(dynamic v) {
    if (v == null) return '-';
    if (v is num) {
      try {
        final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt()).toLocal();
        return dt.toString().split('.').first;
      } catch (_) { return '-'; }
    }
    if (v is String) {
      final n = int.tryParse(v);
      if (n != null) {
        try {
          final dt = DateTime.fromMillisecondsSinceEpoch(n).toLocal();
          return dt.toString().split('.').first;
        } catch (_) {}
      }
      return v;
    }
    return '-';
  }

  /* ---------- サムネ一覧取得&表示 ---------- */
  Future<List<String>> _getThumbs(String personId) async {
    if (!kIsWeb) return const [];
    final f = _jsGet('getPersonThumbs');
    if (f == null) return const [];
    try {
      final res = jsutil.callMethod(html.window, 'getPersonThumbs', [personId]);
      final dartified = jsutil.dartify(res);
      if (dartified is List) {
        return dartified.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> _openThumbsDialog(String personId, {String? title}) async {
    final thumbs = await _getThumbs(personId);
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final list = thumbs;
        return SizedBox(
          height: (MediaQuery.of(ctx).size.height * 0.55).clamp(280.0, 560.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  (title == null || title.isEmpty) ? 'サムネ一覧（$personId）' : '$title（$personId）',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('（保存済み画像はありません）'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final url = list[i];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(url, fit: BoxFit.cover),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 12, 12),
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('閉じる'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /* ---------- ×カウント表示: BottomSheet 版 ---------- */
  Future<void> _openCountsDialog() async {
    final items = await _fetchPersonCounts();
    if (!mounted) return;
    items.sort((a,b) => (b['count'] ?? 0).compareTo(a['count'] ?? 0));

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.6; // 画面の 60% 高さ
        return SizedBox(
          height: maxH.clamp(320.0, 520.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // グリップ
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('P# ×カウント一覧',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const SizedBox(height: 6),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('（登録がありません）'))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final id = items[i]['id'] ?? '-';
                          final name = (items[i]['name'] as String?)?.trim();
                          final label = (name != null && name.isNotEmpty) ? '$name ($id)' : id;
                          final count = items[i]['count'] ?? 0;
                          final createdStr = _fmtCreatedAt(items[i]['createdAt']);
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.person_outline),
                            title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('作成: $createdStr'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('×$count', style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => _openThumbsDialog(id, title: name ?? ''),
                                  child: const Text('サムネ'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 12, 12),
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('閉じる'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /* ================= UI: 見やすいカード化セクション ================= */
  Widget _buildAutoEnrollSection() {
    final w = MediaQuery.of(context).size.width;
    final isNarrow = w < 480; // 狭い時は縦積み
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイトル行（右にトグル）
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '未一致を自動登録（P#割り当て）',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '未登録の顔を検出したら、自動でP#を発行して保存します。',
                        style: TextStyle(color: Colors.black54, fontSize: 12.5, height: 1.2),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _autoEnroll,
                  onChanged: (b) async {
                    _safeSetState(() => _autoEnroll = b);
                    await _applyJsRosterSettings();
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 同時人数行（狭い時は縦、広い時は右寄せ）
            isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('同時人数', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _maxFaces,
                        items: const [1, 2, 3, 4, 5, 6, 7, 8]
                            .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n')))
                            .toList(),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (v) async {
                          if (v == null) return;
                          _safeSetState(() => _maxFaces = v);
                          await _applyJsRosterSettings();
                        },
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Spacer(),
                      const Text('同時人数:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<int>(
                          value: _maxFaces,
                          items: const [1, 2, 3, 4, 5, 6, 7, 8]
                              .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n')))
                              .toList(),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (v) async {
                            if (v == null) return;
                            _safeSetState(() => _maxFaces = v);
                            await _applyJsRosterSettings();
                          },
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  /* ---------- actions ---------- */
  Future<void> _start() async {
    if (!_enabled) {
      _safeSetState(() => _status = '設定がOFFです。まずスイッチをONにしてください。');
      return;
    }
    if (_running) return;

    _svc = createFaceService();
    _sub = _svc!.stream.listen((r) => _safeSetState(() => _hasFace = r.hasFace));
    await _svc!.start();

    if (kIsWeb) {
      await _initWebModuleOnce();
      await _applyJsRosterSettings();

      try {
        await _jsCall<void>('startFaceCamera', const []);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('startFaceCamera 失敗: $e')));
      }
    }

    if (!mounted) return;
    _safeSetState(() {
      _running = true;
      _status = kIsWeb ? '開始しました（Web）' : '開始しました';
    });

    _refreshEnrollments();
    _refreshPersons();
  }

  Future<void> _stop() async {
    if (!_running) return;

    if (_verifyOn) {
      await _toggleVerify(false, silent: true);
    }

    await _sub?.cancel();
    _sub = null;
    try { await _svc?.stop(); } catch (_) {}
    _svc?.dispose(); _svc = null;

    if (kIsWeb) {
      try { await _jsCall<void>('stopFaceCamera', const []); } catch (_) {}
    }

    if (!mounted) return;
    _safeSetState(() {
      _running = false;
      _hasFace = false;

      _stableName = null; _stablePct = null; _stableDist = null;
      _instantName = null; _instantPct = null; _instantDist = null;

      _roster = const [];
      _livePctByPerson.clear();
      _status = '停止しました';
    });
  }

  Future<void> _enroll() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この登録UIはWeb専用です（モバイルは今後対応予定）')),
      );
      return;
    }
    if (!_running) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先に「開始」してください')));
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('名前を入力してください')));
      return;
    }
    try {
      await _jsCall<void>('enrollFace', [name]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登録失敗: $e')));
    }
    await _refreshEnrollments();
    await _refreshPersons();
  }

  Future<List<String>> _listEnrollments() async {
    if (!kIsWeb) return [];
    final f = _jsGet('listEnrollments');
    if (f == null) return [];
    try {
      final res = jsutil.callMethod(html.window, 'listEnrollments', const []);
      final dartified = jsutil.dartify(res);
      if (dartified is List) {
        return dartified.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return <String>[];
  }

  Future<void> _refreshEnrollments() async {
    if (!kIsWeb) return;
    final list = await _listEnrollments();
    if (!mounted) return;
    _safeSetState(() => _enrolled = list);
  }

  Future<void> _refreshPersons() async {
    if (!kIsWeb) return;
    // 可能なら詳細APIで（createdAt, thumbs含む）
    List<Map<String, dynamic>> list = const [];
    try {
      final hasDetail = _jsGet('listPersonsDetail') != null;
      if (hasDetail) {
        final res = jsutil.callMethod(html.window, 'listPersonsDetail', const []);
        final dartified = jsutil.dartify(res);
        if (dartified is List) {
          list = dartified.map<Map<String, dynamic>>((e) {
            if (e is Map) {
              return {
                'id':    e['id']?.toString(),
                'name':  e['name']?.toString(),
                'count': (e['count'] is num) ? (e['count'] as num).toInt() : null,
                'createdAt': e['createdAt'],
                'thumbs': (e['thumbs'] is List) ? e['thumbs'] : const [],
              };
            } else {
              dynamic get(String k) { try { return jsutil.getProperty(e, k); } catch (_) { return null; } }
              final thumbs = get('thumbs');
              return {
                'id':    get('id')?.toString(),
                'name':  get('name')?.toString(),
                'count': (get('count') is num) ? (get('count') as num).toInt() : null,
                'createdAt': get('createdAt'),
                'thumbs': (thumbs is List) ? thumbs : const [],
              };
            }
          }).toList();
        }
      } else {
        final res = jsutil.callMethod(html.window, 'listPersons', const []);
        final dartified = jsutil.dartify(res);
        if (dartified is List) {
          list = dartified.map<Map<String, dynamic>>((e) {
            if (e is Map) {
              return {
                'id':    e['id']?.toString(),
                'name':  e['name']?.toString(),
                'count': (e['count'] is num) ? (e['count'] as num).toInt() : null,
                'createdAt': null,
                'thumbs': const [],
              };
            } else {
              dynamic get(String k) { try { return jsutil.getProperty(e, k); } catch (_) { return null; } }
              return {
                'id':    get('id')?.toString(),
                'name':  get('name')?.toString(),
                'count': (get('count') is num) ? (get('count') as num).toInt() : null,
                'createdAt': null,
                'thumbs': const [],
              };
            }
          }).toList();
        }
      }
    } catch (_) {}

    if (!mounted) return;
    _safeSetState(() => _persons = list);
  }

  Future<void> _deleteEnrollment(String name) async {
    if (!kIsWeb) return;
    final f = _jsGet('clearDBName');
    if (f != null) {
      try {
        jsutil.callMethod(html.window, 'clearDBName', [name]);
      } catch (_) {}
      await _refreshEnrollments();
      await _refreshPersons();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除しました: $name')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('clearDBName が見つかりません')));
    }
  }

  Future<void> _toggleVerify(bool on, {bool silent = false}) async {
    if (!kIsWeb) {
      if (on && !_running) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先に「開始」してください')));
        }
        _safeSetState(() => _verifyOn = false);
        return;
      }
      _safeSetState(() => _verifyOn = on);
      return;
    }

    if (on) {
      if (!_running) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先に「開始」してください')));
        }
        _safeSetState(() => _verifyOn = false);
        return;
      }
      final enrolled = await _listEnrollments();
      final hasPersons = _persons.isNotEmpty;
      if (enrolled.isEmpty && !hasPersons) {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('まず「登録」してください（自動P#でも可）')));
        }
        _safeSetState(() => _verifyOn = false);
        return;
      }
      final startV = _jsGet('startVerify');
      if (startV != null) {
        try { jsutil.callMethod(html.window, 'startVerify', const []); } catch (_) {}
      } else if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('startVerify が見つかりません')));
      }
      _safeSetState(() => _verifyOn = true);
    } else {
      final stopV = _jsGet('stopVerify');
      if (stopV != null) { try { jsutil.callMethod(html.window, 'stopVerify', const []); } catch (_) {} }
      _safeSetState(() {
        _verifyOn = false;
        _stableName = null; _stablePct = null; _stableDist = null;
        _instantName = null; _instantPct = null; _instantDist = null;
      });
    }
  }

  Future<void> _renamePersonDialog({required String personId, String? currentName}) async {
    final ctrl = TextEditingController(text: currentName ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('名前を変更（$personId）'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '例：山田さん'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      final name = ctrl.text.trim();
      if (kIsWeb) {
        await _jsCall<void>('renamePerson', [personId, name], asPromise: false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(name.isEmpty ? '未命名にしました: $personId' : '更新しました: $personId → $name')),
      );
      await _refreshPersons();
      await _refreshEnrollments();
    }
  }

  Future<void> _deletePerson(String personId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除しますか？'),
        content: Text('この人物クラスタ（$personId）を削除します。元に戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok == true) {
      if (kIsWeb) {
        await _jsCall<void>('clearPerson', [personId], asPromise: false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('削除しました: $personId')));
      await _refreshPersons();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sub?.cancel();
    _svc?.dispose();

    if (kIsWeb) {
      for (final p in _webListeners) {
        html.window.removeEventListener(p.type, p.listener);
      }
      _webListeners.clear();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = !_running ? Colors.grey : _hasFace ? Colors.green : Colors.orange;
    final displayDist = _matchDist;

    final pad = MediaQuery.of(context).size.width < 420 ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('顔認証（オプション）')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(pad),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(!_running ? '停止中' : (_hasFace ? 'Face: OK' : 'Face: -'),
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_status, maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Row(
                  children: [
                    const Text('機能', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: _enabled,
                      onChanged: (b) async {
                        _safeSetState(() => _enabled = b);
                        await _savePref(b);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _running ? null : _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('開始'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _running ? _stop : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('停止'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),

            if (kIsWeb) ...[
              _buildAutoEnrollSection(),
              const SizedBox(height: 8),
              const Divider(),
            ],

            // 手動登録（旧）
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: '登録名（例: 自分）'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _running ? _enroll : null, child: const Text('登録')),
              ],
            ),
            const SizedBox(height: 12),

            if (kIsWeb) ...[
              // 旧: 名前ベース
              Row(
                children: [
                  const Text('登録一覧（名前ベース）', style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(onPressed: _refreshEnrollments, icon: const Icon(Icons.refresh)),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _enrolled.isEmpty
                      ? [const Text('（なし）', style: TextStyle(color: Colors.black54))]
                      : _enrolled.map((n) => Chip(label: Text(n), onDeleted: () => _deleteEnrollment(n))).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // 新: P# ベース（×カウント/サムネ表示ボタン付き）
              Row(
                children: [
                  const Text('登録一覧（P#ベース）', style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(onPressed: _refreshPersons, icon: const Icon(Icons.refresh)),
                  IconButton(
                    tooltip: '×カウントを見る',
                    onPressed: _openCountsDialog,
                    icon: const Icon(Icons.list_alt),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _persons.isEmpty
                    ? const Text('（なし）', style: TextStyle(color: Colors.black54))
                    : Wrap(
                        spacing: 10, runSpacing: 10,
                        children: _persons.map((p) {
                          final id = p['id'] as String?;
                          final name = (p['name'] as String?)?.trim();
                          final label = (name?.isNotEmpty ?? false) ? '$name ($id)' : id ?? '-';
                          final count = p['count'] as int?;
                          final livePct = (id != null) ? _livePctByPerson[id] : null;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (count != null) ...[
                                  const SizedBox(width: 8),
                                  Text('×$count', style: const TextStyle(color: Colors.black54)),
                                ],
                                if (livePct != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: Colors.blue.withOpacity(0.25)),
                                    ),
                                    child: Text('一致 ${livePct}%', style: const TextStyle(color: Colors.blue)),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                                  label: const Text('サムネ'),
                                  onPressed: (id == null) ? null : () => _openThumbsDialog(id, title: name ?? ''),
                                ),
                                IconButton(
                                  tooltip: '名前を変更',
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: id == null ? null : () => _renamePersonDialog(personId: id, currentName: name),
                                ),
                                IconButton(
                                  tooltip: 'クラスタ削除',
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  onPressed: id == null ? null : () => _deletePerson(id),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              const Divider(),
            ],

            // roster
            if (kIsWeb) ...[
              const Text('現在のロスター（映っている人物）', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: _roster.isEmpty
                    ? const Text('（いま画面に人物はいません）', style: TextStyle(color: Colors.black54))
                    : Wrap(
                        spacing: 12, runSpacing: 12,
                        children: _roster.map((e) {
                          final personId = (e['personId']?.toString().isNotEmpty ?? false) ? e['personId'].toString() : null;
                          final name = (e['name']?.toString().isNotEmpty ?? false) ? e['name'].toString() : null;
                          final label = name ?? (personId ?? '未割当');
                          final pct = (e['confidencePercent'] is num) ? (e['confidencePercent'] as num).toInt() : null;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  child: Text(
                                    personId != null ? personId.replaceAll(RegExp(r'[^0-9]'), '') : '-',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (pct != null) ...[
                                  const SizedBox(width: 8),
                                  Text('($pct%)', style: const TextStyle(color: Colors.black54)),
                                ],
                                if (personId != null) ...[
                                  IconButton(
                                    tooltip: '名前を変更',
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _renamePersonDialog(personId: personId, currentName: name),
                                  ),
                                  IconButton(
                                    tooltip: 'クラスタ削除',
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: () => _deletePerson(personId),
                                  ),
                                  const SizedBox(width: 6),
                                  OutlinedButton(
                                    onPressed: () => _openThumbsDialog(personId, title: name ?? ''),
                                    child: const Text('サムネ'),
                                  ),
                                ]
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              const Divider(),
            ],

            // verify互換表示
            Row(
              children: [
                const Text('照合テスト（互換）', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Switch.adaptive(value: _verifyOn, onChanged: (on) => _toggleVerify(on)),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_stableName != null || _stablePct != null || _stableDist != null)
                  Text(
                    '確定: ${_stableName ?? '-'}'
                    '${_stablePct != null ? '  ${_stablePct}%': ''}'
                    '${_stableDist != null && displayDist != null ? '  / 距離: ${displayDist.toStringAsFixed(3)}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                if (_instantName != null || _instantPct != null || _instantDist != null)
                  Text(
                    '瞬間: ${_instantName ?? '-'}'
                    '${_instantPct != null ? '  ${_instantPct}%': ''}'
                    '${_instantDist != null ? '  / 距離: ${_instantDist!.toStringAsFixed(3)}' : ''}',
                    style: const TextStyle(color: Colors.black87),
                  ),
                if (_stableName == null && _instantName == null && _hasFace && _verifyOn)
                  const Text('判定中…（安定化を待機）', style: TextStyle(color: Colors.black54)),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const Text('注意事項', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              '・ON時のみ推論。特徴量はブラウザのローカルストレージに保存し、外部送信しません。\n'
              '・簡易識別です。厳密な本人認証用途は専用モデルをご検討ください。',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
