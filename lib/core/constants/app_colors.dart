import 'package:flutter/material.dart';

/// 水彩可爱风格配色方案
/// 参考：粉红、浅黄、浅绿、浅紫、浅蓝的低饱和水彩色
class AppColors {
  AppColors._();

  // ===== 页面背景 =====
  // 亮色：温暖的米白/浅奶油
  static const Color pageBackground = Color(0xFFFFF8F0);
  static const Color pageBackgroundAlt = Color(0xFFFFF5E8);
  // 暗色：柔和的深紫/深蓝灰
  static const Color darkPageBackground = Color(0xFF1E1E2A);
  static const Color darkPageBackgroundAlt = Color(0xFF252535);

  // ===== 卡片背景 =====
  static const Color cardBackground = Color(0xFFFFFDF9);
  static const Color cardBackgroundAlt = Color(0xFFFFFBF5);
  static const Color darkCardBackground = Color(0xFF2A2A3C);
  static const Color darkCardBackgroundAlt = Color(0xFF32324A);

  // ===== AI 聊天画布 =====
  // 聊天页单独一套底色。原来用的是 pageBackground(#FFF8F0) + cardBackground
  // (#FFFDF9) 当气泡，两者亮度几乎一样（Δ0.016），气泡只能靠描边才看得出边界 ——
  // 于是工具气泡描紫边、思考面板再描一层，整屏都是框。把画布压暗一档、
  // 气泡提到纯白，边界靠明度差自然形成，边框就全可以撤掉了。
  //
  // 画布取值有硬约束：**必须同时对白气泡和粉色气泡都有明度差**。
  // 按 0.299R+0.587G+0.114B 的感知亮度算：
  //   #EAE5E0 (0.902) vs #FFFFFF (1.000) → Δ0.098
  //   #EAE5E0 (0.902) vs #F5C6D0 (0.836) → Δ0.066
  // 早先取的 #F0ECE8 与 pinkLight(#FBE4EA) 只差 0.005 —— 我方气泡会彻底糊在
  // 画布里，比改造前还差。所以画布不能再往亮里调。
  static const Color chatCanvas = Color(0xFFEAE5E0);      // 亮色：暖灰画布
  static const Color darkChatCanvas = Color(0xFF16161E);  // 暗色：比页面底更沉
  static const Color chatBubble = Color(0xFFFFFFFF);      // 收到的气泡
  static const Color darkChatBubble = Color(0xFF2E2E42);

  /// 发出的气泡。
  ///
  /// 用主色 [pink] 而不是更浅的 [pinkLight] —— 后者亮度和画布基本一致，
  /// 在暖灰底上等于没有气泡。这里保持粉色系，只是给足饱和度。
  static const Color chatBubbleUser = pink;

  /// 气泡阴影：只做「浮起来一点」的暗示，不能有方向感 ——
  /// 阴影一重，密集消息列表就会显得脏。
  static const List<BoxShadow> chatBubbleShadow = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> darkChatBubbleShadow = [
    BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  // ===== 水彩主色 =====
  // 粉色（主强调色）
  static const Color pink = Color(0xFFF5C6D0);
  static const Color pinkLight = Color(0xFFFBE4EA);
  static const Color pinkDark = Color(0xFFE8A0B0);
  static const Color darkPink = Color(0xFFFFB6D3);
  static const Color darkPinkLight = Color(0xFF3A2A3E);

  // 浅黄色
  static const Color yellow = Color(0xFFF5E6B8);
  static const Color yellowLight = Color(0xFFFFF8E8);
  static const Color darkYellow = Color(0xFFE8D4A0);

  // 浅绿色
  static const Color green = Color(0xFFC8E6C9);
  static const Color greenLight = Color(0xFFE8F5E9);
  static const Color darkGreen = Color(0xFF8DD4A0);

  // 浅紫色
  static const Color purple = Color(0xFFE8D5F5);
  static const Color purpleLight = Color(0xFFF3EAF9);
  static const Color darkPurple = Color(0xFFB8A0D0);

  // 浅蓝色
  static const Color blue = Color(0xFFD4E8F5);
  static const Color blueLight = Color(0xFFEAF4FB);
  static const Color darkBlue = Color(0xFF88C4E0);

  // ===== 文字颜色 =====
  // 亮色
  static const Color titleText = Color(0xFF5C4033);    // 深棕色标题
  static const Color headingText = Color(0xFF6B5040);  // 中棕色
  static const Color bodyText = Color(0xFF7A6555);     // 正文
  static const Color labelText = Color(0xFF9A8878);    // 标签
  // 次要文字：原 0xFFB8A898 在 #FFFDF9 白卡上实测仅 2.27:1 —— 连 AA 大字号的
  // 3:1 都不到。改成 0xFF9C8B7A 后为 3.24:1，属「提亮但不到位」的折中：
  // 再往深走就会越过 labelText(3.35:1) 甚至逼近 bodyText(5.41:1)，把
  // 正文 / 标签 / 次要 这三级层次压平。
  // 若要真正达到 AA 正文线(4.5:1)，需要 labelText + subtleText 一起加深，
  // 属独立的一次色板调整，不在这里顺手改。
  static const Color subtleText = Color(0xFF9C8B7A);   // 次要
  static const Color placeholderText = Color(0xFFD0C0B0); // 占位

  // 暗色
  static const Color darkTitleText = Color(0xFFF5F0E8);
  static const Color darkHeadingText = Color(0xFFE8E0D8);
  static const Color darkBodyText = Color(0xFFD0C8C0);
  static const Color darkLabelText = Color(0xFFA09890);
  static const Color darkSubtleText = Color(0xFF787070);
  static const Color darkPlaceholderText = Color(0xFF585050);

  // ===== 强调色/装饰色 =====
  // 柔和的粉色作为主强调
  static const Color accentPink = Color(0xFFF8A4C8);
  static const Color darkAccentPink = Color(0xFFFFB6D3);

  // 柔和的金色（替代原来的皮革金色）
  static const Color goldAccent = Color(0xFFE8C080);
  static const Color darkGoldAccent = Color(0xFFF0D098);

  /// 指针专用的深金。
  ///
  /// `goldAccent` 是**装饰**用的柔和金，在浅色卡纸 `cardBackground(#FFFDF9)`
  /// 上的对比度只有 **1.68:1** —— 画一条细线当装饰够用，但当**可拖动控件**
  /// 就太淡了（图形控件 WCAG 要求 ≥3:1，看不清就没人会去拖它）。
  /// 这个深度是 **3.2:1**，还是金，但抓得住。
  /// 深色主题不需要它：`darkGoldAccent` 在 `darkCardBackground` 上有 8.2:1。
  static const Color goldPointer = Color(0xFFBC8438);

  // 装饰线条
  static const Color dividerLine = Color(0x15E8C0A0);
  static const Color darkDividerLine = Color(0x20FFFFFF);

  // ===== 按钮 =====
  static const Color buttonPrimary = Color(0xFFF5C6D0);
  static const Color buttonPrimaryDark = Color(0xFFE8A0B0);
  static const Color darkButtonPrimary = Color(0xFFFFB6D3);
  static const Color buttonSecondary = Color(0xFFF5E6B8);
  static const Color darkButtonSecondary = Color(0xFF3A3A4A);

  // ===== 删除 =====
  static const Color deleteRed = Color(0xFFE05050);
  static const Color deleteRedLight = Color(0x1AE05050);

  // ===== 水彩装饰色 =====
  static const Color decoFlowerPink = Color(0xFFF5C6D0);
  static const Color decoCloudPurple = Color(0xFFE8D5F5);
  static const Color decoCloudBlue = Color(0xFFD4E8F5);
  static const Color decoStarGold = Color(0xFFE8C080);

  // ===== 心情颜色 =====
  static const Color moodHappy = Color(0xFFFFD54F);
  static const Color moodCalm = Color(0xFF81C784);
  static const Color moodSad = Color(0xFF90CAF9);
  static const Color moodExcited = Color(0xFFFF8A65);

  // ===== Toast =====
  static const Color toastSuccess = Color(0xFF66BB6A);
  static const Color toastSuccessBg = Color(0xFFE8F5E9);
  static const Color toastSuccessBorder = Color(0xFFA5D6A7);
  static const Color toastError = Color(0xFFEF5350);
  static const Color toastErrorBg = Color(0xFFFFEBEE);
  static const Color toastErrorBorder = Color(0xFFEF9A9A);
  static const Color toastWarning = Color(0xFFFFA726);
  static const Color toastWarningBg = Color(0xFFFFF8E1);
  static const Color toastWarningBorder = Color(0xFFFFE082);
  static const Color toastInfo = Color(0xFF42A5F5);
  static const Color toastInfoBg = Color(0xFFE3F2FD);
  static const Color toastInfoBorder = Color(0xFF90CAF9);

  // ===== 阴影 =====
  // 柔和的粉色阴影
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0AF5C6D0), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x06F5C6D0), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> cardHoverShadow = [
    BoxShadow(color: Color(0x12F5C6D0), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0CF5C6D0), blurRadius: 24, offset: Offset(0, 8)),
  ];

  // 暗色阴影
  static const List<BoxShadow> darkCardShadow = [
    BoxShadow(color: Color(0x30000000), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x20000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  // ===== 上下文感知辅助方法 =====
  static Color pageBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkPageBackground
          : pageBackground;

  static Color card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkCardBackground
          : cardBackground;

  static Color cardAlt(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkCardBackgroundAlt
          : cardBackgroundAlt;

  static Color title(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTitleText
          : titleText;

  static Color heading(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkHeadingText
          : headingText;

  static Color body(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkBodyText
          : bodyText;

  static Color label(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkLabelText
          : labelText;

  static Color subtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSubtleText
          : subtleText;

  static Color accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkAccentPink
          : accentPink;

  static Color gold(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkGoldAccent
          : goldAccent;

  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkDividerLine
          : dividerLine;

  // ===== 聊天页上下文辅助 =====
  static Color chatCanvasOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkChatCanvas
          : chatCanvas;

  static Color chatBubbleOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkChatBubble
          : chatBubble;

  static List<BoxShadow> chatBubbleShadowOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkChatBubbleShadow
          : chatBubbleShadow;

  static List<BoxShadow> shadow(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkCardShadow
          : cardShadow;
}
