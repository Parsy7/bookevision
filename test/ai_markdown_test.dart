import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:bookevision/galerada/theme/g_theme.dart';
import 'package:bookevision/galerada/widgets/g_ai_markdown.dart';

/// Tal cual llegó una respuesta real de Gemini.
const _respuesta = '''Aquí tienes una reescritura, con **tu idea** incluida:

### Opción 1 (Directa y más fluida)
> Solo entonces, cuando la urgencia aflojó, reparó en un detalle.
>
> El maletín reposaba cerrado sobre la mesa.

---

- una *cosa*
2. otra

¿Qué te parece?''';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('el texto plano no lleva marcas de Markdown', () {
    final plano = GAiMarkdown.textoPlano(_respuesta);
    expect(plano, isNot(contains('**')));
    expect(plano, isNot(contains('###')));
    expect(plano, isNot(contains('>')));
    expect(plano, isNot(contains('---')));
    expect(plano, contains('con tu idea incluida'));
    expect(plano, contains('Opción 1 (Directa y más fluida)'));
    expect(plano, contains('• una cosa'));
    expect(plano, contains('2. otra'));
  });

  testWidgets('se pinta sin símbolos, con título, cita y negrita', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildGaleradaTheme(),
      home: const Scaffold(body: SingleChildScrollView(child: GAiMarkdown(_respuesta))),
    ));

    expect(find.textContaining('###'), findsNothing);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('> '), findsNothing);
    expect(find.text('Opción 1 (Directa y más fluida)'), findsOneWidget);

    // Los dos párrafos de la cita van juntos en un solo bloque.
    expect(
      find.text('Solo entonces, cuando la urgencia aflojó, reparó en un detalle.\n\n'
          'El maletín reposaba cerrado sobre la mesa.'),
      findsOneWidget,
    );

    final parrafo = tester.widget<Text>(find.textContaining('tu idea'));
    final negrita = parrafo.textSpan!.visitChildren((span) {
      return !(span is TextSpan && span.text == 'tu idea' && span.style?.fontWeight == FontWeight.w700);
    });
    expect(negrita, isFalse, reason: 'visitChildren corta (devuelve false) al encontrar la negrita');
  });
}
