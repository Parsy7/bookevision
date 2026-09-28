import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/config/app_config.dart';
import 'package:bookevision/models/answer.dart';
import 'package:bookevision/models/review.dart';
import 'package:bookevision/galerada/screens/g_confirm_screen.dart';
import 'package:bookevision/galerada/screens/g_review_list_screen.dart';
import 'package:bookevision/galerada/screens/g_reviewer_screen.dart';
import 'package:bookevision/galerada/theme/g_colors.dart';
import 'package:bookevision/galerada/theme/g_theme.dart';
import 'package:bookevision/galerada/widgets/g_bits.dart';
import 'package:bookevision/galerada/widgets/g_paragraphs.dart';
import 'package:bookevision/galerada/widgets/g_prose.dart';
import 'package:bookevision/galerada/widgets/g_suggestion_card.dart';
import 'package:bookevision/services/api_service.dart';
import 'package:bookevision/services/review_session.dart';

import 'soporte.dart';

const _doc = '# La promesa\n\n'
    'Párrafo uno del capítulo.\n\n'
    'Párrafo dos del capítulo.';

Review _documento() => const Review(
      id: 'doc',
      format: 'la-jaula-rota-review-v4',
      title: 'La promesa',
      chapter: _doc,
      suggestions: [],
    );

Widget _app(Widget home, ApiService api) => Provider<ApiService>.value(
      value: api,
      child: MaterialApp(theme: galeradaTheme, home: home),
    );

/// Lleva el widget a la vista antes de pulsarlo: el capítulo de prueba es más
/// alto que la pantalla del test.
Future<void> _pulsar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

Future<void> _asentar(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('es', null));

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    EditableText.debugDeterministicCursor = true;
  });
  tearDown(() => EditableText.debugDeterministicCursor = false);

  test('la piel por defecto es Galerada', () {
    expect(AppConfig.piel, Piel.galerada);
  });

  group('numeración de párrafos', () {
    test('cuenta por línea en blanco, empezando en ¶1', () {
      expect(GParagraphs.at(_doc, 0), 1);
      expect(GParagraphs.at(_doc, _doc.indexOf('Párrafo uno')), 2);
      expect(GParagraphs.at(_doc, _doc.indexOf('Párrafo dos')), 3);
    });

    test('una inserción abarca dos párrafos', () {
      final i = _doc.indexOf('Párrafo uno');
      expect(GParagraphs.label(_doc, i), '¶2');
      expect(GParagraphs.label(_doc, i, end: _doc.indexOf('Párrafo dos')),
          '¶2–¶3');
    });
  });

  group('portada', () {
    testWidgets('hero, medidor y sellos', (tester) async {
      await tester.pumpWidget(
          _app(const GReviewListScreen(), ApiFalsaConVarias()));
      await _asentar(tester);

      expect(find.textContaining('LA JAULA'), findsNothing,
          reason: 'el hero va en Instrument Serif, no en mayúsculas mono');
      expect(find.text('BOOKEVISION'), findsOneWidget,
          reason: 'la marca sí es mono en mayúsculas');
      expect(find.byType(GMeter), findsWidgets);
      expect(find.byType(GStamp), findsWidgets);
      expect(find.text('01'), findsOneWidget, reason: 'número de dos dígitos');
    });

    testWidgets('lista vacía: página en blanco', (tester) async {
      await tester.pumpWidget(_app(const GReviewListScreen(), ApiFalsaVacia()));
      await _asentar(tester);

      expect(find.textContaining('Página en '), findsOneWidget);
      expect(find.text('Importar revisión'), findsOneWidget);
      expect(find.text('FORMATO · LA-JAULA-ROTA-REVIEW-V4'), findsOneWidget);
    });
  });

  group('lector', () {
    testWidgets('la tarjeta trae las cuatro acciones con sus teclas',
        (tester) async {
      await tester
          .pumpWidget(_app(const GReviewerScreen(reviewId: 'x'), ApiFalsa()));
      await _asentar(tester);

      expect(find.byType(GSuggestionCard), findsOneWidget);
      for (final r in ['Texto original', 'Aceptar propuesta', 'Escribir yo',
        'Eliminar original']) {
        expect(find.text(r), findsOneWidget);
      }
      for (final k in ['O', 'A', 'E', 'X']) {
        expect(find.text(k), findsOneWidget, reason: 'tecla $k');
      }
      expect(find.text('● PENDIENTE'), findsOneWidget);
    });

    testWidgets('elegir una acción la marca y resuelve la tarjeta',
        (tester) async {
      await tester
          .pumpWidget(_app(const GReviewerScreen(reviewId: 'x'), ApiFalsa()));
      await _asentar(tester);

      await _pulsar(tester, find.text('Eliminar original'));

      final sesion = Provider.of<ReviewSession>(
          tester.element(find.byType(GSuggestionCard)),
          listen: false);
      expect(sesion.answerAt(0).choice, Choice.omit);
      expect(find.text('● RESUELTA'), findsOneWidget);
      expect(find.textContaining('desaparecerá del capítulo'), findsOneWidget,
          reason: 'la franja de aviso roja');

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('la barra inferior lleva la cuenta en singular y plural',
        (tester) async {
      await tester
          .pumpWidget(_app(const GReviewerScreen(reviewId: 'x'), ApiFalsa()));
      await _asentar(tester);

      expect(find.text('1 pendiente'), findsOneWidget,
          reason: 'una sola sugerencia: singular');

      await _pulsar(tester, find.text('Aceptar propuesta'));
      expect(find.text('Revisar y confirmar'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('prosa', () {
    testWidgets('la pulsación larga abre todo el capítulo con el cursor donde '
        'se pulsa', (tester) async {
      await tester.pumpWidget(
          _app(const GReviewerScreen(reviewId: 'doc'), ApiFalsa(_documento())));
      await _asentar(tester);

      final bloque = find.byType(GProseBlock);
      expect(bloque, findsOneWidget);
      final caja = tester.getRect(bloque);
      final antes = caja;

      final punto = Offset(caja.left + 60, caja.top + 40);
      await tester.longPressAt(punto);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final campo = tester.widget<EditableText>(find.byType(EditableText));
      expect(campo.controller.text, _doc,
          reason: 'el capítulo entero, no un párrafo');

      final estado =
          tester.state<EditableTextState>(find.byType(EditableText));
      final sel = estado.textEditingValue.selection;
      expect(sel.baseOffset, greaterThan(0));
      expect(sel.baseOffset, lessThan(_doc.length),
          reason: 'ni al principio ni al final');

      expect(tester.getRect(bloque).top, closeTo(antes.top, 0.5),
          reason: 'entrar a editar no mueve el bloque');
      expect(find.text('Guardar'), findsOneWidget,
          reason: 'las acciones van en la barra fija, no dentro del bloque');

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('un bloque editado lleva franja roja y sus chips',
        (tester) async {
      await tester.pumpWidget(
          _app(const GReviewerScreen(reviewId: 'doc'), ApiFalsa(_documento())));
      await _asentar(tester);

      final caja = tester.getRect(find.byType(GProseBlock));
      await tester.longPressAt(Offset(caja.left + 60, caja.top + 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(EditableText), 'Capítulo recortado.');
      await tester.tap(find.text('Guardar'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('VER ORIGINAL'), findsOneWidget);
      expect(find.text('RESTAURAR'), findsOneWidget);

      final marco = tester.widget<Container>(
        find
            .descendant(
                of: find.byType(GProseBlock), matching: find.byType(Container))
            .first,
      );
      final borde = (marco.decoration as BoxDecoration).border! as Border;
      expect(borde.left.color, GColors.red);
      expect(borde.left.width, 3);

      await tester.pump(const Duration(seconds: 2));
    });
  });

  testWidgets('la confirmación cuenta con números grandes', (tester) async {
    await tester.pumpWidget(_app(
      const GConfirmScreen(
        title: 'Capítulo',
        text: _doc,
        counts: Counts(
          total: 3,
          done: 3,
          pending: 0,
          accepted: 2,
          originals: 0,
          custom: 0,
          omitted: 1,
          manual: 1,
        ),
      ),
      ApiFalsa(),
    ));
    await tester.pump();

    expect(find.text('Propuestas aceptadas'), findsOneWidget);
    expect(find.text('Fragmento eliminado'), findsOneWidget,
        reason: 'en singular cuando es uno');
    expect(find.text('Guardar .md'), findsOneWidget);
    expect(find.text('Copiar todo'), findsOneWidget);
  });
}
