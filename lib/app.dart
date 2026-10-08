import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_colors.dart';
import 'core/navigation/app_navigator.dart';
import 'core/providers/app_chrome_provider.dart';
import 'core/widgets/watercolor_background.dart';
import 'features/assistant/services/assistant_route_observer.dart';
import 'features/assistant/services/orb_visibility.dart';
import 'features/assistant/widgets/floating_assistant_orb.dart';
import 'features/assistant/widgets/tool_confirmation_card.dart';
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

    // 字体缩放：恒用用户手动选择的倍率。
    // （曾经的「字体跟随系统」开关已于 2026-10-08 整条移除，
    //   原因见 FontSizeProvider 的文档注释。）
    final textScaler = TextScaler.linear(fontProvider.scale);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: MaterialApp(
        title: '折花日记',
        theme: AppTheme.buildLight(
            seasonalProvider.isEnabled ? seasonalProvider.palette : null),
        darkTheme: AppTheme.buildDark(
            seasonalProvider.isEnabled ? seasonalProvider.palette : null),
        themeMode: themeProvider.mode,
        debugShowCheckedModeBanner: false,
        // 悬浮球需要主动 push 页面，而它挂在 Navigator 之上，
        // 没有自己的 BuildContext 可用 —— 只能靠这个全局 key 拿根 Navigator
        navigatorKey: appNavigatorKey,
        // 悬浮球靠它判断当前栈顶是不是「该藏起来」的页面 / 弹层
        navigatorObservers: [assistantRouteObserver],
        // 悬浮球必须挂在 Navigator **之上**，否则 `Navigator.push` 出来的
        // 页面会把它盖住（写日记、日记详情、成就详情……全都会盖住）。
        // `MaterialApp.builder` 是唯一能稳定拿到这一层的位置。
        // 代价是它同时也会盖住弹层，所以上面那个 observer 是必需的。
        //
        // 确认卡片放在**最后**：它必须盖在悬浮球上面 ——
        // 否则「AI 要删日记」的卡片会被球压住一角，而球在那时毫无用处。
        builder: (context, child) => Stack(
          children: [
            if (child != null) child,
            const FloatingAssistantOrb(),
            const ToolConfirmationCard(),
          ],
        ),
        home: const _AppEntry(),
      ),
    );
  }
}

/// 单例：`Navigator` 在 rebuild 时会比较 observers 列表，
/// 每次 `build` 都 new 一个会触发反复解绑 / 重绑。
/// 观察者的状态本身是静态的，所以不影响正确性，但没必要。
final AssistantRouteObserver assistantRouteObserver = AssistantRouteObserver();

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

  @override
  void initState() {
    super.initState();
    // 主界面挂上之后悬浮球才该出现（首次启动的欢迎页 / 启动 loading 期间不该有）。
    // 放在 post-frame：initState 阶段上层的悬浮球可能正在 build，
    // 这时候 notifyListeners 会触发「build 期间 markNeedsBuild」报错。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppChromeProvider>().setShellVisible(true);
    });
  }

  /// 切 tab 时同步给全局状态 —— 悬浮球靠它判断「现在是不是停在设置页」
  void _setIndex(int index) {
    setState(() => _currentIndex = index);
    context.read<AppChromeProvider>().setTabIndex(index);
  }

  void _navigateToWrite() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        // 必须显式命名：写日记画布上的图片 / 贴纸 / 录音都可拖拽，
        // 悬浮球压在上面会抢走手势，靠这个名字把它藏起来
        settings: const RouteSettings(name: OrbRoutes.write),
        builder: (_) => const DiaryWriteScreen(),
      ),
    );
    // 写完日记返回后刷新连续天数
    _diaryListKey.currentState?.refreshStreak();
  }

  void _switchToList() {
    _setIndex(0);
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
          _setIndex(0);
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
              _setIndex(index);
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
