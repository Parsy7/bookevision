import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookevision/galerada/screens/g_splash.dart';

void main() {
  double opacidadLogo(WidgetTester tester) => tester
      .widget<FadeTransition>(
          find.ancestor(of: find.byType(Image), matching: find.byType(FadeTransition)).first)
      .opacity
      .value;

  testWidgets('la B aparece de menos a más y luego deja paso a la app', (tester) async {
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
    expect(opacidadLogo(tester), 1, reason: 'del todo visible');

    await tester.pump(GSplash.duracion * 0.5);
    expect(find.byType(Image), findsNothing, reason: 'la pantalla de carga se ha ido');
    expect(find.text('La app'), findsOneWidget);
  });
}
