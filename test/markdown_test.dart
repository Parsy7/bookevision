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
      // Si se quedan los \r\n, el capítulo no se parte en párrafos.
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
    test('un bloque editable por párrafo, con sus offsets', () {
      final piezas = buildReaderPieces(_documento());

      expect(piezas.length, 4);
      expect(piezas.every((p) => p is ProsePiece), isTrue,
          reason: 'sin sugerencias no hay tarjetas ni marcadores');

      for (final p in piezas.cast<ProsePiece>()) {
        expect(_md.substring(p.start, p.end), p.text,
            reason: 'los offsets tienen que apuntar al texto de verdad');
      }
      expect((piezas[2] as ProsePiece).text, 'Párrafo dos del capítulo.');
    });

    test('un .md con saltos duros también se parte', () {
      final piezas = buildReaderPieces(
          _documento('Verso uno.\nVerso dos.\nVerso tres.'));

      expect(piezas.length, 3,
          reason: 'sin líneas en blanco, se parte por salto simple');
    });

    test('editar un párrafo no toca a los demás', () async {
      final s = ReviewSession(api: ApiFalsa(_documento()));
      await s.load('doc');

      final p = (buildReaderPieces(s.review!)[2]) as ProsePiece;
      s.setManualEdit(p.start, p.end, p.text, 'Párrafo dos CORREGIDO.');

      expect(
        s.currentText(),
        '# La promesa\n\n'
        'Párrafo uno del capítulo.\n\n'
        'Párrafo dos CORREGIDO.\n\n'
        'Párrafo tres del capítulo.',
      );
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
      expect(find.byType(ProseBlock), findsNWidgets(4));
      expect(find.byTooltip('Pendiente siguiente'), findsNothing);
      expect(find.text('Revisar y confirmar'), findsOneWidget,
          reason: 'no hay nada que resolver: se puede confirmar ya');
    });

    testWidgets('la pulsación larga edita solo ese párrafo', (tester) async {
      await abrir(tester);

      final segundo = find.byType(ProseBlock).at(2);
      final caja = tester.getRect(segundo);
      await tester.longPressAt(Offset(caja.left + 30, caja.top + 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(EditableText), findsOneWidget);
      expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text,
          'Párrafo dos del capítulo.',
          reason: 'el campo lleva el párrafo, no el capítulo entero');

      await tester.enterText(find.byType(EditableText), 'Párrafo dos a mano.');
      await tester.tap(find.text('Guardar').last);
      await tester.pump(const Duration(milliseconds: 400));

      final sesion = Provider.of<ReviewSession>(
          tester.element(find.byType(ProseBlock).first),
          listen: false);
      expect(sesion.currentText(), contains('Párrafo dos a mano.'));
      expect(sesion.currentText(), contains('Párrafo uno del capítulo.'));
      expect(sesion.currentText(), contains('Párrafo tres del capítulo.'));

      await tester.pump(const Duration(seconds: 2));
    });
  });
}
