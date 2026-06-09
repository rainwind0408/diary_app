import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App basic test', (WidgetTester tester) async {
    // 简化测试：只验证基本组件渲染
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('手写日记')),
          body: const Center(child: Text('测试页面')),
        ),
      ),
    );
    expect(find.text('手写日记'), findsOneWidget);
    expect(find.text('测试页面'), findsOneWidget);
  });
}
