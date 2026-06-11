<div align="center">

<img src="assets/icon/app_icon_new.png" width="100" height="100">

# 折花日记

**一款水彩可爱笔记本风格的个人日记应用**

记录生活点滴，用温暖的笔触留住每一天

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Web-lightgrey)
![License](https://img.shields.io/badge/License-Private-blue)

</div>

---

## 应用简介

「折花日记」是一款注重书写体验的个人日记应用。采用水彩手帐风格设计，配合手写体字体，让每一次记录都像在精美的笔记本上书写。支持多页翻页、图片贴纸、语音录制、心情标记等功能，完全离线运行，守护你的隐私。

## 功能特性

### 核心功能

| 功能 | 说明 |
|------|------|
| 多页翻页书写 | 最多 10 页连续书写，自动分页，翻页动画流畅 |
| 图片附件 | 支持拍照/相册选择，可拖拽定位、缩放、旋转 |
| 语音录制 | 内录语音备忘，支持播放、暂停、拖拽定位 |
| 标签系统 | 自定义标签分类，标签云快速筛选 |
| 心情标记 | 5 种心情 emoji + 强度记录，心情日历可视化 |
| 日记加密 | PIN 码锁定日记，SHA-256 加密保护隐私 |

### 特色功能

| 功能 | 说明 |
|------|------|
| 二十四节气主题 | 跟随节气自动切换背景，每个节气独立配色 |
| 成就系统 | 20 种成就徽章，记录写作里程碑，解锁动画 |
| 写作统计 | 字数趋势、心情分布、写作热力图、年度报告 |
| 回顾日历 | 日历视图浏览历史日记，时间分布统计 |
| 模板系统 | 13 种日记模板（旅行、美食、读书、心情等） |
| 贴纸装饰 | 丰富贴纸库，自由贴放装饰日记页面 |
| 提醒功能 | 定时提醒写日记，培养记录习惯 |
| 天气集成 | 自动获取当地天气，记录当日天气状况 |
| AI 聊天 | 调用国内大模型 API，MCP 工具查询日记数据，智能分析对话 |

### 数据管理

| 功能 | 说明 |
|------|------|
| ZIP 完整备份 | 导出全部日记（含图片、音频）为 ZIP 文件 |
| ZIP 导入 | 从 ZIP 备份恢复日记，支持图片和音频还原 |
| 外部分享接收 | 接收其他应用分享的文本，快速创建日记 |
| 本地存储 | SQLite 数据库，完全离线运行，无需联网 |

## 技术架构

```
┌─────────────────────────────────────────────────┐
│                    UI 层                         │
│    水彩背景 + 手写体字体 + 圆角卡片 + 柔和阴影    │
├─────────────────────────────────────────────────┤
│                 features/                        │
│  diary_list │ diary_write │ achievements │ mood   │
│  statistics │ templates  │ stickers    │ review   │
│  reminders  │ settings   │ weather     │ onboarding│
│  chat (AI + MCP)                                          │
├─────────────────────────────────────────────────┤
│                 shared/                          │
│      export │ import │ zip │ sharing_intent      │
├─────────────────────────────────────────────────┤
│                  data/                           │
│         diary_entry │ placed_image/audio          │
│         diary_repository │ database_helper        │
├─────────────────────────────────────────────────┤
│                  core/                           │
│    colors │ text_styles │ theme │ utils │ widgets │
├─────────────────────────────────────────────────┤
│               本地存储层                          │
│          SQLite (sqflite) + SharedPreferences     │
└─────────────────────────────────────────────────┘
```

### 技术栈

| 层面 | 技术 | 说明 |
|------|------|------|
| 框架 | Flutter 3.x + Dart 3.x | 跨平台 UI 框架 |
| 状态管理 | Provider | 响应式状态管理 |
| 本地数据库 | sqflite (SQLite) | 结构化数据存储 |
| 轻量存储 | SharedPreferences | 键值对配置存储 |
| 图表 | fl_chart | 心情趋势、字数统计等图表 |
| 录音 | record + audioplayers | 音频录制与播放 |
| 图片选择 | image_picker + file_selector | 拍照/相册/文件选择 |
| 通知 | flutter_local_notifications | 本地定时提醒 |
| 天气 | http + geolocator | API 天气获取 + GPS 定位 |
| 备份 | archive | ZIP 压缩与解压 |
| 加密 | crypto | SHA-256 哈希加密 |
| AI 聊天 | http | 国内大模型 API 调用（OpenAI 兼容格式） |
| 字体 | Ma Shan Zheng + ZCOOL XiaoWei | 手写风格字体 |

## 快速开始

### 环境要求

- Flutter 3.x（推荐 3.22+）
- Dart 3.x
- Android Studio / VS Code
- 已连接的设备或模拟器

### 安装与运行

```bash
# 克隆仓库
git clone https://github.com/rainwind0408/diary_app.git
cd diary_app

# 安装依赖
flutter pub get

# 运行应用
flutter run

# 构建 Android APK
flutter build apk --release

# 构建 iOS
flutter build ios --release

# 构建 Windows
flutter build windows --release

# 构建 macOS
flutter build macos --release

# 构建 Linux
flutter build linux --release

# 构建 Web
flutter build web --release
```

## 项目结构

```
diary_app/
├── lib/
│   ├── main.dart                    # 应用入口
│   ├── app.dart                     # 根组件 + 主外壳 + 底部导航
│   │
│   ├── core/                        # 通用核心层
│   │   ├── constants/               # 常量（颜色、尺寸、文字样式、心情）
│   │   ├── theme/                   # Material 主题配置
│   │   ├── utils/                   # 工具（日期、字数、节气、分页解析）
│   │   └── widgets/                 # 通用组件（水彩背景、装饰、Toast）
│   │
│   ├── data/                        # 数据层
│   │   ├── database/                # SQLite 数据库管理
│   │   ├── models/                  # 数据模型（日记、图片、音频、天气）
│   │   └── repositories/            # 数据仓库（封装 CRUD 操作）
│   │
│   ├── features/                    # 功能模块（16 个模块）
│   │   ├── chat/                    # AI 聊天（MCP 工具 + 国内大模型）
│   │   ├── diary_list/              # 日记列表（筛选、搜索、卡片流）
│   │   ├── diary_write/             # 日记编写（多页、图片、音频、标签）
│   │   ├── diary_detail/            # 日记详情（只读展示）
│   │   ├── diary_encrypt/           # 日记加密（PIN 码管理）
│   │   ├── achievements/            # 成就系统（20 种成就）
│   │   ├── mood/                    # 心情系统（日历、趋势图）
│   │   ├── statistics/              # 统计图表（热力图、饼图、趋势）
│   │   ├── review/                  # 回顾日历
│   │   ├── templates/               # 模板系统（13 种模板）
│   │   ├── stickers/                # 贴纸系统
│   │   ├── voice_recording/         # 语音录制
│   │   ├── weather/                 # 天气服务 + 节气主题
│   │   ├── reminders/               # 提醒功能
│   │   ├── settings/                # 设置（主题、字体、导入导出）
│   │   └── onboarding/              # 欢迎页
│   │
│   └── shared/                      # 共享层
│       ├── services/                # 服务（导出、导入、ZIP、分享）
│       └── widgets/                 # 共享组件（确认弹窗）
│
├── assets/                          # 资源文件
│   ├── backgrounds/                 # 背景图（24 节气 + 5 季节水彩）
│   ├── decorations/                # 装饰元素（花朵、云朵、星星）
│   ├── fonts/                       # 手写字体
│   └── icon/                        # 应用图标
│
├── android/                         # Android 平台
├── ios/                             # iOS 平台
├── windows/                         # Windows 平台
├── macos/                           # macOS 平台
├── linux/                           # Linux 平台
└── web/                             # Web 平台
```

## UI 设计

### 水彩可爱笔记本风格

- **配色方案**：低饱和粉色、蓝色、绿色、黄色、紫色，柔和温馨
- **背景设计**：水彩纹理图片，跟随二十四节气自动切换
- **装饰元素**：水彩花朵、云朵、星星、蛋糕、茶杯等 PNG 素材
- **卡片风格**：大圆角（20px）、柔和阴影、半透明效果
- **字体选择**：Ma Shan Zheng 手写体（标题）+ ZCOOL XiaoWei（正文）

### 节气主题系统

应用内置 24 张节气背景图，开启节气主题后自动跟随当前节气切换：

> 立春 → 雨水 → 惊蛰 → 春分 → 清明 → 谷雨 → 立夏 → 小满 → 芒种 → 夏至 → 小暑 → 大暑 → 立秋 → 处暑 → 白露 → 秋分 → 寒露 → 霜降 → 立冬 → 小雪 → 大雪 → 冬至 → 小寒 → 大寒

同时支持天气集成，显示当前温度和天气状况。

## 平台支持

| 平台 | 状态 | 说明 |
|------|------|------|
| Android | ✅ | 完整支持，已测试 |
| iOS | ✅ | 完整支持 |
| Windows | ✅ | 完整支持，桌面端优化 |
| macOS | ✅ | 完整支持 |
| Linux | ✅ | 完整支持 |
| Web | ✅ | 基础支持 |

## 版本历史

| 版本 | 日期 | 主要变更 |
|------|------|---------|
| v3.3.1 | 2026-06-11 | 修复连续天数统计需重启才刷新的问题 |
| v3.3.0 | 2026-06-11 | 全面 bug 检测修复（连续天数/日期查询/类型安全） |
| v3.2.2 | 2026-06-10 | 视觉行数检测 + 递归分页 + 时区修复 |
| v3.2.1 | 2026-06-10 | API Key 按厂商持久化存储（切换厂商自动填充） |
| v3.2.0 | 2026-06-10 | 自定义模板 + 模型手动更新 + 键盘修复 + 应用更名折花日记 |
| v3.1.0 | 2026-06-09 | AI 聊天功能（MCP 工具 + 国内大模型 API + 设置页入口） |
| v3.0.0 | 2026-06-09 | 关于页面 + 华为提醒修复 + README 重设计 |
| v2.9.0 | 2026-06-09 | 导入功能优化（file_selector + Share Intent）+ 标签筛选修复 + 成就系统修复 |
| v2.8.0 | 2026-06-08 | 全局内容回流 + 原子化切页 + RangeError 修复 |
| v2.7.0 | 2026-06-07 | 3D 数组分页方案替代边界拼接方案 |
| v2.6.0 | 2026-06-06 | 录音页面化与自由定位 |
| v2.5.0 | 2026-06-06 | 输入超限自动跳页 + 连续内容分页 |
| v2.4.0 | 2026-06-05 | 每行空白字符功能 + APK 打包指南 |
| v2.2.0 | 2026-06-05 | ZIP 完整备份导出 + 图片拖拽 + 中心缩放 |
| v2.1.0 | 2026-06-05 | 二十四节气背景图替换 + 全局字体缩放 |
| v2.0.0 | 2026-06-04 | UI 重设计全部完成（水彩可爱风格） |
| v1.6.0 | 2026-06-03 | 统计增强（心情趋势/字数趋势/心情饼图/标签云） |
| v1.5.0 | 2026-06-03 | 模板扩充 + 提醒功能（13 模板 + 通知提醒） |
| v1.4.0 | 2026-06-03 | 成就系统（20 成就 + 解锁动画 + 4 栏导航） |
| v1.3.0 | 2026-06-03 | 心情系统 + 问候语横幅 |
| v1.0.0 | 2026-05-30 | 前端重构完成 + 天气 API 替换 |

## 相关文档

- [项目文件结构说明](项目文件结构说明.md) — 详细的文件结构与功能说明

---

<div align="center">

**用温暖的笔触，记录生活的每一天**

Made with Flutter & Dart

</div>
