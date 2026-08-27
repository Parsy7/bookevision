import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/services/review_session.dart';
import 'package:bookevision/theme/app_theme.dart';
import 'package:bookevision/widgets/suggestion_card.dart';

import 'soporte.dart';

EditableTextState _campo(WidgetTester t) =>
    t.state<EditableTextState>(find.byType(EditableText));

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    EditableText.debugDeterministicCursor = true;
  });
  tearDown(() => EditableText.debugDeterministicCursor = false);

  testWidgets('mover la selección no reconstruye el lector entero',
      (tester) async {
    final sesion = ReviewSession(api: ApiFalsa());
    await sesion.load('x');
    sesion.setCustom(
        0,
        'Una versión propia bastante larga para poder seleccionar una frase '
        'entera dentro de ella sin quedarse corto.');

    await tester.pumpWidget(_conTarjeta(sesion));

    final campo = find.byType(EditableText);
    expect(campo, findsOneWidget);

    // A partir de aquí contamos cuántas veces se repinta todo el lector.
    var repintados = 0;
    void contar() => repintados++;
    sesion.addListener(contar);

    // Selección con pulsación larga + arrastre, sin tocar una sola letra.
    final r = tester.getRect(campo);
    final g = await tester.startGesture(Offset(r.left + 40, r.top + 12));
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 1; i <= 8; i++) {
      await g.moveTo(Offset(r.left + 40 + 20.0 * i, r.top + 12));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_campo(tester).textEditingValue.selection.isCollapsed, isFalse,
        reason: 'la prueba solo vale si de verdad ha seleccionado algo');
    expect(repintados, 0,
        reason: 'seleccionar no cambia el texto: no debe tocar la sesión '
            'ni repintar el capítulo entero');

    sesion.removeListener(contar);
    await tester.pump(const Duration(seconds: 2)); // vacía el autosave
    sesion.dispose();
  });

  testWidgets('escribir sí sigue guardándose', (tester) async {
    final sesion = ReviewSession(api: ApiFalsa());
    await sesion.load('x');
    sesion.setCustom(0, 'Mi versión');

    await tester.pumpWidget(_conTarjeta(sesion));

    await tester.enterText(find.byType(EditableText), 'Mi versión corregida');
    await tester.pump();

    expect(sesion.answerAt(0).custom, 'Mi versión corregida');

    await tester.pump(const Duration(seconds: 2));
    sesion.dispose();
  });

  testWidgets('"Usar sugerencia" deja el cursor en un sitio válido',
      (tester) async {
    final sesion = ReviewSession(api: ApiFalsa());
    await sesion.load('x');
    sesion.setCustom(0, 'Algo que tenía escrito');

    await tester.pumpWidget(_conTarjeta(sesion));

    // Con el campo enfocado, como cuando estás escribiendo.
    await tester.tap(find.byType(EditableText));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Usar sugerencia'));
    await tester.pump(const Duration(milliseconds: 400));

    final valor = _campo(tester).textEditingValue;
    expect(valor.text, 'su frase propuesta');
    expect(valor.selection.isValid, isTrue,
        reason: 'una selección inválida hace que el cursor salte solo');
    expect(valor.selection.baseOffset, valor.text.length);

    await tester.pump(const Duration(seconds: 2));
    sesion.dispose();
  });
}

Widget _conTarjeta(ReviewSession sesion) {
  return ChangeNotifierProvider<ReviewSession>.value(
    value: sesion,
    child: MaterialApp(
      theme: appTheme,
      home: const Scaffold(
        body: SingleChildScrollView(child: SuggestionCard(index: 0)),
      ),
    ),
  );
}
