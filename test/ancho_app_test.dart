import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookevision/galerada/theme/g_spacing.dart';
import 'package:bookevision/galerada/widgets/g_ancho_app.dart';

void main() {
  late Size medidaDentro;

  Future<void> pintar(WidgetTester tester, Size ventana) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = ventana;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: GAnchoApp(
        child: Builder(builder: (context) {
          medidaDentro = MediaQuery.sizeOf(context);
          return const SizedBox.expand(key: Key('app'));
        }),
      ),
    ));
  }

  testWidgets('en escritorio la app es una columna centrada de anchoApp', (tester) async {
    await pintar(tester, const Size(1400, 900));
    final app = tester.getRect(find.byKey(const Key('app')));
    expect(app.width, GSpacing.anchoApp);
    expect(app.center.dx, 700, reason: 'centrada en la ventana');
    expect(medidaDentro.width, GSpacing.anchoApp,
        reason: 'lo que mide la pantalla (p. ej. el panel de la IA) ve la columna, no la ventana');
  });

  testWidgets('en el móvil no cambia nada', (tester) async {
    await pintar(tester, const Size(390, 844));
    expect(tester.getRect(find.byKey(const Key('app'))).width, 390);
    expect(medidaDentro.width, 390);
  });
}
