// Web専用: iframe を生成して ViewFactory 登録し、postMessage/受信を扱う
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui' as ui;

class JsBridge {
  final html.IFrameElement iframe;
  final String viewType;

  JsBridge(String src)
      : iframe = html.IFrameElement()
          ..src = src
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%',
        viewType = 'report-iframe-${DateTime.now().millisecondsSinceEpoch}' {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(viewType, (int _) => iframe);
  }

  void post(String json) {
    iframe.contentWindow?.postMessage(json, '*');
  }

  void onMessage(void Function(String) handler) {
    html.window.onMessage.listen((event) {
      final data = event.data;
      if (data is String) handler(data);
    });
  }
}
