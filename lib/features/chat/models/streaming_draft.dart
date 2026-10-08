/// 流式回答的「草稿」——还没落库的增量内容。
///
/// 为什么单独抽出来、并用 `ValueNotifier` 承载：
/// `ChatProvider.notifyListeners()` 会让**整屏**（含消息列表）重建，
/// 逐 token 地调它必然掉帧。所以粗粒度状态（开始 / 结束 / 报错）走
/// notifyListeners，逐 token 的刷新走这里 —— 只有草稿气泡订阅它。
///
/// 纯 Dart、零依赖，便于单测。
library;

class StreamingDraft {
  final String content;
  final String reasoning;

  const StreamingDraft({this.content = '', this.reasoning = ''});

  static const StreamingDraft empty = StreamingDraft();

  bool get isEmpty => content.isEmpty && reasoning.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// 追加增量。
  ///
  /// 两个增量都为空时**返回自身**（`identical` 可用于判断「这次没变化」，
  /// 调用方据此跳过无谓的刷新）。
  StreamingDraft append({String content = '', String reasoning = ''}) {
    if (content.isEmpty && reasoning.isEmpty) return this;
    return StreamingDraft(
      content: this.content + content,
      reasoning: this.reasoning + reasoning,
    );
  }

  @override
  String toString() =>
      'StreamingDraft(content: ${content.length}字, '
      'reasoning: ${reasoning.length}字)';
}
