import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:bookevision/galerada/theme/g_theme.dart';
import 'package:bookevision/galerada/widgets/g_prose.dart';

/// El botón "Preguntar a la IA" depende de que `GProseFlow` avise de cada
/// cambio de selección por `onSelectionChanged` — probado antes que dependía
/// de `contextMenuBuilder`, que Flutter no reinvoca en cada gesto y dejaba el
/// botón sin aparecer buena parte de las veces. Esto comprueba el contrato
/// directamente sobre `SelectionArea`, sin simular gestos táctiles reales
/// (frágil y no es lo que se quiere ejercitar aquí).
void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('un cambio de selección no vacío llama a onSeleccionCambia',
      (tester) async {
    String? recibido;
    var vacioLlamado = false;

    await tester.pumpWidget(MaterialApp(
      theme: buildGaleradaTheme(),
      home: Scaffold(
        body: GProseFlow(
          'Un párrafo cualquiera.',
          onSeleccionCambia: (s) => recibido = s,
          onSeleccionVacia: () => vacioLlamado = true,
        ),
      ),
    ));

    final area = tester.widget<SelectionArea>(find.byType(SelectionArea));
    area.onSelectionChanged!(const SelectedContent(plainText: '  un fragmento  '));

    expect(recibido, 'un fragmento');
    expect(vacioLlamado, isFalse);
  });

  testWidgets('una selección que queda vacía llama a onSeleccionVacia',
      (tester) async {
    var vacioLlamado = false;

    await tester.pumpWidget(MaterialApp(
      theme: buildGaleradaTheme(),
      home: Scaffold(
        body: GProseFlow(
          'Un párrafo cualquiera.',
          onSeleccionCambia: (_) {},
          onSeleccionVacia: () => vacioLlamado = true,
        ),
      ),
    ));

    final area = tester.widget<SelectionArea>(find.byType(SelectionArea));
    area.onSelectionChanged!(null);

    expect(vacioLlamado, isTrue);
  });

  testWidgets('sin onSeleccionCambia el texto no es seleccionable',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildGaleradaTheme(),
      home: const Scaffold(body: GProseFlow('Un párrafo cualquiera.')),
    ));

    expect(find.byType(SelectionArea), findsNothing);
  });
}
