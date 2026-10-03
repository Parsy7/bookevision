import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookevision/galerada/screens/g_splash.dart';

void main() {
  double opacidadLogo(WidgetTester tester) => tester
      .widget<Opacity>(
          find.ancestor(of: find.byType(Image), matching: find.byType(Opacity)).first)
      .opacity;

  testWidgets('la B aparece de menos a más, late en pantalla y luego deja paso a la app',
      (tester) async {
    var construida = 0;
    await tester.pumpWidget(MaterialApp(
      home: GSplash(child: Builder(builder: (_) {
        construida++;
        return const Text('La app');
      })),
    ));

    expect(construida, greaterThan(0),
        reason: 'la app se construye debajo desde el principio, para ir cargando');
    expect(opacidadLogo(tester), 0, reason: 'empieza invisible');

    await tester.pump(GSplash.duracion * 0.25);
    final aMitad = opacidadLogo(tester);
    expect(aMitad, inExclusiveRange(0, 1), reason: 'a medio fundido');

    await tester.pump(GSplash.duracion * 0.3);
    expect(opacidadLogo(tester), inExclusiveRange(0, 1),
        reason: 'ya apareció del todo, pero sigue latiendo, no se queda fija');

    // Mientras la B se queda en pantalla, su opacidad no se queda quieta:
    // late entre 1 y 0.3 una y otra vez.
    final valores = <double>[];
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      valores.add(opacidadLogo(tester));
    }
    expect(valores.toSet().length, greaterThan(1),
        reason: 'la opacidad cambia con el tiempo en vez de quedarse fija en 1');
    expect(valores.any((v) => v < 0.6), isTrue,
        reason: 'el latido baja de forma clara, hacia los 0.3 de opacidad');

    await tester.pump(GSplash.duracion);
    expect(find.byType(Image), findsNothing, reason: 'la pantalla de carga se ha ido');
    expect(find.text('La app'), findsOneWidget);
  });
}
