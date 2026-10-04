import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/config/app_config.dart';
import 'package:bookevision/models/answer.dart';
import 'package:bookevision/models/capitulo.dart';
import 'package:bookevision/models/libro.dart';
import 'package:bookevision/models/review_summary.dart';
import 'package:bookevision/models/review.dart';
import 'package:bookevision/galerada/screens/g_confirm_screen.dart';
import 'package:bookevision/galerada/screens/g_libro_list_screen.dart';
import 'package:bookevision/galerada/screens/g_libro_screen.dart';
import 'package:bookevision/galerada/screens/g_original_screen.dart';
import 'package:bookevision/galerada/screens/g_preview_screen.dart';
import 'package:bookevision/galerada/screens/g_review_list_screen.dart';
import 'package:bookevision/galerada/screens/g_reviewer_screen.dart';
import 'package:bookevision/galerada/theme/g_colors.dart';
import 'package:bookevision/galerada/theme/g_theme.dart';
import 'package:bookevision/galerada/widgets/g_bits.dart';
import 'package:bookevision/galerada/widgets/g_foot.dart';
import 'package:bookevision/galerada/widgets/g_lista.dart';
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

const _libro = Libro(id: 1, title: 'Mi libro de prueba', capitulos: 3);
const _capitulo = Capitulo(id: 2, libroId: 1, numero: 14, titulo: 'XIV Primero la promesa');
const _portadaCapitulo = GReviewListScreen(libro: _libro, capitulo: _capitulo);

/// Dos capítulos sueltos: uno ya marcado como finalizado y otro no.
class _ApiDosSueltos extends ApiFalsa {
  @override
  Future<List<ReviewSummary>> getRevisiones({String? libroId, int? capituloId}) async => const [
        ReviewSummary(id: 'a', format: 'f', title: 'Final', total: 0, resolved: 0, manual: 0, finalizada: true),
        ReviewSummary(id: 'b', format: 'f', title: 'Borrador', total: 0, resolved: 0, manual: 0),
      ];
}

class _ApiConLibros extends ApiFalsa {
  @override
  Future<List<Libro>> getLibros() async => const [_libro];
}

/// Un libro con muchos capítulos, más de los que caben en la hoja de mover.
class _ApiMuchosCapitulos extends ApiFalsaConVarias {
  @override
  Future<List<Capitulo>> getCapitulos(int libroId) async => [
        for (var i = 1; i <= 30; i++)
          Capitulo(id: 100 + i, libroId: 1, numero: i, titulo: 'Capítulo número $i'),
      ];
}

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
      await tester.pumpWidget(_app(_portadaCapitulo, ApiFalsaConVarias()));
      await _asentar(tester);

      expect(find.text('XIV Primero la promesa'), findsOneWidget,
          reason: 'el hero es el título del capítulo');
      expect(find.textContaining('LA JAULA'), findsNothing,
          reason: 'el hero va en Instrument Serif, no en mayúsculas mono');
      expect(find.text('BOOKEVISION'), findsNothing,
          reason: 'la marca y el logo solo van en «Mis libros»');
      expect(find.descendant(of: find.byType(GHero), matching: find.byType(Image)), findsNothing);
      expect(find.byType(GMeter), findsWidgets);
      expect(find.byType(GStamp), findsWidgets);
      expect(find.text('01'), findsOneWidget, reason: 'número de dos dígitos');
    });

    testWidgets('«Mis libros» lleva el logo junto a la marca', (tester) async {
      await tester.pumpWidget(_app(const GLibroListScreen(), _ApiConLibros()));
      await _asentar(tester);

      expect(find.text('BOOKEVISION'), findsOneWidget,
          reason: 'la marca es mono en mayúsculas');
      expect(find.descendant(of: find.byType(GHero), matching: find.byType(Image)), findsOneWidget,
          reason: 'el logo va junto a «bookevision»');
    });

    testWidgets('lista vacía: página en blanco', (tester) async {
      await tester.pumpWidget(_app(_portadaCapitulo, ApiFalsaVacia()));
      await _asentar(tester);

      expect(find.textContaining('Página en '), findsOneWidget);
      expect(find.text('Importar revisión'), findsOneWidget);
      expect(find.text('FORMATO · LA-JAULA-ROTA-REVIEW-V4'), findsOneWidget);
    });

    testWidgets('un capítulo suelto finalizado lleva el sello LISTO relleno',
        (tester) async {
      await tester.pumpWidget(_app(_portadaCapitulo, _ApiDosSueltos()));
      await _asentar(tester);

      final sellos = tester.widgetList<GStamp>(find.byType(GStamp)).toList();
      expect(sellos.map((s) => (s.label, s.filled)), [('Listo', true), ('.md', false)]);
    });

    testWidgets('mantener pulsada una revisión permite moverla a otro capítulo',
        (tester) async {
      final api = ApiFalsaConVarias();
      await tester.pumpWidget(_app(_portadaCapitulo, api));
      await _asentar(tester);

      await tester.longPress(find.text('Capítulo 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mover a otro capítulo'));
      await tester.pumpAndSettle();

      expect(find.text('14 · XIV Primero la promesa'), findsNothing,
          reason: 'el capítulo en el que ya está no se ofrece');
      await tester.tap(find.text('15 · XV El regreso'));
      await tester.pumpAndSettle();

      expect(api.movidas, {'c1': 3});
    });

    testWidgets('la hoja de mover hace scroll cuando hay muchos capítulos',
        (tester) async {
      final api = _ApiMuchosCapitulos();
      await tester.pumpWidget(_app(_portadaCapitulo, api));
      await _asentar(tester);

      await tester.longPress(find.text('Capítulo 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mover a otro capítulo'));
      await tester.pumpAndSettle();

      final ultimo = find.text('30 · Capítulo número 30');
      await tester.scrollUntilVisible(ultimo, 200,
          scrollable: find.descendant(
              of: find.byType(BottomSheet), matching: find.byType(Scrollable)));
      await tester.tap(ultimo);
      await tester.pumpAndSettle();

      expect(api.movidas, {'c1': 130});
    });

    testWidgets('la portada del libro lista sus capítulos con número y sello',
        (tester) async {
      await tester.pumpWidget(_app(const GLibroScreen(libro: _libro), ApiFalsaConVarias()));
      await _asentar(tester);

      expect(find.text('Mi libro de prueba'), findsOneWidget);
      expect(find.text('3 capítulos'), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
      expect(find.text('XIV Primero la promesa'), findsOneWidget);
      final sellos = tester.widgetList<GStamp>(find.byType(GStamp)).toList();
      expect(sellos.map((s) => (s.label, s.filled)),
          [('Listo', true), ('En curso', false), ('Vacío', false)]);
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

    testWidgets(
        'seleccionar dentro de "Escribir yo" ofrece "Preguntar a la IA", sin '
        'poder usarlo como sugerencia', (tester) async {
      await tester
          .pumpWidget(_app(const GReviewerScreen(reviewId: 'x'), ApiFalsa()));
      await _asentar(tester);

      await _pulsar(tester, find.text('Escribir yo'));
      await tester.enterText(find.byType(EditableText), 'Mi versión de la frase');
      await tester.pump();
      expect(find.text('Preguntar a la IA'), findsNothing,
          reason: 'escribir sin seleccionar no saca el botón');

      final editor = tester.widget<EditableText>(find.byType(EditableText)).controller;
      editor.selection = const TextSelection(baseOffset: 3, extentOffset: 10); // "versión"
      await tester.pump();
      expect(find.text('Preguntar a la IA'), findsOneWidget);

      await tester.tap(find.text('Preguntar a la IA'));
      await tester.pump();
      expect(find.textContaining('Sobre: "versión"'), findsOneWidget);

      await escribirEnChat(tester, '¿Mejor así?');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Respuesta sobre la selección'), findsOneWidget);
      expect(find.textContaining('USAR COMO SUGERENCIA'), findsNothing,
          reason: 'lo escrito a mano no existe en el original: no se puede anclar');

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('cambiar de opción con texto seleccionado quita el botón',
        (tester) async {
      await tester
          .pumpWidget(_app(const GReviewerScreen(reviewId: 'x'), ApiFalsa()));
      await _asentar(tester);

      await _pulsar(tester, find.text('Escribir yo'));
      await tester.enterText(find.byType(EditableText), 'Mi versión de la frase');
      tester.widget<EditableText>(find.byType(EditableText)).controller.selection =
          const TextSelection(baseOffset: 3, extentOffset: 10);
      await tester.pump();
      expect(find.text('Preguntar a la IA'), findsOneWidget);

      await _pulsar(tester, find.text('Aceptar propuesta'));
      await tester.pump();
      expect(find.text('Preguntar a la IA'), findsNothing,
          reason: 'el editor ya no está: su selección tampoco');

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
        'arrastrar tras la pulsación larga selecciona y ofrece "Preguntar a la IA"',
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
      expect(find.text('Preguntar a la IA'), findsOneWidget,
          reason: 'el fragmento arrastrado ofrece el mismo botón que Original/Vista previa');
      expect(find.textContaining('Sobre:'), findsNothing,
          reason: 'el panel no se abre solo, hay que tocar el botón');

      await tester.tap(find.text('Preguntar a la IA'));
      await tester.pump();
      expect(find.textContaining('Sobre:'), findsOneWidget,
          reason: 'tocar el botón abre el panel con el fragmento como contexto');

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
      await tester.pump();

      expect(find.text('Preguntar a la IA'), findsOneWidget,
          reason: 'seleccionar ya en modo edición muestra el mismo botón flotante');

      await tester.tap(find.text('Preguntar a la IA'));
      await tester.pump();
      expect(find.textContaining('Sobre:'), findsOneWidget);

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

  group('finalizar', () {
    // La burbuja de la IA no para de animarse: sin pumpAndSettle, y un
    // frame más para que el menú dé por terminada su animación de entrada.
    Future<void> abrirMenu(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }

    testWidgets('un capítulo suelto se marca como finalizado y se reabre desde ⋯',
        (tester) async {
      final api = ApiFalsa(_documento());
      await tester.pumpWidget(_app(const GReviewerScreen(reviewId: 'doc'), api));
      await _asentar(tester);

      await abrirMenu(tester);
      await tester.tap(find.text('Marcar como finalizado'));
      await tester.pump(const Duration(seconds: 1)); // la burbuja IA no para de animarse: sin pumpAndSettle
      expect(api.finalizadas, {'doc': true});

      await abrirMenu(tester);
      expect(find.text('Marcar como finalizado'), findsNothing);
      await tester.tap(find.text('Reabrir capítulo'));
      await tester.pump(const Duration(seconds: 1)); // la burbuja IA no para de animarse: sin pumpAndSettle
      expect(api.finalizadas, {'doc': false});

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('con sugerencias no hay opción de finalizar: ya lo dicen ellas',
        (tester) async {
      await tester.pumpWidget(_app(const GReviewerScreen(reviewId: 'x'), ApiFalsa()));
      await _asentar(tester);

      await abrirMenu(tester);
      expect(find.text('Marcar como finalizado'), findsNothing);
      expect(find.text('Reabrir capítulo'), findsNothing);
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

      await escribirEnChat(tester, '¿Qué te parece?');
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
