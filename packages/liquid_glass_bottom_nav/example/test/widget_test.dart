// Basic smoke test for the LiquidGlass Nav example app.

import 'package:flutter_test/flutter_test.dart';

import 'package:liquid_glass_bottom_nav_example/main.dart';

void main() {
  testWidgets('renders settings page and switches tabs via the nav bar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('LiquidGlass Nav'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Switch tabs using the nav bar below'), findsOneWidget);
  });
}
