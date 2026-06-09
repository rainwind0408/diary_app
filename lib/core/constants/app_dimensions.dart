/// 水彩可爱风格的尺寸和间距常量
class AppDimensions {
  AppDimensions._();

  // ===== 间距系统 (8px grid) =====
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // ===== 卡片 =====
  static const double cardRadius = 20.0;      // 大圆角，水彩风格
  static const double cardPaddingH = 20.0;
  static const double cardPaddingV = 16.0;
  static const double cardMarginBottom = 12.0;
  static const double contentMaxHeight = 120.0;
  static const double fadeHeight = 36.0;

  // ===== 按钮 =====
  static const double buttonRadius = 24.0;    // 椭圆形按钮
  static const double buttonPaddingH = 24.0;
  static const double buttonPaddingV = 12.0;
  static const double buttonMinHeight = 48.0;

  // ===== 标签页 =====
  static const double tabPaddingV = 12.0;
  static const double tabPaddingH = 16.0;
  static const double tabRadius = 16.0;

  // ===== Toast =====
  static const double toastPaddingH = 20.0;
  static const double toastPaddingV = 12.0;
  static const double toastRadius = 16.0;
  static const double toastTopOffset = 20.0;

  // ===== 布局 =====
  static const double listPadding = 20.0;
  static const double listPaddingMobile = 16.0;
  static const double sectionGap = 12.0;
  static const double actionsGap = 12.0;

  // ===== 日记列表 =====
  static const double monthHeaderPadding = 16.0;
  static const double monthHeaderRadius = 12.0;

  // ===== 日期组 =====
  static const double dateGroupHeaderPadding = 12.0;
  static const double dateGroupGap = 20.0;
  static const double dateGroupInnerGap = 8.0;

  // ===== 日记编写页 =====
  static const double writePageRadius = 24.0;  // 编写区大圆角
  static const double writePagePadding = 24.0;
  static const double pagePaddingH = 20.0;     // 页面水平内边距
  static const double toolbarHeight = 56.0;

  // ===== 底部导航 =====
  static const double bottomNavHeight = 64.0;
  static const double bottomNavIconSize = 24.0;
  static const double bottomNavRadius = 16.0;

  // ===== 翻页 =====
  static const int maxPages = 10;
  static const int maxLinesPerPage = 15; // 每页最大行数
  static const double swipeThreshold = 50.0;

  // ===== 动画时长 (毫秒) =====
  static const int tabSwitchDuration = 300;
  static const int pageTurnDuration = 350;
  static const int cardEntranceDuration = 400;
  static const int cardExpandDuration = 350;
  static const int toastEnterDuration = 350;
  static const int toastDisplayDuration = 2500;
  static const int toastExitDuration = 400;
  static const int deleteAnimDuration = 300;
  static const int staggerDelay = 80;
  static const int pressAnimDuration = 100;

  // ===== 水平卡片轮播 =====
  static const double carouselCardWidth = 280.0;
  static const double carouselCardHeight = 360.0;
  static const double carouselCardRadius = 24.0;
  static const double carouselCardGap = 16.0;
}
