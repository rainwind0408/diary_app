import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/providers/app_chrome_provider.dart';
import 'features/diary_list/providers/date_filter_provider.dart';
import 'features/diary_list/providers/diary_list_provider.dart';
import 'features/diary_write/providers/diary_write_provider.dart';
import 'features/achievements/providers/achievement_provider.dart';
import 'features/settings/providers/font_size_provider.dart';
import 'features/settings/providers/theme_provider.dart';
import 'features/weather/providers/seasonal_provider.dart';
import 'features/templates/providers/template_provider.dart';
import 'features/reminders/providers/reminder_provider.dart';
import 'features/reminders/services/notification_service.dart';
import 'shared/services/sharing_intent_service.dart';
import 'features/statistics/providers/statistics_provider.dart';
import 'features/stickers/providers/sticker_provider.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/chat/providers/chat_session_provider.dart';
import 'features/chat/services/ai_config_store.dart';
import 'features/diary_list/services/temp_cover_store.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 水彩风格：使用透明状态栏
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // 初始化通知服务
  await NotificationService.initialize();

  // 初始化分享接收服务
  SharingIntentService.init();

  // 预加载 AI 配置（LlmService.providers 为同步接口，依赖此处的内存缓存）
  await AiConfigStore.load();

  // 清掉上一次运行留下的「临时封面图」。
  //
  // ★ 必须在这里，早于任何 UI 读取 —— 首页的封面位会读这个列表，
  //   晚一步就会先闪一下旧图再消失。
  // 不能放进 DiaryListScreen.initState：那样切到别的 tab 再回来就会
  //   把刚生成的图误删。需求要的是「下一次开启应用」这种确定性。
  await TempCoverStore.wipe();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FontSizeProvider()),
        ChangeNotifierProvider(create: (_) => DateFilterProvider()),
        ChangeNotifierProvider(create: (_) => DiaryListProvider()),
        ChangeNotifierProvider(create: (_) => DiaryWriteProvider()),
        ChangeNotifierProvider(create: (_) => SeasonalProvider()),
        ChangeNotifierProvider(create: (_) => AchievementProvider()..loadAchievements()),
        ChangeNotifierProvider(create: (_) => TemplateProvider()..loadTemplates()),
        ChangeNotifierProvider(create: (_) => ReminderProvider()..loadSettings()),
        ChangeNotifierProvider(create: (_) => StatisticsProvider()..loadStatistics()),
        ChangeNotifierProvider(create: (_) => StickerProvider()..loadStickers()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ChatSessionProvider()),
        // 悬浮球需要知道「现在停在哪个 tab / 主界面挂了没」，
        // 但悬浮球挂在 MaterialApp.builder 那一层，是 MainShell 的
        // 祖先的兄弟，拿不到它的 State —— 只能靠这个全局状态桥接
        ChangeNotifierProvider(create: (_) => AppChromeProvider()..load()),
      ],
      child: const DiaryApp(),
    ),
  );
}
