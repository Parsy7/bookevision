import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/galerada/theme/g_theme.dart';
import 'package:bookevision/galerada/widgets/g_ai_assistant_overlay.dart';
import 'package:bookevision/services/api_service.dart';
import 'package:bookevision/services/g_ai_assistant_controller.dart';

import 'soporte.dart';

class _ApiLenta extends ApiFalsa {
  @override
  Future<String> chat(String mensaje) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 'Tras pensarlo';
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> abrir(WidgetTester tester, GAiAssistantController controller, ApiService api) async {
    await tester.pumpWidget(Provider<ApiService>.value(
      value: api,
      child: MaterialApp(
        theme: buildGaleradaTheme(),
        home: Scaffold(
          body: Stack(children: [const SizedBox.expand(), GAiAssistantOverlay(controller: controller)]),
        ),
      ),
    ));
    await tester.pump();
  }

  group('GAiAssistantController', () {
    test('empieza oculto y abre en modo panel', () {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x');
      expect(c.mode, GAiAssistantMode.hidden);
      c.abrir();
      expect(c.mode, GAiAssistantMode.panel);
    });

    test('minimizar vuelve a burbuja sin perder los mensajes', () async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x');
      c.abrir();
      await c.enviar('Hola');
      expect(c.messages.length, 2);
      c.minimizar();
      expect(c.mode, GAiAssistantMode.bubble);
      expect(c.messages.length, 2, reason: 'minimizar no borra la conversación');
    });

    test('marca "hay nuevo" si la respuesta llega estando minimizado', () async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x');
      c.abrir();
      c.minimizar();
      await c.enviar('¿Sigues ahí?');
      expect(c.hayNuevo, isTrue);
      c.abrir();
      expect(c.hayNuevo, isFalse, reason: 'abrir el panel limpia el aviso');
    });

    test('con contexto de selección, pregunta usa preguntarSeleccion y trae seed', () async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x');
      c.abrir(seleccion: 'un fragmento del capítulo');
      await c.enviar('¿Por qué?');
      final respuesta = c.messages.last;
      expect(respuesta.deUsuario, isFalse);
      expect(respuesta.texto, 'Respuesta sobre la selección');
      expect(respuesta.seed, isNotNull);
      expect(respuesta.seed!['selection'], 'un fragmento del capítulo');
    });

    test('sin selección, chat libre no trae seed', () async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x');
      c.abrir();
      await c.enviar('Hola');
      expect(c.messages.last.seed, isNull);
    });

    test('resize se queda dentro de los límites', () {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x');
      c.resize(-10000);
      expect(c.panelHeight, GAiAssistantController.minHeight);
      c.resize(10000);
      expect(c.panelHeight, GAiAssistantController.maxHeight);
    });

    test('convertirEnSugerencia llama a la API solo cuando hay seed', () async {
      final api = ApiFalsa();
      final c = GAiAssistantController(api: api, revisionId: 'x');
      c.abrir();
      await c.enviar('Hola'); // sin seed
      expect(await c.convertirEnSugerencia(c.messages.last), isFalse);
      expect(api.sugerenciasGeneradas, 0);

      c.abrir(seleccion: 'fragmento');
      await c.enviar('¿Y si...?'); // con seed
      expect(await c.convertirEnSugerencia(c.messages.last), isTrue);
      expect(api.sugerenciasGeneradas, 1);
    });
  });

  group('GAiAssistantOverlay', () {
    testWidgets('oculto no pinta nada', (tester) async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x');
      await abrir(tester, c, ApiFalsa());
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('la burbuja abre el panel, y el campo no se come la pantalla', (tester) async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x')
        ..mode = GAiAssistantMode.bubble;
      await abrir(tester, c, ApiFalsa());

      await tester.tap(find.byIcon(Icons.auto_awesome));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      final campo = tester.getRect(find.byType(TextField));
      expect(campo.height, lessThan(150),
          reason: 'el campo de entrada debe caber en unas pocas líneas, no '
              'ocupar casi toda la pantalla');
    });

    testWidgets('enviar un mensaje muestra la respuesta de la IA', (tester) async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x')..abrir();
      await abrir(tester, c, ApiFalsa());

      await tester.enterText(find.byType(TextField), 'Hola');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Hola'), findsOneWidget);
      expect(find.text('Respuesta de mentira'), findsOneWidget);
    });

    testWidgets('mientras espera la respuesta no se ve el texto todavía',
        (tester) async {
      final api = _ApiLenta();
      final c = GAiAssistantController(api: api, revisionId: 'x')..abrir();
      await abrir(tester, c, api);

      await tester.enterText(find.byType(TextField), 'Hola');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      expect(c.enviando, isTrue);
      expect(find.text('Tras pensarlo'), findsNothing);

      await tester.pump(const Duration(milliseconds: 600));

      expect(c.enviando, isFalse);
      expect(find.text('Tras pensarlo'), findsOneWidget);
    });

    testWidgets('minimizar vuelve a mostrar la burbuja', (tester) async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x')..abrir();
      await abrir(tester, c, ApiFalsa());

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(c.mode, GAiAssistantMode.bubble);
    });
  });
}
