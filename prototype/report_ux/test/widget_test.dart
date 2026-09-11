import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:report_ux/main.dart';

void main() {
  testWidgets('shell renders with the widget reader and TOC chips', (tester) async {
    await tester.pumpWidget(const ReportUxPrototypeApp());
    expect(find.text('Option A — widgets'), findsOneWidget);
    expect(find.byType(ActionChip), findsWidgets);
  });
}
