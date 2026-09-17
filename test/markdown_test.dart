import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/models/review.dart';
import 'package:bookevision/screens/reviewer_screen.dart';
import 'package:bookevision/services/api_service.dart';
import 'package:bookevision/services/review_session.dart';
import 'package:bookevision/theme/app_theme.dart';
import 'package:bookevision/utils/import_md.dart';
import 'package:bookevision/utils/reader_layout.dart';
import 'package:bookevision/widgets/progress_header.dart';
import 'package:bookevision/widgets/prose_block.dart';
import 'package:bookevision/widgets/suggestion_card.dart';

import 'soporte.dart';

const _md = '# La promesa\n\n'
    'Párrafo uno del capítulo.\n\n'
    'Párrafo dos del capítulo.\n\n'
    'Párrafo tres del capítulo.';

/// El mismo capítulo con los dos últimos párrafos quitados de una vez: lo que
/// no se podía hacer cuando cada párrafo era un bloque suelto.
const _recortado = '# La promesa\n\nPárrafo uno del capítulo.';

Review _documento([String texto = _md]) => Review(
      id: 'doc',
      format: 'la-jaula-rota-review-v4',
      title: 'La promesa',
      chapter: texto,
      suggestions: const [],
    );

void main() {
  group('conversión del .md', () {
    test('el título sale del primer encabezado', () {
      expect(ImportMd.titulo('capitulo-x.md', _md), 'La promesa');
    });

    test('sin encabezado, del nombre del archivo', () {
      expect(ImportMd.titulo('La jaula rota - cap 3.md', 'Texto suelto.'),
          'La jaula rota - cap 3');
    });

    test('los saltos de Windows se normalizan', () {
      final r = ImportMd.revision('x.md', 'Uno.\r\n\r\nDos.\r\n');
      expect(r['chapter'], 'Uno.\n\nDos.');
    });

    test('un encabezado kilométrico no revienta la columna', () {
      final r = ImportMd.revision('x.md', '# ${'á' * 400}\n\nTexto.');
      expect((r['title'] as String).runes.length, 255);
    });

    test('entra como revisión sin sugerencias y sin id', () {
      final r = ImportMd.revision('capitulo-x.md', _md);
      expect(r['suggestions'], isEmpty);
      expect(r.containsKey('id'), isFalse,
          reason: 'la API deriva el id, así se puede cargar dos veces');
      expect(r['chapter'], _md,
          reason: 'el contenido entra tal cual, encabezado incluido');
    });
  });

  group('lector de un capítulo suelto', () {
    test('un solo bloque con el capítulo entero', () {
      final piezas = buildReaderPieces(_documento());

      expect(piezas.length, 1,
          reason: 'de punta a punta: hay que poder quitar varios párrafos de '
              'una vez, no uno por uno');
      final p = piezas.single as ProsePiece;
      expect(p.text, _md);
      expect(p.start, 0);
      expect(p.end, _md.length);
    });

    test('la edición se lleva por delante párrafos enteros', () async {
      final s = ReviewSession(api: ApiFalsa(_documento()));
      await s.load('doc');

      final p = buildReaderPieces(s.review!).single as ProsePiece;
      s.setManualEdit(p.start, p.end, p.text, _recortado);

      expect(s.currentText(), _recortado,
          reason: 'separadores incluidos, sin huecos sueltos');
      s.dispose();
    });

    test('sin sugerencias no hay nada pendiente', () async {
      final s = ReviewSession(api: ApiFalsa(_documento()));
      await s.load('doc');

      expect(s.allResolved, isTrue);
      expect(s.counts().total, 0);
      s.dispose();
    });
  });

  group('pantalla del capítulo suelto', () {
    setUp(() {
      GoogleFonts.config.allowRuntimeFetching = false;
      EditableText.debugDeterministicCursor = true;
    });
    tearDown(() => EditableText.debugDeterministicCursor = false);

    Future<void> abrir(WidgetTester tester) async {
      await tester.pumpWidget(
        Provider<ApiService>.value(
          value: ApiFalsa(_documento()),
          child: MaterialApp(
            theme: appTheme,
            home: const ReviewerScreen(reviewId: 'doc'),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('ni tarjetas ni barra de progreso', (tester) async {
      await abrir(tester);

      expect(find.byType(SuggestionCard), findsNothing);
      expect(find.byType(ProgressHeader), findsNothing);
      expect(find.byType(ProseBlock), findsOneWidget);
      expect(find.byTooltip('Pendiente siguiente'), findsNothing);
      expect(find.text('Revisar y confirmar'), findsOneWidget,
          reason: 'no hay nada que resolver: se puede confirmar ya');
    });

    testWidgets('la pulsación larga deja editable el capítulo entero',
        (tester) async {
      await abrir(tester);

      final caja = tester.getRect(find.byType(ProseBlock));
      await tester.longPressAt(Offset(caja.left + 30, caja.top + 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final campo = tester.widget<EditableText>(find.byType(EditableText));
      expect(campo.controller.text, _md,
          reason: 'el campo lleva todo el capítulo, no solo el párrafo tocado');

      await tester.enterText(find.byType(EditableText), _recortado);
      await tester.tap(find.text('Guardar').last);
      await tester.pump(const Duration(milliseconds: 400));

      final sesion = Provider.of<ReviewSession>(
          tester.element(find.byType(ProseBlock)),
          listen: false);
      expect(sesion.currentText(), _recortado);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('el cursor sigue cayendo donde se pulsa', (tester) async {
      await abrir(tester);

      final caja = tester.getRect(find.byType(ProseBlock));
      // Tercera línea del bloque, no el principio.
      final punto = Offset(caja.left + 80, caja.top + 70);
      await tester.longPressAt(punto);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final estado =
          tester.state<EditableTextState>(find.byType(EditableText));
      final seleccion = estado.textEditingValue.selection;
      expect(seleccion.baseOffset, greaterThan(0));
      expect(seleccion.baseOffset, lessThan(_md.length),
          reason: 'ni al principio ni al final del capítulo');

      final cursor = estado.renderEditable
          .getLocalRectForCaret(seleccion.extent);
      final global = estado.renderEditable.localToGlobal(cursor.topLeft);
      expect(punto.dy, greaterThanOrEqualTo(global.dy - 1));
      expect(punto.dy, lessThanOrEqualTo(global.dy + cursor.height + 1));

      await tester.pump(const Duration(seconds: 2));
    });
  });
}
