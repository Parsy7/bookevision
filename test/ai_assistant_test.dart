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
  Future<String> chat(
    String mensaje, {
    required String revisionId,
    required String capitulo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 'Tras pensarlo';
  }
}

/// Se queda con lo que le llegó, para comprobar que el chat libre y las
/// preguntas sobre selección de verdad mandan el capítulo como contexto
/// (vital: sin esto la IA no sabe de qué capítulo se habla).
class _ApiQueRecuerdaElContexto extends ApiFalsa {
  String? ultimoRevisionIdEnChat;
  String? ultimoCapituloEnChat;
  String? ultimoRevisionIdEnPreguntarSeleccion;
  String? ultimoCapituloEnPreguntarSeleccion;

  @override
  Future<String> chat(
    String mensaje, {
    required String revisionId,
    required String capitulo,
  }) async {
    ultimoRevisionIdEnChat = revisionId;
    ultimoCapituloEnChat = capitulo;
    return 'Respuesta de mentira';
  }

  @override
  Future<String> preguntarSeleccion(
    String seleccion,
    String pregunta, {
    required String revisionId,
    required String capitulo,
  }) async {
    ultimoRevisionIdEnPreguntarSeleccion = revisionId;
    ultimoCapituloEnPreguntarSeleccion = capitulo;
    return 'Respuesta sobre la selección';
  }
}

/// Falla la primera vez (como el 502 real de Gemini saturado) y responde bien
/// a partir de la segunda — para probar "Reintentar" sin inventar un mock de
/// http.
class _ApiFallaUnaVez extends ApiFalsa {
  int llamadas = 0;

  @override
  Future<String> chat(
    String mensaje, {
    required String revisionId,
    required String capitulo,
  }) async {
    llamadas++;
    if (llamadas == 1) throw Exception('Error API (502): saturado');
    return 'Ahora sí';
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
    test('el chat libre manda el capítulo actual como contexto', () async {
      final api = _ApiQueRecuerdaElContexto();
      final c = GAiAssistantController(
        api: api,
        revisionId: 'cap-7',
        capituloActual: () => 'texto del capítulo, tal cual',
      );
      c.abrir();
      await c.enviar('¿Qué te parece este capítulo?');
      expect(api.ultimoRevisionIdEnChat, 'cap-7');
      expect(api.ultimoCapituloEnChat, 'texto del capítulo, tal cual');
    });

    test('preguntar sobre una selección también manda el capítulo', () async {
      final api = _ApiQueRecuerdaElContexto();
      final c = GAiAssistantController(
        api: api,
        revisionId: 'cap-7',
        capituloActual: () => 'texto del capítulo, tal cual',
      );
      c.abrir(seleccion: 'un fragmento');
      await c.enviar('¿Por qué?');
      expect(api.ultimoRevisionIdEnPreguntarSeleccion, 'cap-7');
      expect(api.ultimoCapituloEnPreguntarSeleccion, 'texto del capítulo, tal cual');
    });

    test('el capítulo se pide de nuevo en cada mensaje, no se cachea', () async {
      final api = _ApiQueRecuerdaElContexto();
      var version = 1;
      final c = GAiAssistantController(
        api: api,
        revisionId: 'x',
        capituloActual: () => 'capítulo v$version',
      );
      c.abrir();
      await c.enviar('Primer mensaje');
      expect(api.ultimoCapituloEnChat, 'capítulo v1');

      version = 2; // simula una edición hecha entre un mensaje y el siguiente
      await c.enviar('Segundo mensaje');
      expect(api.ultimoCapituloEnChat, 'capítulo v2',
          reason: 'la siguiente pregunta debe ver la edición ya hecha');
    });

    test('empieza oculto y abre en modo panel', () {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo');
      expect(c.mode, GAiAssistantMode.hidden);
      c.abrir();
      expect(c.mode, GAiAssistantMode.panel);
    });

    test('minimizar vuelve a burbuja sin perder los mensajes', () async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo');
      c.abrir();
      await c.enviar('Hola');
      expect(c.messages.length, 2);
      c.minimizar();
      expect(c.mode, GAiAssistantMode.bubble);
      expect(c.messages.length, 2, reason: 'minimizar no borra la conversación');
    });

    test('marca "hay nuevo" si la respuesta llega estando minimizado', () async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo');
      c.abrir();
      c.minimizar();
      await c.enviar('¿Sigues ahí?');
      expect(c.hayNuevo, isTrue);
      c.abrir();
      expect(c.hayNuevo, isFalse, reason: 'abrir el panel limpia el aviso');
    });

    test('con contexto de selección, pregunta usa preguntarSeleccion y trae seed', () async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo');
      c.abrir(seleccion: 'un fragmento del capítulo');
      await c.enviar('¿Por qué?');
      final respuesta = c.messages.last;
      expect(respuesta.deUsuario, isFalse);
      expect(respuesta.texto, 'Respuesta sobre la selección');
      expect(respuesta.seed, isNotNull);
      expect(respuesta.seed!['selection'], 'un fragmento del capítulo');
    });

    test('con anclable=false (vista previa) se pregunta pero no hay seed',
        () async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo');
      c.abrir(seleccion: 'texto ya compuesto', anclable: false);
      await c.enviar('¿Y esto?');
      final respuesta = c.messages.last;
      expect(respuesta.texto, 'Respuesta sobre la selección',
          reason: 'sigue usando preguntarSeleccion, solo no se puede convertir');
      expect(respuesta.seed, isNull,
          reason: 'no se puede anclar en el capítulo original');
    });

    test('sin selección, chat libre no trae seed', () async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo');
      c.abrir();
      await c.enviar('Hola');
      expect(c.messages.last.seed, isNull);
    });

    test('resize se queda dentro de los límites', () {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo');
      c.resize(-10000);
      expect(c.panelHeight, GAiAssistantController.minHeight);
      c.resize(10000);
      expect(c.panelHeight, GAiAssistantController.maxHeight);
    });

    test('convertirEnSugerencia llama a la API solo cuando hay seed', () async {
      final api = ApiFalsa();
      final c = GAiAssistantController(api: api, revisionId: 'x', capituloActual: () => 'un capitulo');
      c.abrir();
      await c.enviar('Hola'); // sin seed
      expect(await c.convertirEnSugerencia(c.messages.last), isFalse);
      expect(api.sugerenciasGeneradas, 0);

      c.abrir(seleccion: 'fragmento');
      await c.enviar('¿Y si...?'); // con seed
      expect(await c.convertirEnSugerencia(c.messages.last), isTrue);
      expect(api.sugerenciasGeneradas, 1);
    });

    test('un fallo deja el mensaje marcado como reintentable', () async {
      final c = GAiAssistantController(api: _ApiFallaUnaVez(), revisionId: 'x', capituloActual: () => 'un capitulo');
      c.abrir();
      await c.enviar('Hola');

      final error = c.messages.last;
      expect(error.esError, isTrue);
      expect(error.origenParaReintentar, 'Hola');
    });

    test('reintentar repite la pregunta sin duplicar la burbuja del usuario',
        () async {
      final c = GAiAssistantController(api: _ApiFallaUnaVez(), revisionId: 'x', capituloActual: () => 'un capitulo');
      c.abrir();
      await c.enviar('Hola');
      expect(c.messages.length, 2); // usuario + error

      await c.reintentar(c.messages.last);

      expect(c.messages.length, 2, reason: 'sigue habiendo solo un "Hola"');
      expect(c.messages.first.texto, 'Hola');
      expect(c.messages.last.texto, 'Ahora sí');
      expect(c.messages.last.esError, isFalse);
    });
  });

  group('GAiAssistantOverlay', () {
    testWidgets('oculto no pinta nada', (tester) async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo');
      await abrir(tester, c, ApiFalsa());
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('la burbuja abre el panel, y el campo no se come la pantalla', (tester) async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo')
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
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo')..abrir();
      await abrir(tester, c, ApiFalsa());

      await tester.enterText(find.byType(TextField), 'Hola');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Hola'), findsOneWidget);
      expect(find.text('Respuesta de mentira'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Respuesta de mentira'),
          matching: find.byType(SelectableText),
        ),
        findsOneWidget,
        reason: 'el texto de la IA se puede seleccionar con pulsación larga',
      );
    });

    testWidgets('mientras espera la respuesta no se ve el texto todavía',
        (tester) async {
      final api = _ApiLenta();
      final c = GAiAssistantController(api: api, revisionId: 'x', capituloActual: () => 'un capitulo')..abrir();
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

    testWidgets('tocar "Reintentar" repite la pregunta sin volver a escribirla',
        (tester) async {
      final api = _ApiFallaUnaVez();
      final c = GAiAssistantController(api: api, revisionId: 'x', capituloActual: () => 'un capitulo')..abrir();
      await abrir(tester, c, api);

      await tester.enterText(find.byType(TextField), 'Hola');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('REINTENTAR'), findsOneWidget);

      await tester.tap(find.text('REINTENTAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('REINTENTAR'), findsNothing);
      expect(find.text('Ahora sí'), findsOneWidget);
      expect(find.text('Hola'), findsOneWidget, reason: 'no se duplica la pregunta');
    });

    testWidgets('minimizar vuelve a mostrar la burbuja', (tester) async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo')..abrir();
      await abrir(tester, c, ApiFalsa());

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(c.mode, GAiAssistantMode.bubble);
    });
  });
}
