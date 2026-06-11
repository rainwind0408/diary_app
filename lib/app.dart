import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_colors.dart';
import 'core/widgets/watercolor_background.dart';
import 'features/diary_list/providers/date_filter_provider.dart';
import 'features/diary_list/providers/diary_list_provider.dart';
import 'features/diary_write/screens/diary_write_screen.dart';
import 'features/settings/providers/font_size_provider.dart';
import 'features/settings/providers/theme_provider.dart';
import 'features/weather/providers/seasonal_provider.dart';
import 'features/achievements/screens/achievement_screen.dart';
import 'features/diary_list/screens/diary_list_screen.dart';
import 'features/onboarding/screens/welcome_screen.dart';
import 'features/review/screens/review_screen.dart';
import 'features/settings/screens/settings_screen.dart';

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final seasonalProvider = context.watch<SeasonalProvider>();
    final fontProvider = context.watch<FontSizeProvider>();

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(fontProvider.scale),
      ),
      child: MaterialApp(
        title: '折花日记',
        theme: AppTheme.buildLight(
            seasonalProvider.isEnabled ? seasonalProvider.palette : null),
        darkTheme: AppTheme.buildDark(
            seasonalProvider.isEnabled ? seasonalProvider.palette : null),
        themeMode: themeProvider.mode,
        debugShowCheckedModeBanner: false,
        home: const _AppEntry(),
      ),
    );
  }
}

/// 应用入口：检测首次启动，决定显示欢迎页还是主页
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _checking = true;
  bool _showWelcome = false;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;
    if (mounted) {
      setState(() {
        _showWelcome = !hasSeenWelcome;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      // 加载中：显示水彩背景
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: WatercolorBackground(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_showWelcome) {
      return WelcomeScreen(
        onComplete: () {
          setState(() => _showWelcome = false);
        },
      );
    }

    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final _diaryListKey = GlobalKey<DiaryListScreenState>();

  void _navigateToWrite() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DiaryWriteScreen()),
    );
    // 写完日记返回后刷新连续天数
    _diaryListKey.currentState?.refreshStreak();
  }

  void _switchToList() {
    setState(() => _currentIndex = 0);
    _diaryListKey.currentState?.refreshStreak();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: WatercolorBackground(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              DiaryListScreen(key: _diaryListKey, onNavigateToWrite: _navigateToWrite),
              const AchievementScreen(),
              ReviewScreen(onTagTapped: (_) => _switchToList()),
              const SettingsScreen(),
            ],
          ),
        ),
        bottomNavigationBar: _WatercolorBottomNav(
          currentIndex: _currentIndex,
          isDark: isDark,
          onTap: (index) {
            if (index == 4) {
              // 写日记按钮
              _navigateToWrite();
            } else {
              if (index == 0) {
                if (_currentIndex == 0) {
                  // 已在日记标签，点击刷新
                  final date = context.read<DateFilterProvider>().selectedDate;
                  context.read<DiaryListProvider>().loadEntries(date);
                }
                // 切换到日记标签时刷新连续天数
                _diaryListKey.currentState?.refreshStreak();
              }
              setState(() => _currentIndex = index);
            }
          },
        ),
      ),
    );
  }
}

/// 水彩风格底部导航栏（圆形图标风格，参考图2）
class _WatercolorBottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onTap;

  const _WatercolorBottomNav({
    required this.currentIndex,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final inactiveColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavCircleItem(
            icon: Icons.book,
            label: '日记',
            isActive: currentIndex == 0,
            activeColor: accentColor,
            inactiveColor: inactiveColor,
            onTap: () => onTap(0),
          ),
          _NavCircleItem(
            icon: Icons.emoji_events,
            label: '成就',
            isActive: currentIndex == 1,
            activeColor: accentColor,
            inactiveColor: inactiveColor,
            onTap: () => onTap(1),
          ),
          // 写日记按钮（中间突出）
          GestureDetector(
            onTap: () => onTap(4),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 22),
            ),
          ),
          _NavCircleItem(
            icon: Icons.bar_chart,
            label: '回顾',
            isActive: currentIndex == 2,
            activeColor: accentColor,
            inactiveColor: inactiveColor,
            onTap: () => onTap(2),
          ),
          _NavCircleItem(
            icon: Icons.settings,
            label: '设置',
            isActive: currentIndex == 3,
            activeColor: accentColor,
            inactiveColor: inactiveColor,
            onTap: () => onTap(3),
          ),
        ],
      ),
    );
  }
}

class _NavCircleItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavCircleItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive
                    ? activeColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? activeColor : inactiveColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
