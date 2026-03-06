import 'package:flutter_test/flutter_test.dart';

import 'package:ai_mobile_coder_ui/src/app.dart';

void main() {
  testWidgets('renders workbench shell', (WidgetTester tester) async {
    await tester.pumpWidget(const AICoderApp());
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('新消息'), findsOneWidget);
    expect(find.text('开始新对话'), findsOneWidget);
  });
}
