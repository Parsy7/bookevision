import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/config/app_config.dart';
import 'package:bookevision/models/answer.dart';
import 'package:bookevision/models/review.dart';
import 'package:bookevision/galerada/screens/g_confirm_screen.dart';
import 'package:bookevision/galerada/screens/g_original_screen.dart';
import 'package:bookevision/galerada/screens/g_preview_screen.dart';
import 'package:bookevision/galerada/screens/g_review_list_screen.dart';
import 'package:bookevision/galerada/screens/g_reviewer_screen.dart';
import 'package:bookevision/galerada/theme/g_colors.dart';
import 'package:bookevision/galerada/theme/g_theme.dart';
import 'package:bookevision/galerada/widgets/g_bits.dart';
import 'package:bookevision/galerada/widgets/g_foot.dart';
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

/// Un párrafo largo de una sola línea (sin saltos), para que arrastrar el
/// dedo tenga sitio de sobra dentro de la misma línea envuelta, sin caer
/// cerca del final corto de un título como en `_documento()`.
Review _documentoLargo() => const Review(
      id: 'doc',
      format: 'la-jaula-rota-review-v4',
      title: 'Uno',
      chapter: 'Una frase bastante larga para que el arrastre del dedo tenga '
          'sitio de sobra donde recorrer sin salirse de la línea visible.',
      suggestions: [],
    );

Widget _app(Widget home, ApiService api) => Provider<ApiService>.value(
      value: api,
      child: MaterialApp(theme: buildGaleradaTheme(), home: home),
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
      await tester.pumpWidget(_app(
          const GReviewListScreen(libroId: 1, libroTitle: 'Mi libro de prueba'),
          ApiFalsaConVarias()));
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
      await tester.pumpWidget(_app(
          const GReviewListScreen(libroId: 1, libroTitle: 'Mi libro de prueba'),
          ApiFalsaVacia()));
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

    testWidgets(
        'arrastrar tras la pulsación larga selecciona en vez de editar y abre la IA',
        (tester) async {
      await tester.pumpWidget(
          _app(const GReviewerScreen(reviewId: 'doc'), ApiFalsa(_documentoLargo())));
      await _asentar(tester);

      final caja = tester.getRect(find.byType(GProseBlock));
      final inicio = Offset(caja.left + 40, caja.top + 20);
      final fin = Offset(caja.left + 300, caja.top + 20);

      final gesto = await tester.startGesture(inicio);
      await tester.pump(const Duration(milliseconds: 600)); // supera el umbral de pulsación larga
      await gesto.moveTo(fin);
      await tester.pump();
      await gesto.up();
      await tester.pump();

      expect(find.text('Guardar'), findsNothing,
          reason: 'arrastrar tras la pulsación larga selecciona, no edita el bloque');
      expect(find.textContaining('Sobre:'), findsOneWidget,
          reason: 'el panel de la IA se abre con el fragmento arrastrado como contexto');

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets(
        'ya en modo edición, seleccionar texto también ofrece "Preguntar a la IA"',
        (tester) async {
      await tester.pumpWidget(
          _app(const GReviewerScreen(reviewId: 'doc'), ApiFalsa(_documento())));
      await _asentar(tester);

      final caja = tester.getRect(find.byType(GProseBlock));
      await tester.longPressAt(Offset(caja.left + 60, caja.top + 40));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final controlador = tester.widget<EditableText>(find.byType(EditableText)).controller;
      controlador.selection = const TextSelection(baseOffset: 2, extentOffset: 13); // "La promesa"

      final campo = tester.widget<TextField>(find.byType(TextField));
      final estado = tester.state<EditableTextState>(find.byType(EditableText));
      final menu = campo.contextMenuBuilder!(tester.element(find.byType(TextField)), estado);

      await tester.pumpWidget(MaterialApp(home: Material(child: menu)));
      expect(find.text('Preguntar a la IA'), findsOneWidget);

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

  group('asistente flotante', () {
    testWidgets('la burbuja no tapa la barra de navegación del lector',
        (tester) async {
      await tester.pumpWidget(
          _app(const GReviewerScreen(reviewId: 'doc'), ApiFalsa(_documentoLargo())));
      await _asentar(tester);

      final barra = tester.getRect(find.byType(GFoot));
      final burbuja = tester.getRect(find.byIcon(Icons.auto_awesome));

      expect(burbuja.bottom, lessThanOrEqualTo(barra.top),
          reason: 'la burbuja debe flotar por encima de la barra, no sobre ella');
    });
  });

  group('vista previa', () {
    testWidgets(
        'seleccionar texto pregunta a la IA, pero no ofrece "usar como sugerencia"',
        (tester) async {
      await tester.pumpWidget(_app(
        const GPreviewScreen(
          title: 'Capítulo',
          text: 'Una frase cualquiera del capítulo ya compuesto.',
          revisionId: 'x',
          counts: Counts(
              total: 0, done: 0, pending: 0, accepted: 0, originals: 0, custom: 0, omitted: 0, manual: 0),
        ),
        ApiFalsa(),
      ));
      await tester.pump();

      final area = tester.widget<SelectionArea>(find.byType(SelectionArea));
      area.onSelectionChanged!(const SelectedContent(plainText: 'frase cualquiera'));
      await tester.pump();

      expect(find.text('Preguntar a la IA'), findsOneWidget);
      await tester.tap(find.text('Preguntar a la IA'));
      await tester.pump();

      expect(find.textContaining('Sobre:'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '¿Qué te parece?');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Respuesta sobre la selección'), findsOneWidget);
      expect(find.textContaining('USAR COMO SUGERENCIA'), findsNothing,
          reason: 'el fragmento viene del texto ya compuesto, no se puede '
              'anclar de vuelta en el capítulo original');
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

  testWidgets('la barra de estado de Android no tapa la barra superior',
      (tester) async {
    addTearDown(tester.view.reset);
    const estado = 24.0; // reloj, iconos y batería del sistema
    final fisicos = estado * tester.view.devicePixelRatio;
    tester.view.viewPadding = FakeViewPadding(top: fisicos);
    tester.view.padding = FakeViewPadding(top: fisicos);

    await tester
        .pumpWidget(_app(const GReviewerScreen(reviewId: 'x'), ApiFalsa()));
    await _asentar(tester);

    for (final f in [
      find.byIcon(Icons.arrow_back),
      find.byIcon(Icons.more_horiz),
    ]) {
      expect(tester.getRect(f).top, greaterThanOrEqualTo(estado),
          reason: 'el hub de Android se comía el botón y no se podía pulsar');
    }

    // Y el cuerpo sigue empezando por debajo de la barra, no detrás.
    expect(tester.getRect(find.byType(GProseBlock).first).top,
        greaterThan(estado + 40));

    await tester.pump(const Duration(seconds: 2));
  });

  group('barra inferior', () {
    testWidgets('la CTA llena el alto entero de la barra, no solo su texto',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildGaleradaTheme(),
        home: Scaffold(
          bottomNavigationBar: GFoot.navegada(
            label: '17 pendientes',
            fill: GFootFill.red,
            onMain: () {},
            onUp: () {},
            onDown: () {},
          ),
          body: const SizedBox(),
        ),
      ));
      await tester.pump();

      final barra = tester.getRect(find.byType(GFoot));
      // El Container rojo es el que está entre las dos flechas (64..ancho-64).
      final cta = tester.getRect(find
          .ancestor(of: find.text('17 pendientes'), matching: find.byType(Container))
          .first);

      expect(cta.height, closeTo(barra.height, 1),
          reason: 'antes se encogía al alto del texto y dejaba papel arriba '
              'y abajo');
      expect(cta.top, closeTo(barra.top, 1));
      expect(cta.bottom, closeTo(barra.bottom, 1));
    });

    testWidgets('las flechas también llenan el alto entero', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildGaleradaTheme(),
        home: Scaffold(
          bottomNavigationBar: GFoot.navegada(
            label: '1 pendiente',
            fill: GFootFill.red,
            onMain: () {},
            onUp: () {},
            onDown: () {},
          ),
          body: const SizedBox(),
        ),
      ));
      await tester.pump();

      final barra = tester.getRect(find.byType(GFoot));
      final flecha = tester.getRect(find
          .ancestor(of: find.byIcon(Icons.north), matching: find.byType(Container))
          .first);

      expect(flecha.height, closeTo(barra.height, 1));
    });
  });

  testWidgets('el capítulo original reserva el hueco del menú de Android',
      (tester) async {
    addTearDown(tester.view.reset);
    const navegacion = 48.0; // menú de gestos / 3 botones de Android
    final fisicos = navegacion * tester.view.devicePixelRatio;
    tester.view.viewPadding = FakeViewPadding(bottom: fisicos);
    tester.view.padding = FakeViewPadding(bottom: fisicos);

    final capitulo = List.filled(30, 'Un párrafo de relleno bien largo.')
        .join('\n\n');
    await tester.pumpWidget(_app(
      GOriginalScreen(chapter: capitulo, revisionId: 'x'),
      ApiFalsa(),
    ));
    await tester.pump();

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -5000));
    await tester.pump();

    final ultimo = tester.getRect(find.byType(GProse).last);
    expect(ultimo.bottom, lessThanOrEqualTo(600 - navegacion),
        reason: 'el último párrafo quedaba debajo del menú de Android');
  });
}
