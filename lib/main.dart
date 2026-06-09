import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
      ],
      child: const DiaryApp(),
    ),
  );
}
