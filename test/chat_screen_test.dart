import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/galerada/screens/g_chat_screen.dart';
import 'package:bookevision/galerada/theme/g_theme.dart';
import 'package:bookevision/services/api_service.dart';

import 'soporte.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> abrir(WidgetTester tester, ApiService api) async {
    await tester.pumpWidget(Provider<ApiService>.value(
      value: api,
      child: MaterialApp(theme: buildGaleradaTheme(), home: const GChatScreen()),
    ));
    await tester.pump();
  }

  testWidgets('el campo de escritura no se come la pantalla',
      (tester) async {
    await abrir(tester, ApiFalsa());

    final campo = tester.getRect(find.byType(TextField));
    expect(campo.height, lessThan(150),
        reason: 'el campo de entrada debe caber en unas pocas líneas, no '
            'ocupar casi toda la pantalla');
  });

  testWidgets('enviar un mensaje muestra la respuesta de la IA',
      (tester) async {
    await abrir(tester, ApiFalsa());

    await tester.enterText(find.byType(TextField), 'Hola');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Hola'), findsOneWidget);
    expect(find.text('Respuesta de mentira'), findsOneWidget);
  });
}
