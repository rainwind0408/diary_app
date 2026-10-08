import 'package:shared_preferences/shared_preferences.dart';

import 'orb_geometry.dart';

/// 悬浮球位置的持久化。
///
/// 存 `SharedPreferences` 而不是 AI 配置 —— 它是**界面偏好**，
/// 不该混进 `ai_config_v2`（那份配置有版本迁移逻辑，塞界面状态进去
/// 只会让迁移越来越难维护）。
///
/// 读写全部吞异常：位置丢了最多回到默认落点，不该让启动流程崩掉。
class OrbPositionStore {
  OrbPositionStore._();

  static const String key = 'assistant_orb_offset';

  static Future<OrbPoint?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return OrbGeometry.parse(prefs.getString(key));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(OrbPoint point) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, OrbGeometry.serialize(point));
    } catch (_) {
      // 存不下就下次回到默认位置，不影响本次使用
    }
  }
}
