import 'package:flutter_test/flutter_test.dart';
import 'package:visit_cambodia/main.dart';

void main() {
  testWidgets('Visit Cambodia app starts', (WidgetTester tester) async {
    // Launch the Visit Cambodia application.
    await tester.pumpWidget(const VisitCambodiaApp());

    // Verify that the application root widget exists.
    expect(find.byType(VisitCambodiaApp), findsOneWidget);

    // Verify that the MaterialApp is present.
    expect(find.byType(VisitCambodiaApp), findsOneWidget);
  });
}
