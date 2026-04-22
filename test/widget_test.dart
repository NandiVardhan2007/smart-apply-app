import 'package:flutter_test/flutter_test.dart';
import 'package:smart_apply/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartApplyApp(),
      ),
    );

    // Verify that the login screen title exists
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
