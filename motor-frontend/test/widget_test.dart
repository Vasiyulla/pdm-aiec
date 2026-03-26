// ============================================================
//  widget_test.dart  — Basic smoke test for Motor Dashboard
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:motor_frontend/main.dart';

void main() {
  testWidgets('App smoke test — renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MotorDashboardApp());
    await tester.pumpAndSettle();

    // The app should render without crashing
    expect(find.byType(MotorDashboardApp), findsOneWidget);
  });
}
