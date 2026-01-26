// This is a basic Flutter widget test for Notefy tuner app.

import 'package:flutter_test/flutter_test.dart';
import 'package:notefy/main.dart';

void main() {
  testWidgets('Notefy app starts successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NotefyApp());

    // Verify that the app title is displayed
    expect(find.text('Notefy'), findsOneWidget);
  });
}
