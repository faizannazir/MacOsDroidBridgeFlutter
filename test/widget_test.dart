import 'package:flutter_test/flutter_test.dart';

import 'package:droid_bridge/app/bridge_app.dart';

void main() {
  testWidgets('renders dashboard content', (WidgetTester tester) async {
    await tester.pumpWidget(const BridgeApp());
    await tester.pumpAndSettle();

    expect(find.text('Droid Bridge'), findsOneWidget);
    expect(find.text('Connect a device'), findsOneWidget);
    expect(find.text('Share actions'), findsOneWidget);
  });
}
