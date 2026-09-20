import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/models/manual_edit.dart';
import 'package:bookevision/models/review.dart';
import 'package:bookevision/models/review_state.dart';
import 'package:bookevision/screens/reviewer_screen.dart';
import 'package:bookevision/services/api_service.dart';
import 'package:bookevision/services/review_session.dart';
import 'package:bookevision/theme/app_theme.dart';
import 'package:bookevision/widgets/prose_block.dart';

import 'soporte.dart';

const _md = '# La promesa\n\n'
    'Párrafo uno del capítulo.\n\n'
    'Párrafo dos del capítulo.\n\n'
    'Párrafo tres del capítulo.';

const _dos = 'Párrafo dos del capítulo.';

Review _documento() => const Review(
      id: 'doc',
      format: 'la-jaula-rota-review-v4',
      title: 'La promesa',
      chapter: _md,
      suggestions: [],
    );

/// API que devuelve un estado ya guardado, como el que tienes en el servidor.
class _ApiConEstado extends ApiFalsa {
  _ApiConEstado(this.edits) : super(_documento());
  final Map<String, ManualEdit> edits;

  @override
  Future<ReviewState> getEstado(String id) async =>
      ReviewState(answers: const [], manualEdits: edits);
}

/// Edición de las de antes: guardada por párrafo, no por capítulo entero.
ManualEdit _porParrafo(String texto, String nuevo) {
  final ini = _md.indexOf(texto);
  return ManualEdit(
      start: ini, end: ini + texto.length, original: texto, value: nuevo);
}

Future<ReviewSession> _cargar(Map<String, ManualEdit> edits) async {
  final s = ReviewSession(api: _ApiConEstado(edits));
  await s.load('doc');
  return s;
}

void main() {
  test('una edición por párrafo se dobla dentro del bloque único', () async {
    final vieja = _porParrafo(_dos, 'Dos, recortado.');
    final s = await _cargar({vieja.blockId: vieja});

    // Ya no cuelga de su párrafo: ahora es la edición del capítulo entero,
    // que es el único bloque que el lector pinta.
    expect(s.manualEdits.keys.single, 'b_0_${_md.length}');
    expect(s.currentText(), _md.replaceAll(_dos, 'Dos, recortado.'),
        reason: 'el trabajo hecho no se pierde');
    s.dispose();
  });

  test('lo que se ve es lo que se exporta', () async {
    final vieja = _porParrafo(_dos, 'Dos, recortado.');
    final s = await _cargar({vieja.blockId: vieja});

    // El lector pinta el valor del bloque; exportar compone lo mismo.
    expect(s.manualEdits['b_0_${_md.length}']!.value, s.currentText());
    s.dispose();
  });

  test('editar el capítulo entero después ya no revienta', () async {
    final vieja = _porParrafo(_dos, 'Dos.');
    final s = await _cargar({vieja.blockId: vieja});

    s.setManualEdit(0, _md.length, _md, '# La promesa\n\nSolo esto.');

    expect(s.currentText(), '# La promesa\n\nSolo esto.',
        reason: 'manda la edición del bloque que estás viendo');
    s.dispose();
  });

  test('varias ediciones viejas se doblan todas, en orden', () async {
    final a = _porParrafo('Párrafo uno del capítulo.', 'Uno.');
    final b = _porParrafo(_dos, 'Dos.');
    final s = await _cargar({a.blockId: a, b.blockId: b});

    expect(s.currentText(),
        '# La promesa\n\nUno.\n\nDos.\n\nPárrafo tres del capítulo.');
    s.dispose();
  });

  test('una revisión con tarjetas no se toca', () async {
    final s = ReviewSession(api: ApiFalsa());
    await s.load('x');

    // Los bloques de una revisión con sugerencias no han cambiado nunca.
    final pieza = s.review!.chapter.indexOf(fraseOriginal);
    s.setManualEdit(0, pieza - 1, s.review!.chapter.substring(0, pieza - 1),
        'Principio cambiado.');
    expect(s.currentText(), startsWith('Principio cambiado.'));
    expect(s.manualEdits.length, 1);
    s.dispose();
  });

  testWidgets('Revisar y confirmar no deja la pantalla en gris',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    EditableText.debugDeterministicCursor = true;
    addTearDown(() => EditableText.debugDeterministicCursor = false);

    final vieja = _porParrafo(_dos, 'Dos.');
    await tester.pumpWidget(Provider<ApiService>.value(
      value: _ApiConEstado({vieja.blockId: vieja}),
      child: MaterialApp(
          theme: appTheme, home: const ReviewerScreen(reviewId: 'doc')),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Se edita el capítulo entero, como haces tú, y luego se confirma.
    final caja = tester.getRect(find.byType(ProseBlock));
    await tester.longPressAt(Offset(caja.left + 30, caja.top + 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(EditableText), 'Capítulo recortado.');
    await tester.tap(find.text('Guardar').last);
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Revisar y confirmar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull,
        reason: 'esto es lo que dejaba la pantalla en gris');
    expect(find.text('Tu capítulo quedará así'), findsOneWidget);
    expect(find.textContaining('Capítulo recortado.'), findsWidgets);

    await tester.pump(const Duration(seconds: 2));
  });
}
