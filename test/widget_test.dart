// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:auth_buttons/auth_buttons.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglot/main.dart';

void main() {
  testWidgets('Login smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that there is a button
    expect(find.byType(GoogleAuthButton), findsOneWidget);

    // Tap the login button and trigger a frame.
    await tester.tap(find.byType(GoogleAuthButton));
    await tester.pump();

    // Verify that the page changes
    sleep(Duration(milliseconds: 500));
    expect(find.text('Login with Google'), findsNothing);
  });
}
