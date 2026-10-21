import 'package:bard/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shell shows the app title', (tester) async {
    await tester.pumpWidget(const BardApp());
    expect(find.text('B.A.R.D. Files'), findsOneWidget);
  });
}
