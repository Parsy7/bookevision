import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/galerada/escritorio/g_escritorio.dart';
import 'package:bookevision/galerada/escritorio/g_escritorio_screen.dart';
import 'package:bookevision/galerada/screens/g_libro_list_screen.dart';
import 'package:bookevision/galerada/theme/g_spacing.dart';
import 'package:bookevision/galerada/theme/g_theme.dart';
import 'package:bookevision/galerada/widgets/g_ancho_app.dart';
import 'package:bookevision/galerada/widgets/g_bits.dart';
import 'package:bookevision/galerada/widgets/g_lector.dart';
import 'package:bookevision/models/capitulo.dart';
import 'package:bookevision/models/libro.dart';
import 'package:bookevision/models/review.dart';
import 'package:bookevision/models/review_summary.dart';
import 'package:bookevision/services/api_service.dart';
import 'package:bookevision/services/review_session.dart';
import 'package:bookevision/utils/texto_capitulo.dart';

import 'soporte.dart';

const _libro = Libro(id: 1, title: 'La jaula rota', capitulos: 3);

Review _rev(String id, String titulo, String texto) => Review(
      id: id,
      format: 'la-jaula-rota-review-v4',
      title: titulo,
      chapter: texto,
      suggestions: const [],
    );

/// Un libro con tres capítulos: el 11 con dos revisiones (la más nueva es
/// `r2`), el 12 con una y el 13 vacío.
class _ApiLibro extends ApiFalsa {
  final borradas = <String>[];

  @override
  Future<List<Capitulo>> getCapitulos(int libroId) async => const [
        Capitulo(
            id: 11,
            libroId: 1,
            numero: 11,
            titulo: 'El eco',
            revisiones: 2,
            listas: 1),
        Capitulo(
            id: 12,
            libroId: 1,
            numero: 12,
            titulo: 'Vino amargo',
            revisiones: 1,
            listas: 1),
        Capitulo(id: 13, libroId: 1, numero: 13, titulo: 'La guardia'),
      ];

  @override
  Future<List<ReviewSummary>> getRevisiones(
          {String? libroId, int? capituloId}) async =>
      switch (capituloId) {
        11 => [
            ReviewSummary(
                id: 'r1',
                format: 'f',
                title: 'Borrador base',
                total: 0,
                resolved: 0,
                manual: 0,
                updatedAt: DateTime(2026, 10, 1)),
            ReviewSummary(
                id: 'r2',
                format: 'f',
                title: 'Ajuste de descripciones',
                total: 0,
                resolved: 0,
                manual: 0,
                updatedAt: DateTime(2026, 10, 9)),
          ],
        12 => const [
            ReviewSummary(
                id: 'r3',
                format: 'f',
                title: 'Vino',
                total: 0,
                resolved: 0,
                manual: 0),
          ],
        _ => const [],
      };

  @override
  Future<Review> getRevision(String id) async => switch (id) {
        'r1' => _rev('r1', 'Borrador base', 'Texto del borrador base.'),
        'r2' => _rev('r2', 'Ajuste de descripciones',
            'El viento del norte arreciaba.\n\nElian contemplaba la niebla.'),
        _ => _rev(id, 'Vino', 'Un chapuzón de vino amargo.'),
      };

  @override
  Future<void> deleteRevision(String id) async => borradas.add(id);
}

/// Un chip por su rótulo: el chip lo escribe en mayúsculas.
Finder _chip(String rotulo) => find.widgetWithText(GChip, rotulo.toUpperCase());

/// Pinta el escritorio a [ventana] dentro de la app, como la monta `main`.
Future<void> _abrir(WidgetTester tester,
    {Size ventana = const Size(1400, 900), ApiService? api}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = ventana;
  addTearDown(tester.view.reset);
  // Como si se hubiera abierto con `GEscritorio.abrir`.
  final abiertas = GEscritorio.abiertas as ValueNotifier<int>;
  abiertas.value++;
  addTearDown(() => abiertas.value--);
  await tester.pumpWidget(
    Provider<ApiService>.value(
      value: api ?? _ApiLibro(),
      child: MaterialApp(
        theme: buildGaleradaTheme(),
        builder: (context, child) => GAnchoApp(child: child!),
        home: const GEscritorioScreen(libro: _libro),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    EditableText.debugDeterministicCursor = true;
    GEscritorio.forzarWindows = null;
  });
  tearDown(() {
    EditableText.debugDeterministicCursor = false;
    GEscritorio.forzarWindows = null;
  });

  group('TextoCapitulo', () {
    test('numerales romanos', () {
      expect(TextoCapitulo.romano(1), 'I');
      expect(TextoCapitulo.romano(4), 'IV');
      expect(TextoCapitulo.romano(11), 'XI');
      expect(TextoCapitulo.romano(15), 'XV');
      expect(TextoCapitulo.romano(24), 'XXIV');
      expect(TextoCapitulo.romano(1994), 'MCMXCIV');
      expect(TextoCapitulo.romano(0), '0', reason: 'el cero no tiene numeral');
    });

    test('palabras, párrafos y miles', () {
      expect(TextoCapitulo.palabras('  uno  dos\n\ntres '), 3);
      expect(TextoCapitulo.palabras(''), 0);
      expect(TextoCapitulo.parrafos('a\n\nb\n\n\nc'), 3);
      expect(TextoCapitulo.parrafos('solo uno'), 1);
      expect(TextoCapitulo.miles(3412), '3.412');
      expect(TextoCapitulo.miles(68420), '68.420');
      expect(TextoCapitulo.miles(999), '999');
    });

    test('fechas', () {
      final ahora = DateTime(2026, 10, 10, 12);
      expect(TextoCapitulo.fecha(DateTime(2026, 10, 10, 9, 5), ahora: ahora),
          'Hoy, 09:05');
      expect(TextoCapitulo.fecha(DateTime(2026, 10, 9, 22, 3), ahora: ahora),
          'Ayer, 22:03');
      expect(TextoCapitulo.fecha(DateTime(2026, 10, 1), ahora: ahora), '1 oct');
      expect(TextoCapitulo.fecha(DateTime(2025, 3, 7), ahora: ahora),
          '7 mar 2025');
    });
  });

  group('cuándo hay escritorio', () {
    late bool resultado;

    Future<void> medir(WidgetTester tester, Size ventana,
        {bool windows = false}) async {
      GEscritorio.forzarWindows = windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = ventana;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          resultado = GEscritorio.esEscritorio(context);
          return const SizedBox();
        }),
      ));
    }

    testWidgets('Windows con ventana ancha: sí', (tester) async {
      await medir(tester, const Size(1400, 900), windows: true);
      expect(resultado, isTrue);
    });

    testWidgets('Windows con la ventana estrecha: no', (tester) async {
      await medir(tester, const Size(700, 900), windows: true);
      expect(resultado, isFalse);
    });

    testWidgets('tablet en horizontal: sí', (tester) async {
      await medir(tester, const Size(1280, 800));
      expect(resultado, isTrue);
    });

    testWidgets('tablet en vertical: no', (tester) async {
      await medir(tester, const Size(800, 1280));
      expect(resultado, isFalse);
    });

    testWidgets('el móvil, ni en horizontal: no', (tester) async {
      await medir(tester, const Size(932, 430));
      expect(resultado, isFalse);
    });

    testWidgets('lo mide la ventana, no la columna de la app', (tester) async {
      GEscritorio.forzarWindows = true;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.reset);
      late double anchoMediaQuery;
      await tester.pumpWidget(MaterialApp(
        home: GAnchoApp(
          child: Builder(builder: (context) {
            anchoMediaQuery = MediaQuery.sizeOf(context).width;
            resultado = GEscritorio.esEscritorio(context);
            return const SizedBox();
          }),
        ),
      ));
      expect(anchoMediaQuery, GSpacing.anchoApp);
      expect(resultado, isTrue);
    });
  });

  group('GAnchoApp con el escritorio abierto', () {
    testWidgets('no recorta la ventana mientras hay uno abierto',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(
        home: GAnchoApp(child: SizedBox.expand(key: Key('app'))),
      ));
      expect(tester.getRect(find.byKey(const Key('app'))).width,
          GSpacing.anchoApp);

      (GEscritorio.abiertas as ValueNotifier<int>).value++;
      await tester.pump();
      expect(tester.getRect(find.byKey(const Key('app'))).width, 1400);

      (GEscritorio.abiertas as ValueNotifier<int>).value--;
      await tester.pump();
      expect(tester.getRect(find.byKey(const Key('app'))).width,
          GSpacing.anchoApp);
    });
  });

  group('GEscritorioScreen', () {
    testWidgets('lista los capítulos con su numeral y abre la última revisión',
        (tester) async {
      await _abrir(tester);

      expect(find.text('XI'), findsOneWidget);
      expect(find.text('XII'), findsOneWidget);
      expect(find.text('XIII'), findsOneWidget);
      expect(find.text('El eco'), findsOneWidget);
      // Está abierto el capítulo 11 con su revisión más reciente (r2).
      expect(find.textContaining('El viento del norte arreciaba.'),
          findsOneWidget);
      expect(find.text('XI. El eco'), findsOneWidget);
      expect(find.text('2 PÁRRAFOS · 9 PALABRAS'), findsOneWidget);
      expect(find.text('CAPÍTULOS: 3'), findsOneWidget);
    });

    testWidgets('los botones sin función están apagados', (tester) async {
      await _abrir(tester);

      for (final rotulo in ['Partes', 'Verificar canon']) {
        final chip = tester.widget<GChip>(_chip(rotulo));
        expect(chip.onTap, isNull, reason: '«$rotulo» aún no hace nada');
      }
      // Los que sí funcionan, no.
      for (final rotulo in ['Exportar (.md)', 'Resumir escena', 'Mi perfil']) {
        final chip = tester.widget<GChip>(_chip(rotulo));
        expect(chip.onTap, isNotNull, reason: '«$rotulo» sí funciona');
      }
    });

    testWidgets('elegir otro capítulo cambia el texto', (tester) async {
      await _abrir(tester);

      await tester.tap(find.text('Vino amargo'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.textContaining('chapuzón de vino amargo'), findsOneWidget);
      expect(find.textContaining('El viento del norte'), findsNothing);
      expect(find.text('XII. Vino amargo'), findsOneWidget);
    });

    testWidgets('un capítulo sin revisiones ofrece importar una',
        (tester) async {
      await _abrir(tester);

      await tester.tap(find.text('La guardia'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.textContaining('aún no tiene revisiones'), findsOneWidget);
      expect(find.text('Importar revisión o .md'.toUpperCase()), findsNothing,
          reason: 'es un GButton, que escribe el rótulo tal cual');
      expect(find.text('Importar revisión o .md'), findsOneWidget);
    });

    testWidgets('el reloj enseña las revisiones y se abre otra',
        (tester) async {
      await _abrir(tester);

      await tester.tap(find.byTooltip('Revisiones de «El eco»'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Ajuste de descripciones'), findsOneWidget);
      expect(find.text('Borrador base'), findsOneWidget);
      expect(find.text('EN EL EDITOR'), findsOneWidget);
      // Restaurar y Comparar existen pero apagados (solo en la que no está
      // abierta).
      for (final rotulo in ['Restaurar', 'Comparar']) {
        final chip = tester.widget<GChip>(_chip(rotulo));
        expect(chip.onTap, isNull);
      }

      await tester.tap(find.text('Borrador base'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Texto del borrador base.'), findsOneWidget);

      await tester.tap(find.text('Ver todos los capítulos'));
      await tester.pump();
      expect(find.text('XII'), findsOneWidget);
    });

    testWidgets('Ver original / split pone el original al lado',
        (tester) async {
      await _abrir(tester);
      expect(find.text('ORIGINAL · SOLO LECTURA'), findsNothing);

      await tester.tap(_chip('Ver original / split'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('ORIGINAL · SOLO LECTURA'), findsOneWidget);
      // El texto sale dos veces: el editor y el original.
      expect(find.textContaining('El viento del norte arreciaba.'),
          findsNWidgets(2));

      await tester.tap(find.byTooltip('Cerrar el original'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('ORIGINAL · SOLO LECTURA'), findsNothing);
    });

    testWidgets('F11 esconde los paneles y vuelve a enseñarlos',
        (tester) async {
      await _abrir(tester);
      expect(find.text('CAPÍTULOS: 3'), findsOneWidget);
      expect(find.text('Asistente IA'.toUpperCase()), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.f11);
      await tester.pump();
      expect(find.text('CAPÍTULOS: 3'), findsNothing);
      expect(find.text('XII'), findsNothing);
      expect(find.text('Asistente IA'.toUpperCase()), findsNothing);
      expect(
          find.textContaining('El viento del norte arreciaba.'), findsOneWidget,
          reason: 'el texto sigue ahí');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('XII'), findsOneWidget);
    });

    testWidgets('el asistente acoplado contesta sin burbuja flotante',
        (tester) async {
      await _abrir(tester);

      await tester.tap(_chip('Resumir escena'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Respuesta de mentira'), findsOneWidget);
      expect(find.byTooltip('Ocultar el asistente'), findsOneWidget);
    });

    testWidgets('en una ventana justa el asistente espera y se puede abrir',
        (tester) async {
      await _abrir(tester, ventana: const Size(1000, 700));
      expect(find.text('ASISTENTE IA'), findsNothing);

      await tester.tap(find.byTooltip('Mostrar el asistente'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('ASISTENTE IA'), findsOneWidget);

      await tester.tap(find.byTooltip('Ocultar el asistente'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('ASISTENTE IA'), findsNothing);
    });

    testWidgets(
        'con un borrador sin guardar pregunta antes de cambiar de capítulo',
        (tester) async {
      await _abrir(tester);
      final sesion = Provider.of<ReviewSession>(
          tester.element(find.byType(GLectorCuerpo)),
          listen: false);
      sesion.sinGuardar = true;
      await tester.pump();

      await tester.tap(find.text('Vino amargo'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Seguir editando'), findsOneWidget);

      await tester.tap(find.text('Seguir editando'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          find.textContaining('El viento del norte arreciaba.'), findsOneWidget,
          reason: 'sigue en el mismo capítulo');
    });
  });

  group('abrir un libro', () {
    testWidgets(
        'en Windows ancho, lleva al escritorio; en estrecho, a la lista de capítulos',
        (tester) async {
      Future<void> pintar(Size ventana, {required bool windows}) async {
        GEscritorio.forzarWindows = windows;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = ventana;
        await tester.pumpWidget(
          Provider<ApiService>.value(
            value: _ApiConLibros(),
            child: MaterialApp(
              theme: buildGaleradaTheme(),
              builder: (context, child) => GAnchoApp(child: child!),
              home: const GLibroListScreen(),
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      addTearDown(tester.view.reset);
      await pintar(const Size(1400, 900), windows: true);
      await tester.tap(find.text('La jaula rota'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byType(GEscritorioScreen), findsOneWidget);
      expect(GEscritorio.abiertas.value, 1);

      // Volver cierra el escritorio y devuelve la columna estrecha.
      await tester.tap(find.widgetWithText(InkWell, 'BIBLIOTECA').first);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byType(GEscritorioScreen), findsNothing);
      expect(GEscritorio.abiertas.value, 0);
    });
  });
}

class _ApiConLibros extends _ApiLibro {
  @override
  Future<List<Libro>> getLibros() async => const [_libro];
}
