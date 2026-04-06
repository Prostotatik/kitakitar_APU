// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:center_web/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CenterWebApp());

    // Verify that the app loads with the login page
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}