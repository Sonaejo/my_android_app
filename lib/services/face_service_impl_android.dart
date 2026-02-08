import 'dart:async';
import 'face_service.dart';

class _AndroidFaceService implements FaceService {
  final _ctrl = StreamController<FaceResult>.broadcast();
  bool _running = false;

  @override
  Stream<FaceResult> get stream => _ctrl.stream;

  @override
  Future<void> start() async {
    _running = true;
  }

  @override
  Future<void> stop() async {
    _running = false;
  }

  @override
  void dispose() {
    _ctrl.close();
  }
}

FaceService createPlatformFaceService() => _AndroidFaceService();
