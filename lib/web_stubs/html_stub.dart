// lib/web_stubs/html_stub.dart
// Web以外で dart:html を参照しないための最小スタブ

// ignore_for_file: unused_element, unused_field

class Event {
  const Event();
}

class CustomEvent extends Event {
  final dynamic detail;
  const CustomEvent([this.detail]);
}

typedef EventListener = void Function(Event);

class _DummyLocation {
  void reload() {
    // no-op（Web以外では何もしない）
  }
}

class _DummyWindow {
  final _DummyLocation location = _DummyLocation();

  void addEventListener(String t, EventListener l) {}
  void removeEventListener(String t, EventListener l) {}
}

final _DummyWindow window = _DummyWindow();
