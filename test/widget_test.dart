import 'package:flutter_test/flutter_test.dart';

import 'package:yuandex/src/app.dart';

void main() {
  testWidgets('renders workbench shell', (WidgetTester tester) async {
    await tester.pumpWidget(const YuandexApp());
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('新消息'), findsOneWidget);
    expect(find.text('开始新对话'), findsOneWidget);
  });
}
