import 'package:flutter_test/flutter_test.dart';
import 'package:aluminium_designer/app/app.dart';

void main() {
  testWidgets('AluVis launches', (WidgetTester tester) async {
    await tester.pumpWidget(const AluVisApp());

    expect(find.text('AluVis'), findsOneWidget);
    expect(find.text('Mes projets'), findsOneWidget);
    expect(find.text('Nouveau projet'), findsOneWidget);
  });
}
