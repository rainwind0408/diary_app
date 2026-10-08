import 'package:flutter/material.dart';

/// 全局 Navigator 句柄。
///
/// 悬浮球挂在 `MaterialApp.builder` 的 Stack 里，是 Navigator 的**兄弟节点**
/// 而不是它的后代 —— 所以在球的 `BuildContext` 上调 `Navigator.of(context)`
/// 找不到任何 Navigator（会抛 "No Navigator in context"）。
///
/// 必须给 `MaterialApp` 传一个 `navigatorKey`，球通过这个 key 拿到
/// `NavigatorState` 来 push 页面。
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
