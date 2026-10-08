/// 「推理模型」识别 + token 预算换算。
///
/// 背景：`max_tokens` 在多数 OpenAI 兼容网关里是**思考 + 正文的总上限**。
/// 推理模型（DeepSeek-R1 / Qwen3 / GLM-Z1 …）常把默认的 2048 全花在思考上，
/// 正文直接空白或被截断。所以要在**发请求之前**就给这类模型额外留出思考预算。
///
/// 纯 Dart、零依赖，便于在纯 Dart VM 里单测。
library;

/// 命中这些片段的模型名，按「会先输出思考过程」处理。
///
/// 宁可多给也别漏：`max_tokens` 是**上限不是目标**，模型答完自己就停了，
/// 多给不会让它变啰嗦；但漏了就是正文空白，用户完全没法用。
const List<String> reasoningModelMarkers = [
  'deepseek-reasoner',
  'deepseek-r1',
  'qwq',
  'qwen3',
  'glm-z1',
  'glm-4.5',
  'magistral',
  'reasoning',
  'thinking',
  '-think',
  'r1-',
  '-r1',
];

/// OpenAI 推理系列。单独拎出来是因为「o1」这种两字符片段太容易误伤
/// （比如 `gpt-4o1`），必须**按分隔符切词后整词匹配**。
const List<String> reasoningModelTokens = ['o1', 'o3', 'o4'];

/// 模型名是否像「会先思考」的推理模型。
///
/// 只按名字猜，必然有漏网之鱼（自建/代理模型常常叫 `my-model-v2`）。
/// 漏了的靠 [AiConfig.reasoningModels] 学习补齐 —— 见过一次思考过程就记下来。
bool looksLikeReasoningModel(String model) {
  final m = model.toLowerCase().trim();
  if (m.isEmpty) return false;

  for (final marker in reasoningModelMarkers) {
    if (m.contains(marker)) return true;
  }

  final tokens = m.split(RegExp(r'[-_./:\s]+'));
  for (final token in tokens) {
    if (reasoningModelTokens.contains(token)) return true;
  }
  return false;
}

/// 换算真正要发出去的 `max_tokens`。
///
/// [isReasoning] 为真时，在 [maxTokens]（**正文**上限）之上再加
/// [reasoningBudget]，让思考过程不占用正文的额度。
///
/// [reasoningBudget] <= 0 表示关闭该特性（思考与正文共用 [maxTokens]）。
int effectiveMaxTokens({
  required int maxTokens,
  required int reasoningBudget,
  required bool isReasoning,
}) {
  final base = maxTokens < 1 ? 1 : maxTokens;
  if (!isReasoning || reasoningBudget <= 0) return base;
  return base + reasoningBudget;
}

/// 流式结束时，判断这次回答是不是「被 token 上限截断了」。
///
/// [finishReason] 为 `length` 说明模型是因为撞到上限停的；此时若正文为空、
/// 思考过程却很长，基本可以断定是**思考把额度吃光了** —— 这正是本文件
/// 要解决的问题，值得给用户一句明确的提示而不是让他对着空气发呆。
bool looksTruncatedByReasoning({
  required String finishReason,
  required String content,
  required String reasoning,
}) {
  if (finishReason != 'length') return false;
  if (reasoning.trim().isEmpty) return false;
  return content.trim().isEmpty;
}
