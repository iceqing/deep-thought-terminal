import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deep_thought/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DeepThoughtApp());

    // Verify that loading screen or terminal is shown
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
