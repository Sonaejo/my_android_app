import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 黒画面回避：初期化は落ちても・詰まっても起動は続行する
  try {
    await _safeBoot();
  } catch (_) {
    // 何があっても起動は継続
  }

  runApp(const MyApp());
}

/// 起動時の初期化（Webで危ないものはスキップ＆タイムアウト）
Future<void> _safeBoot() async {
  // 例：設定読み込みなど「Webでも安全」なものはここに置いてOK
  // await SharedPreferences.getInstance();

  if (kIsWeb) {
    // ✅ Webでは危ない初期化をやらない（ここが黒画面の最大原因になりがち）
    // - permission_handler
    // - flutter_local_notifications
    // - timezone
    // - camera / ML Kit / webview_flutter の初期起動
    return;
  }

  // ✅ モバイルのみ：通知や権限など
  // await initNotifications().timeout(const Duration(seconds: 3), onTimeout: () {});
  // await initTimezone().timeout(const Duration(seconds: 3), onTimeout: () {});
  // await requestPermissions().timeout(const Duration(seconds: 3), onTimeout: () {});
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ✅ 黒画面に見えないように明示
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
      ),

      home: const BootGate(),
    );
  }
}

/// 「必ず何か表示する」ゲート
class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initApp();
  }

  Future<void> _initApp() async {
    // ✅ ここで “あなたのアプリの本来の初期化” を入れていく
    // ただし Webでは危ないものは絶対に実行しない（kIsWebでガード）
    if (!kIsWeb) {
      // 例：モバイルだけ通知初期化 etc
    }

    // ✅ 何かが詰まって真っ黒になるのを防ぐ
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture.timeout(
        const Duration(seconds: 5),
        onTimeout: () {}, // タイムアウトしても先へ進む
      ),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        // ✅ 本来の最初の画面に置き換える（ホーム画面等）
        return const Scaffold(
          body: Center(
            child: Text('BOOT OK', style: TextStyle(fontSize: 24)),
          ),
        );
      },
    );
  }
}
