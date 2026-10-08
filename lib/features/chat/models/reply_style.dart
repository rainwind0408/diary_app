/// 一次对话回合的「回复风格」—— **纯 Dart**，不依赖 Flutter，便于离线测试。
///
/// 目前只有一个非默认值：[voiceBrief]，用于悬浮球长按语音提问。
///
/// ## ⚠️ [voiceBrief] 有一个副作用
///
/// 语音回合里 `generate_image` 生成的图会被**顺带放到首页封面位**
/// （临时图，冷启动即消失）。见 `ChatProvider._maybePublishTempCover`。
///
/// 之所以挂在这个标志上而不是让模型理解一个新工具：用户按住球说
/// 「生成一张…」时，他要的就是「给我看张图」，落封面与交互一一对应，
/// 且零提示词依赖（模型判不准「这次是封面还是聊天配图」）。
///
/// ## 为什么用「追加系统提示词」而不是截断
///
/// 用户明确要求过「不要采用截断策略」。除了尊重需求，截断在这条链路上确实是错的：
///
/// - 中文 150 字大约是 2~3 个完整句子，**硬截会砍在句子中间**，
///   读出来是半句话，比长一点更糟；
/// - 截断发生在「模型已经生成完」之后，token 已经花了、延迟已经付了，纯属浪费；
/// - 一旦截断，落库的正文和模型以为它说过的话不一致，下一轮上下文会出现
///   「我没说过这句」的错位。
///
/// 所以约束走提示词（[systemSuffix]），token 上限（[contentTokenCap]）只作为
/// 「模型收不住尾」时的安全网，且给得比 150 字宽裕得多 —— 见下。
library;

enum ReplyStyle {
  /// 普通回合：用全局 `systemPrompt` + 全局 `maxTokens`
  normal,

  /// 悬浮球语音回合：追加简洁约束 + 压低正文 token 上限
  voiceBrief;

  /// 追加到系统提示词**末尾**的段落（空串 = 不追加）。
  ///
  /// 放系统提示词而不是用户消息，是为了**不污染落库的用户消息** ——
  /// 转写文本原样入库，历史记录干净。
  String get systemSuffix {
    switch (this) {
      case ReplyStyle.normal:
        return '';
      case ReplyStyle.voiceBrief:
        return '\n\n【本轮要求】用户是用语音提问的，回复会被朗读出来。'
            '请用不超过 150 个字回答，优先给结论和最有用的那一句，'
            '不要罗列、不要分点、不要用 Markdown 标记、不要客套开场白。'
            '如果确实需要展开，先给 150 字以内的回答，再问用户要不要细说。';
    }
  }

  /// 本轮请求的**正文** token 上限；null = 用全局配置。
  ///
  /// [voiceBrief] 取 512 而不是 256：
  /// - 中文 150 字在 qwen / gpt 系 tokenizer 下大约 150~260 token；
  /// - 留一倍余量，避免出现 `finish_reason: length` 把句子砍断 ——
  ///   那反而变成了截断，与需求相反。
  int? get contentTokenCap {
    switch (this) {
      case ReplyStyle.normal:
        return null;
      case ReplyStyle.voiceBrief:
        return 512;
    }
  }

  /// 是否需要给这次请求压低 `max_tokens`
  bool get capsContentTokens => contentTokenCap != null;
}
