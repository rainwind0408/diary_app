import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/tool_confirmation.dart';

/// 写操作的「人工确认门」。
///
/// ## 要解决的问题
///
/// 工具执行是 `await` 在 LLM 循环里的同步等待（`_executeTool` 返回
/// `Future<String>`）。要在中间插一句「等用户点确认」，就得让这个 Future
/// **挂起**，再由一次 UI 事件把它 resolve 掉 —— 本类就是这个挂起/唤醒机制。
///
/// ## 为什么是静态单例而不是 provider
///
/// 理由和 `TtsPlayer` 一样：确认门可能在**任何页面**被触发（AI 可以在聊天页、
/// 日记列表页、甚至悬浮球语音直通里调写工具）。放进某个页面的 State 里，
/// 一 push 新页面就会漏掉。
class ToolConfirmationGate {
  ToolConfirmationGate._();

  /// 当前待确认的请求；null = 没有。
  ///
  /// 界面层 `ValueListenableBuilder` 监听它来决定卡片显不显示。
  static final ValueNotifier<ToolConfirmationRequest?> pending =
      ValueNotifier<ToolConfirmationRequest?>(null);

  /// 用户多久不操作视为取消。
  ///
  /// 超时**默认取消**而不是默认同意 —— 这是安全默认。
  /// 60 秒也够用户看清卡片上写的是什么。
  static const Duration timeout = Duration(seconds: 60);

  /// 挂起等待用户决定。
  ///
  /// 返回 true = 用户点了确认；false = 用户取消 / 超时 / 被 [resolve] 放掉。
  static Future<bool> request(ToolConfirmationRequest req) async {
    // 上一个还没走完就又来一个：把旧的当「取消」放掉。
    // 不这么做的话旧的会一直挂到 60 秒超时，界面上会出现两张叠在一起的卡片。
    resolve(false);

    pending.value = req;
    try {
      return await req.completer.future.timeout(
        timeout,
        onTimeout: () => false,
      );
    } finally {
      // 只清自己那一个 —— 万一期间已经被换成新的请求了，别把新的抹掉
      if (identical(pending.value, req)) pending.value = null;
    }
  }

  /// 用户点了确认 / 取消。
  ///
  /// 重复调用是安全的（`Completer` 只认第一次）。
  static void resolve(bool approved) {
    final req = pending.value;
    if (req == null || req.completer.isCompleted) return;
    req.completer.complete(approved);
  }

  /// 有没有正在等待确认的操作
  static bool get isWaiting => pending.value != null;
}
