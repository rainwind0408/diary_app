/// 写操作的「人工确认」模型 —— **纯 Dart**，便于离线单测。
///
/// 模型能改用户的日记，就必须让用户在**改动发生之前**看到「要改什么」。
/// 本文件只描述「给用户看什么」，真正挂起等待 UI 的机制在
/// `services/tool_confirmation_gate.dart`。
library;

import 'dart:async';

/// 工具的风险等级。
///
/// 分级不是为了好看，而是为了**决定确认方式**：
/// `write` 点一下就行，`destructive` 必须长按 1 秒。
enum ToolRisk {
  /// 只读，不过确认门
  read,

  /// 写入 / 修改，可恢复
  write,

  /// 不可恢复（删除）
  destructive;

  /// 确认按钮的文案
  String get confirmLabel => this == ToolRisk.destructive ? '长按删除' : '确认';

  /// 是否需要「长按」才能确认
  bool get needsHold => this == ToolRisk.destructive;
}

/// 确认卡片上的一行摘要。
///
/// 刻意做成结构化的「标签 + 值」，而不是把工具入参的 JSON 直接丢出来 ——
/// 用户看不懂 `{"diary_id": 7, "content": "..."}`。
class ConfirmationLine {
  /// 左侧标签，例如「标题」「正文」
  final String label;

  /// 右侧内容
  final String value;

  /// 是否加重显示（一般给「会被写进去的正文」）
  final bool emphasize;

  const ConfirmationLine({
    required this.label,
    required this.value,
    this.emphasize = false,
  });
}

/// 一次待确认的操作。
class ToolConfirmationRequest {
  /// 触发这次确认的工具名（`create_diary` 等）
  final String toolName;

  /// 风险等级
  final ToolRisk risk;

  /// 卡片标题，例如「新建一篇日记」「删除《周末的雨》」
  final String title;

  /// 结构化摘要
  final List<ConfirmationLine> lines;

  /// 危险操作的额外警示语（红色显示）
  final String? warning;

  /// 由 `ToolConfirmationGate` 等待 / 完成的信号
  final Completer<bool> completer;

  ToolConfirmationRequest({
    required this.toolName,
    required this.risk,
    required this.title,
    this.lines = const [],
    this.warning,
    Completer<bool>? completer,
  }) : completer = completer ?? Completer<bool>();

  /// 确认按钮文案
  String get confirmLabel => risk.confirmLabel;

  /// 要不要长按确认
  bool get needsHold => risk.needsHold;
}

/// 把一段文本压成卡片上的一行摘要。
///
/// 三条纪律（见方案 7.3）：
/// 1. 折叠换行 —— 卡片本身不能比日记还长；
/// 2. 超过 [max] 个字符就截断加省略号；
/// 3. **不劈开代理对** —— 否则 emoji 会变成半个乱码方块。
String excerpt(String text, {int max = 60}) {
  final oneLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (oneLine.length <= max) return oneLine;

  var end = max;
  if (end > 0 && _isHighSurrogate(oneLine.codeUnitAt(end - 1))) {
    end -= 1;
  }
  return '${oneLine.substring(0, end)}…';
}

/// 「旧 → 新」的对比行，供修改类操作展示「会覆盖掉什么」
String diffLine(String before, String after) =>
    '${excerpt(before, max: 40)} → ${excerpt(after, max: 40)}';

bool _isHighSurrogate(int codeUnit) =>
    codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
