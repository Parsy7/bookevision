import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/services/review_session.dart';
import 'package:bookevision/theme/app_spacing.dart';
import 'package:bookevision/theme/app_theme.dart';
import 'package:bookevision/widgets/prose_block.dart';

/// Bloque más alto que la pantalla del test (800x600), como los del capítulo.
final String _texto = List.filled(
  40,
  'La jaula seguía abierta y nadie en la casa se atrevía a decirlo en voz alta.',
).join(' ');

/// El lector de verdad: un único scroll enorme con el bloque dentro. Es esa
/// combinación la que hacía saltar la vista al empezar a editar.
Widget _lector(ScrollController controller) {
  return ChangeNotifierProvider<ReviewSession>(
    create: (_) => ReviewSession(),
    child: MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            children: [
              ProseBlock(text: _texto, start: 0, end: _texto.length),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    ),
  );
}

final Finder _prosa = find.descendant(
  of: find.byType(ProseBlock),
  matching: find.byType(Text),
);

Future<void> _mantenerPulsado(WidgetTester tester, Offset punto) async {
  await tester.longPressAt(punto);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Sin parpadeo de cursor no quedan frames pendientes en el test.
    EditableText.debugDeterministicCursor = true;
  });

  tearDown(() {
    EditableText.debugDeterministicCursor = false;
  });

  testWidgets('el texto no se recompone al pasar a edición', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(_lector(controller));

    final antes = tester.getRect(_prosa);
    await _mantenerPulsado(tester, antes.topLeft + const Offset(30, 40));

    final campo = find.byType(EditableText);
    expect(campo, findsOneWidget);
    final despues = tester.getRect(campo);

    expect(despues.top, closeTo(antes.top, 0.5),
        reason: 'el bloque no puede moverse de sitio');
    expect(despues.left, closeTo(antes.left, 0.5),
        reason: 'el bloque no puede sangrarse al editar');
    expect(despues.height, closeTo(antes.height, 1),
        reason: 'misma altura = mismas líneas = no ha roto línea distinto');

    controller.dispose();
  });

  testWidgets('el cursor cae donde se ha pulsado, no al final', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(_lector(controller));

    final prosa = tester.getRect(_prosa);
    final punto = prosa.topLeft + const Offset(120, 100);
    await _mantenerPulsado(tester, punto);

    final estado = tester.state<EditableTextState>(find.byType(EditableText));
    final seleccion = estado.textEditingValue.selection;

    expect(seleccion.isCollapsed, isTrue);
    expect(seleccion.baseOffset, greaterThan(0));
    expect(seleccion.baseOffset, lessThan(_texto.length),
        reason: 'el cursor al final del bloque era justo el bug');

    final render = estado.renderEditable;
    final cursor = render.getLocalRectForCaret(seleccion.extent);
    final global = render.localToGlobal(cursor.topLeft);

    expect(punto.dy, greaterThanOrEqualTo(global.dy - 1));
    expect(punto.dy, lessThanOrEqualTo(global.dy + cursor.height + 1),
        reason: 'el cursor debe quedar en la línea pulsada');
    expect(global.dx, closeTo(punto.dx, 25),
        reason: 'y en el carácter pulsado, no al principio de la línea');

    controller.dispose();
  });

  testWidgets('el lector no se desplaza cuando se abre el teclado',
      (tester) async {
    final controller = ScrollController();
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_lector(controller));

    expect(controller.offset, 0);
    final prosa = tester.getRect(_prosa);
    expect(prosa.height, greaterThan(600),
        reason: 'el bloque debe ser más alto que la pantalla, como en el libro');

    await _mantenerPulsado(tester, prosa.topLeft + const Offset(30, 60));
    expect(find.byType(EditableText), findsOneWidget);

    // El teclado sube: es aquí donde `EditableText` revela el cursor y, si el
    // cursor estuviera al final de un bloque tan largo, se llevaría el lector
    // por delante.
    tester.view.viewInsets =
        FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.offset, lessThan(1),
        reason: 'el punto de lectura no puede moverse al empezar a editar');

    controller.dispose();
  });
}
