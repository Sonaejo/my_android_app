import 'face_service.dart';

class _NoopFaceService implements FaceService {
  @override
  Stream<FaceResult> get stream => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

FaceService createPlatformFaceService() => _NoopFaceService();
