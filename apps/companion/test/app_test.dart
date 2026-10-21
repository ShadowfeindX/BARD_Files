import 'package:companion/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shell shows the app title', (tester) async {
    await tester.pumpWidget(const CompanionApp());
    expect(find.text('B.A.R.D. Companion'), findsOneWidget);
  });
}
