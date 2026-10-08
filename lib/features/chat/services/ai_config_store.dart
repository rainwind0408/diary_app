import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_config.dart';
import 'ai_config_migration.dart';

/// AI 配置的唯一读写入口。
///
/// 存储形态：SharedPreferences 单 key [keyConfig] 存一段 JSON（[AiConfig.toJsonString]）。
/// 旧版（v1）是多个平铺 key，首次加载时自动迁移；旧 key 保留不删以便回滚。
class AiConfigStore {
  AiConfigStore._();

  /// 新配置 key
  static const String keyConfig = 'ai_config_v2';

  static AiConfig? _cache;

  /// 内存缓存（同步读取用；未加载过则为 null）
  static AiConfig? get cached => _cache;

  /// 读取配置。首次调用会尝试从 v1 迁移；配置损坏时回退到初始配置。
  static Future<AiConfig> load({bool force = false}) async {
    if (!force && _cache != null) return _cache!;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyConfig);

    AiConfig config;
    if (raw != null && raw.isNotEmpty) {
      config = AiConfig.fromJsonString(raw)
          .withMissingPresets()
          .refreshBuiltinPresets()
          .refreshDefaultSystemPrompt();
    } else {
      config = AiConfigMigration.migrate({
        AiConfigMigration.kOldProvider:
            prefs.getString(AiConfigMigration.kOldProvider),
        AiConfigMigration.kOldApiKey:
            prefs.getString(AiConfigMigration.kOldApiKey),
        AiConfigMigration.kOldApiKeys:
            prefs.getString(AiConfigMigration.kOldApiKeys),
        AiConfigMigration.kOldModel:
            prefs.getString(AiConfigMigration.kOldModel),
        AiConfigMigration.kOldUrl: prefs.getString(AiConfigMigration.kOldUrl),
        AiConfigMigration.kOldSystemPrompt:
            prefs.getString(AiConfigMigration.kOldSystemPrompt),
        AiConfigMigration.kOldCachedProviders:
            prefs.getString(AiConfigMigration.kOldCachedProviders),
      });
    }

    _cache = config;
    await prefs.setString(keyConfig, config.toJsonString());
    return config;
  }

  /// 保存配置（同时更新内存缓存）
  static Future<void> save(AiConfig config) async {
    _cache = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyConfig, config.toJsonString());
  }

  /// 局部更新：读 → 变换 → 存
  static Future<AiConfig> update(
    AiConfig Function(AiConfig current) transform,
  ) async {
    final current = await load();
    final next = transform(current);
    await save(next);
    return next;
  }

  /// 清空内存缓存（需要强制重载时用）
  static void invalidate() => _cache = null;

  /// 是否已有落盘配置（用于判断是否需要引导配置）
  static Future<bool> hasStoredConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyConfig);
    return raw != null && raw.isNotEmpty;
  }

  /// 生成一个不与现有配置冲突的新厂商 id（供「新增自定义厂商」使用）
  static String newProviderId(AiConfig config, String prefix) {
    final base = AiConfigMigration.slug(prefix);
    var candidate = base;
    var i = 1;
    final existing = config.providers.map((p) => p.id).toSet();
    while (existing.contains(candidate)) {
      candidate = '$base-$i';
      i++;
    }
    return candidate;
  }
}
