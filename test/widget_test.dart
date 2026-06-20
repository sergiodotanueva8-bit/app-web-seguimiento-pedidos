// Test básico de arranque de la app.
//
// El archivo original (generado por el template de Flutter) hacía
// referencia a una clase `MyApp` que nunca existió en este proyecto
// — la app real se llama `MrBarrilApp` (ver lib/main.dart). Por eso
// `flutter analyze` y `flutter test` fallaban con
// "The name 'MyApp' isn't a class".
//
// Este test no intenta probar lógica de negocio (login, pedidos, etc.),
// solo confirma que la app arranca sin tirar una excepción.

import 'package:flutter_test/flutter_test.dart';
import 'package:mrbarril_pedidos/main.dart';

void main() {
  testWidgets('La app arranca sin lanzar excepciones', (WidgetTester tester) async {
    await tester.pumpWidget(const MrBarrilApp());
    // Si llegó hasta aquí sin lanzar excepción, ya es una señal de que
    // el árbol de widgets raíz (MaterialApp + locales + tema) está bien.
    expect(find.byType(MrBarrilApp), findsOneWidget);
  });
}
