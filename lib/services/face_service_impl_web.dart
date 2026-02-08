import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as jsutil;
import 'face_service.dart';

class _WebFaceService implements FaceService {
  final _ctrl = StreamController<FaceResult>.broadcast();
  bool _running = false;
  html.EventListener? _listener;

  @override
  Stream<FaceResult> get stream => _ctrl.stream;

  @override
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _listener = (evt) {
      try {
        final detail = (evt as dynamic).detail;
        final hasFace = detail?['hasFace'] == true;
        _ctrl.add(FaceResult(hasFace: hasFace));
      } catch (_) {}
    };
    html.window.addEventListener('face:onResult', _listener!);

    final init = jsutil.getProperty(html.window, 'initFaceModule');
    if (init != null) {
      jsutil.callMethod(init, 'call', [html.window]);
    }
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    if (_listener != null) {
      html.window.removeEventListener('face:onResult', _listener!);
      _listener = null;
    }
  }

  @override
  void dispose() {
    stop();
    _ctrl.close();
  }
}

FaceService createPlatformFaceService() => _WebFaceService();
