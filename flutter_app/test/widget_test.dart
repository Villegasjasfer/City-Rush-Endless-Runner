// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:city_rush_endless_runner/main.dart';

void main() {
  testWidgets('shows both runners and the start action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CityRushApp());

    expect(find.text('CITY RUSH'), findsOneWidget);
    expect(find.text('PLAYER 1'), findsOneWidget);
    expect(find.text('PLAYER 2'), findsOneWidget);
    expect(find.text('START THE RUN'), findsOneWidget);
  });
}
