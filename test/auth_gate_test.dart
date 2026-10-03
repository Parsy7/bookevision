import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/galerada/screens/g_auth_gate.dart';
import 'package:bookevision/galerada/screens/g_login_screen.dart';
import 'package:bookevision/galerada/theme/g_theme.dart';
import 'package:bookevision/models/libro.dart';
import 'package:bookevision/services/api_service.dart';

import 'soporte.dart';

const _canal = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

class _ApiSinLibros extends ApiFalsa {
  @override
  Future<List<Libro>> getLibros() async => const [];
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('tras un login correcto pasa a «Mis libros» sin errores', (tester) async {
    String? token; // sin sesión al abrir
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, (call) async => call.method == 'read' ? token : null);
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null));

    await tester.pumpWidget(Provider<ApiService>.value(
      value: _ApiSinLibros(),
      child: MaterialApp(theme: buildGaleradaTheme(), home: const GAuthGate()),
    ));
    await tester.pump();
    expect(find.byType(GLoginScreen), findsOneWidget);

    // Lo que hace la pantalla de login al entrar bien: guarda el token y avisa.
    token = 'token-de-prueba';
    tester.widget<GLoginScreen>(find.byType(GLoginScreen)).onAuthenticated();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(tester.takeException(), isNull,
        reason: 'setState no puede recibir una función que devuelva un Future');
    expect(find.byType(GLoginScreen), findsNothing);
    expect(find.text('Mis libros'), findsOneWidget);
  });
}
