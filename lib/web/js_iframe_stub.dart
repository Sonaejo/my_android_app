// 非Web環境では使われないスタブ
class JsBridge {
  JsBridge(String src);
  String get viewType => '';
  void post(String json) {}
  void onMessage(void Function(String) handler) {}
}
