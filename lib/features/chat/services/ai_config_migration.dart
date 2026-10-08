/// v1 → v2 配置迁移（纯 Dart，不依赖 Flutter，便于独立测试）
library;

import 'dart:convert';

import '../models/ai_config.dart';
import '../models/ai_provider.dart';

class AiConfigMigration {
  AiConfigMigration._();

  // ── v1 旧 key ──
  static const String kOldProvider = 'chat_api_provider';
  static const String kOldApiKey = 'chat_api_key';
  static const String kOldApiKeys = 'chat_api_keys';
  static const String kOldModel = 'chat_api_model';
  static const String kOldUrl = 'chat_api_url';
  static const String kOldSystemPrompt = 'chat_system_prompt';
  static const String kOldCachedProviders = 'chat_cached_providers';

  /// 把旧的平铺配置迁移成新的 [AiConfig]。
  ///
  /// 迁移规则：
  /// - 旧厂商名（DeepSeek / 通义千问 / 智谱 GLM / 月之暗面 / 豆包）与内置预设同名，按名称匹配
  /// - 旧 `chat_api_keys`（Map<厂商名, key>）逐项写回对应厂商
  /// - 旧 `chat_api_key`（单 key）兼容写回当前厂商
  /// - 旧 `chat_cached_providers`（更新过的模型列表）覆盖对应厂商的 models
  /// - 旧 `chat_api_model` / `chat_api_url` 写入选中的那个厂商
  /// - 旧 `chat_system_prompt` 写入全局
  /// - 厂商名匹配不上（用户曾自定义）时，按旧 URL 新建一个自定义厂商
  ///
  /// 任何一步解析失败都只跳过该步，不影响整体可用性。
  static AiConfig migrate(Map<String, Object?> values) {
    var config = AiConfig.initial();

    final oldProviderName = _str(values[kOldProvider]);
    final oldModel = _str(values[kOldModel]);
    final oldUrl = _str(values[kOldUrl]);
    final oldSystemPrompt = _str(values[kOldSystemPrompt]);

    // 1) 收集旧 API Key
    final keys = <String, String>{};
    final decodedKeys = _decode(values[kOldApiKeys]);
    if (decodedKeys is Map) {
      decodedKeys.forEach((k, v) {
        keys[k.toString()] = v.toString();
      });
    }
    final singleKey = _str(values[kOldApiKey]);
    if (singleKey != null && oldProviderName != null) {
      keys.putIfAbsent(oldProviderName, () => singleKey);
    }

    // 2) 收集旧缓存模型列表
    final cachedModels = <String, List<String>>{};
    final decodedCached = _decode(values[kOldCachedProviders]);
    if (decodedCached is List) {
      for (final item in decodedCached) {
        if (item is Map) {
          final name = _str(item['name']);
          final models = item['models'];
          if (name != null && models is List) {
            cachedModels[name] = models.whereType<String>().toList();
          }
        }
      }
    }

    // 3) 写回每个内置对话厂商
    for (final p in config.providersOf(AiCapability.chat)) {
      var updated = p;
      final key = keys[p.name];
      if (key != null && key.isNotEmpty) {
        updated = updated.copyWith(apiKey: key);
      }
      final models = cachedModels[p.name];
      if (models != null && models.isNotEmpty) {
        updated = updated.copyWith(models: models);
      }
      config = config.upsertProvider(updated);
    }

    // 4) 选中厂商 + 模型 + URL
    if (oldProviderName != null) {
      final matched = config
          .providersOf(AiCapability.chat)
          .where((p) => p.name == oldProviderName)
          .toList();

      if (matched.isNotEmpty) {
        var selected = matched.first;
        if (oldModel != null) {
          selected = selected.copyWith(selectedModel: oldModel);
        }
        if (oldUrl != null) {
          selected = selected.copyWith(baseUrl: oldUrl);
        }
        config = config.upsertProvider(selected);
        config = config.copyWith(chatProviderId: selected.id);
      } else if (oldUrl != null) {
        // 预设里没有这个名字 → 视为用户自定义过的厂商，原样保留
        final customId = 'migrated-${slug(oldProviderName)}';
        config = config.upsertProvider(
          AiProvider(
            id: customId,
            name: oldProviderName,
            capability: AiCapability.chat,
            protocol: AiProtocol.custom,
            baseUrl: oldUrl,
            apiKey: keys[oldProviderName] ?? '',
            models: oldModel != null ? [oldModel] : const [],
            selectedModel: oldModel,
          ),
        );
        config = config.copyWith(chatProviderId: customId);
      }
    }

    // 5) System Prompt
    if (oldSystemPrompt != null) {
      config = config.copyWith(systemPrompt: oldSystemPrompt);
    }

    return config;
  }

  /// 生成安全的自定义 id（避免中文/空格进 id）。
  ///
  /// 若名称不含 ASCII 字母数字（例如纯中文），退化为**稳定的**哈希后缀，
  /// 保证同一名称每次得到同一个 id（否则迁移两次会产生重复厂商）。
  static String slug(String input) {
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      if (_isAsciiAlnum(ch)) {
        buf.write(ch.toLowerCase());
      } else if (ch == ' ' || ch == '-' || ch == '_') {
        buf.write('-');
      }
    }
    final s = buf.toString().replaceAll(RegExp(r'-+'), '-');
    final trimmed = s.replaceAll(RegExp(r'^-|-$'), '');
    if (trimmed.isNotEmpty) return trimmed;
    return 'p${_stableHash(input)}';
  }

  /// FNV-1a 32 位哈希（确定性，跨进程/跨版本一致）
  static String _stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static bool _isAsciiAlnum(String ch) {
    if (ch.length != 1) return false;
    final code = ch.codeUnitAt(0);
    return (code >= 0x30 && code <= 0x39) || // 0-9
        (code >= 0x41 && code <= 0x5A) || // A-Z
        (code >= 0x61 && code <= 0x7A); // a-z
  }

  /// 非空字符串（空串视作 null）
  static String? _str(Object? v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static dynamic _decode(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
