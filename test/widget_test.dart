import 'package:droid_bridge/app/bridge_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders iPhone Continuity dashboard layout', (WidgetTester tester) async {
    await tester.pumpWidget(const BridgeApp());
    await tester.pumpAndSettle();

    expect(find.text('iPhone Continuity'), findsOneWidget);
    expect(find.text('iPhone Mirroring'), findsWidgets);
  });
}
