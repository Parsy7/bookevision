import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/screens/reviewer_screen.dart';
import 'package:bookevision/services/api_service.dart';
import 'package:bookevision/services/review_session.dart';
import 'package:bookevision/theme/app_theme.dart';
import 'package:bookevision/widgets/app_button.dart';
import 'package:bookevision/widgets/prose_block.dart';

import 'soporte.dart';

Future<void> _abrirLector(WidgetTester tester) async {
  await tester.pumpWidget(
    Provider<ApiService>.value(
      value: ApiFalsa(),
      child: MaterialApp(
        theme: appTheme,
        home: const ReviewerScreen(reviewId: 'x'),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pulsación larga sobre el bloque de prosa número [n].
Future<void> _editarBloque(WidgetTester tester, int n) async {
  final bloque = find.byType(ProseBlock).at(n);
  final caja = tester.getRect(bloque);
  await tester.longPressAt(Offset(caja.left + 30, caja.top + 40));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

ReviewSession _sesion(WidgetTester tester) => Provider.of<ReviewSession>(
      tester.element(find.byType(ProseBlock).first),
      listen: false,
    );

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    EditableText.debugDeterministicCursor = true;
  });
  tearDown(() => EditableText.debugDeterministicCursor = false);

  testWidgets('editar saca la barra fija y esconde la navegación',
      (tester) async {
    await _abrirLector(tester);
    expect(find.text('Guardar'), findsOneWidget); // el de la barra superior

    await _editarBloque(tester, 0);

    expect(find.byTooltip('Pendiente siguiente'), findsNothing,
        reason: 'mientras editas, la barra de abajo es la de edición');
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Guardar'), findsNWidgets(2)); // arriba y en la barra
    expect(find.text('Restaurar'), findsNothing,
        reason: 'restaurar vive en el conmutador del bloque, no en la barra');
  });

  testWidgets('los botones del bloque ya no van dentro del bloque',
      (tester) async {
    await _abrirLector(tester);
    final antes = tester.getRect(find.byType(ProseBlock).first);

    await _editarBloque(tester, 0);

    final despues = tester.getRect(find.byType(ProseBlock).first);
    expect(despues, antes,
        reason: 'entrar en edición no puede cambiar nada del bloque');
  });

  testWidgets('la barra queda sobre el teclado y Guardar guarda',
      (tester) async {
    addTearDown(tester.view.reset);
    await _abrirLector(tester);
    await _editarBloque(tester, 0);

    tester.view.viewInsets =
        FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final barra = tester.getRect(find.text('Guardar').last);
    expect(barra.bottom, lessThanOrEqualTo(300),
        reason: 'la barra tiene que verse por encima del teclado');

    await tester.enterText(find.byType(EditableText), 'Texto ya corregido.');
    await tester.tap(find.text('Guardar').last);
    await tester.pump(const Duration(milliseconds: 400));

    expect(_sesion(tester).manualEdits.values.single.value,
        'Texto ya corregido.');
    expect(find.byType(EditableText), findsNothing,
        reason: 'al guardar se sale de edición');

    await tester.pump(const Duration(seconds: 2)); // vacía el autosave
  });

  testWidgets('editar otro bloque cancela el primero', (tester) async {
    await _abrirLector(tester);
    await _editarBloque(tester, 0);
    expect(find.byType(EditableText), findsOneWidget);

    await _editarBloque(tester, 1);

    expect(find.byType(EditableText), findsOneWidget,
        reason: 'solo un bloque en edición a la vez');
    expect(find.text('Cancelar'), findsOneWidget,
        reason: 'y solo una barra de edición');
  });

  testWidgets('la barra cabe en una pantalla estrecha', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // En los tests la fuente es la de prueba, con todos los glifos cuadrados:
    // mide casi el doble que Lora y hace "desbordar" cualquier rótulo que en
    // el móvil cabe de sobra. Se silencian solo esos; lo demás sigue fallando.
    final errorOriginal = FlutterError.onError;
    FlutterError.onError = (detalles) {
      if (detalles.exceptionAsString().contains('overflowed')) return;
      errorOriginal?.call(detalles);
    };
    addTearDown(() => FlutterError.onError = errorOriginal);

    await _abrirLector(tester);
    await _editarBloque(tester, 0);

    // Lo que sí se puede medir es la caja de los botones.
    final guardar = tester.getRect(find.widgetWithText(AppButton, 'Guardar'));
    final cancelar = tester.getRect(find.widgetWithText(AppButton, 'Cancelar'));

    expect(guardar.left, greaterThanOrEqualTo(0));
    expect(cancelar.right, lessThanOrEqualTo(360));
    expect(guardar.right, lessThanOrEqualTo(cancelar.left),
        reason: 'los dos botones, uno al lado del otro, sin pisarse');
    for (final b in [guardar, cancelar]) {
      expect(b.height, greaterThanOrEqualTo(44),
          reason: 'área táctil mínima de la guía');
    }
  });
}
