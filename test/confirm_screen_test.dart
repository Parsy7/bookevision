import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:bookevision/screens/confirm_screen.dart';
import 'package:bookevision/widgets/app_button.dart';
import 'package:bookevision/services/review_session.dart';
import 'package:bookevision/theme/app_theme.dart';

final String _capitulo = List.filled(
  60,
  'La jaula seguía abierta y nadie en la casa se atrevía a decirlo en voz alta.',
).join('\n\n');

const _cuentas = Counts(
  total: 3,
  done: 3,
  pending: 0,
  accepted: 1,
  originals: 1,
  custom: 0,
  omitted: 1,
  manual: 2,
);

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: appTheme,
      home: ConfirmScreen(
          title: 'Capítulo', text: _capitulo, counts: _cuentas),
    ));
    await tester.pump();
  }

  testWidgets('los botones se ven sin hacer scroll', (tester) async {
    await abrir(tester);

    for (final rotulo in ['Guardar .md', 'Copiar todo']) {
      final caja = tester.getRect(find.text(rotulo));
      expect(caja.bottom, lessThanOrEqualTo(600),
          reason: '$rotulo tiene que estar dentro de la pantalla ya');
      expect(caja.top, greaterThanOrEqualTo(0));
    }
  });

  testWidgets('y siguen en su sitio al recorrer el capítulo', (tester) async {
    await abrir(tester);
    final antes = tester.getRect(find.text('Guardar .md'));

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pump();

    expect(tester.getRect(find.text('Guardar .md')), antes,
        reason: 'la barra es fija: el scroll no la mueve');
  });

  testWidgets('el resumen dice cuántos fragmentos se eliminan', (tester) async {
    await abrir(tester);
    expect(find.text('1 fragmento eliminado'), findsOneWidget,
        reason: 'en singular cuando es uno');
    expect(find.text('2 bloques editados directamente'), findsOneWidget);
  });

  testWidgets('la barra de navegación de Android no tapa los botones',
      (tester) async {
    addTearDown(tester.view.reset);
    const navegacion = 48.0; // barra de 3 botones de Android
    final fisicos = navegacion * tester.view.devicePixelRatio;
    tester.view.viewPadding = FakeViewPadding(bottom: fisicos);
    tester.view.padding = FakeViewPadding(bottom: fisicos);

    await abrir(tester);

    for (final rotulo in ['Guardar .md', 'Copiar todo']) {
      final caja = tester.getRect(find.widgetWithText(AppButton, rotulo));
      expect(caja.bottom, lessThanOrEqualTo(600 - navegacion),
          reason: '$rotulo se mete debajo de la barra de Android');
    }
  });
}
