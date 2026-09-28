import 'package:flutter_test/flutter_test.dart';
import 'package:pengingat_tugas/main.dart';

void main() {
  testWidgets('Smoke test aplikasi pengingat tugas', (WidgetTester tester) async {
    // Kita hanya perlu memastikan app bisa di-render awal tanpa crash
    await tester.pumpWidget(const PengingatTugasApp());
  });
}
