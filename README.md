# 手写日记

一款古董笔记本风格的个人日记应用，基于 Flutter 开发，支持 Android、iOS、Windows、macOS、Linux、Web 全平台。

## 特色

- 皮革封面 + 米色横线纸 + 金色点缀的沉浸式手帐风格
- 马善政/站酷小薇手写体字体
- 多页翻页写入，最多 10 页
- 心情 emoji 标记
- 按日期筛选浏览
- SQLite 本地存储，完全离线运行

## 技术栈

| 层面 | 技术 |
|------|------|
| 框架 | Flutter 3.x + Dart |
| 状态管理 | Provider |
| 本地数据库 | sqflite (SQLite) |
| 字体 | Ma Shan Zheng + ZCOOL XiaoWei |

## 快速开始

```bash
# 安装依赖
flutter pub get

# 运行（需要已连接设备或启动模拟器）
flutter run

# 构建 APK
flutter build apk --release
```

## 项目结构

```
lib/
├── core/           # 通用层：颜色、主题、工具类、复用组件
├── data/           # 数据层：SQLite 数据库、模型、仓库
├── features/       # 功能模块：列表页、写入页、设置页
└── shared/         # 共享服务：导出、生命周期
```

## 文档

| 文档 | 说明 |
|------|------|
| [功能规划.md](功能规划.md) | 功能路线图与状态标注 |
| [技术实现方案.md](技术实现方案.md) | 12 个功能的详细实现方案 |
| [Flutter重构方案.md](Flutter重构方案.md) | 从旧版重构到 Flutter 的设计文档 |
| [后续操作指南.md](后续操作指南.md) | 环境搭建与项目初始化 |
| [日常运行指南.md](日常运行指南.md) | 日常开发运行步骤与 FAQ |
