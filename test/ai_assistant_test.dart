import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:bookevision/galerada/theme/g_colors.dart';
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
    List<Map<String, String>> historial = const [],
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
  List<Map<String, String>> ultimoHistorialEnChat = const [];
  List<Map<String, String>> ultimoHistorialEnPreguntarSeleccion = const [];

  @override
  Future<String> chat(
    String mensaje, {
    required String revisionId,
    required String capitulo,
    List<Map<String, String>> historial = const [],
  }) async {
    ultimoRevisionIdEnChat = revisionId;
    ultimoCapituloEnChat = capitulo;
    ultimoHistorialEnChat = historial;
    return 'Respuesta de mentira';
  }

  @override
  Future<String> preguntarSeleccion(
    String seleccion,
    String pregunta, {
    required String revisionId,
    required String capitulo,
    List<Map<String, String>> historial = const [],
  }) async {
    ultimoRevisionIdEnPreguntarSeleccion = revisionId;
    ultimoCapituloEnPreguntarSeleccion = capitulo;
    ultimoHistorialEnPreguntarSeleccion = historial;
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
    List<Map<String, String>> historial = const [],
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
    test('cada mensaje lleva la conversación anterior, sin errores ni él mismo',
        () async {
      final api = _ApiQueRecuerdaElContexto();
      final c = GAiAssistantController(api: api, revisionId: 'x', capituloActual: () => 'cap');

      await c.enviar('Primera pregunta');
      expect(api.ultimoHistorialEnChat, isEmpty, reason: 'el primer mensaje no tiene pasado');

      c.messages.add(const GAiMessage('✕ fallo', false, esError: true));
      await c.enviar('Hazlo más corto');
      expect(api.ultimoHistorialEnChat, [
        {'rol': 'autor', 'texto': 'Primera pregunta'},
        {'rol': 'ia', 'texto': 'Respuesta de mentira'},
      ]);
    });

    test('el historial se acota a los últimos turnos', () async {
      final api = _ApiQueRecuerdaElContexto();
      final c = GAiAssistantController(api: api, revisionId: 'x', capituloActual: () => 'cap');
      for (var i = 0; i < 20; i++) {
        await c.enviar('Pregunta $i');
      }
      expect(api.ultimoHistorialEnChat, hasLength(GAiAssistantController.maxTurnosHistorial));
      expect(api.ultimoHistorialEnChat.last['texto'], 'Respuesta de mentira');
    });

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

      await escribirEnChat(tester, 'Hola');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Hola'), findsOneWidget);
      expect(find.text('Respuesta de mentira'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Respuesta de mentira'),
          matching: find.byType(SelectionArea),
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

      await escribirEnChat(tester, 'Hola');
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

      await escribirEnChat(tester, 'Hola');
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

    testWidgets('el panel ocupa todo el ancho menos el margen, con tope de 600',
        (tester) async {
      addTearDown(tester.view.reset);
      Rect panel() => tester.getRect(find
          .descendant(
              of: find.byType(GAiAssistantOverlay),
              matching: find.byType(Material))
          .first);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo')..abrir();
      await abrir(tester, c, ApiFalsa());
      expect(panel().width, 360 - 24, reason: 'móvil: todo el ancho menos 12 a cada lado');
      expect(panel().right, 360 - 12);

      tester.view.physicalSize = const Size(1000, 780);
      await tester.pump();
      expect(panel().width, 600, reason: 'tablet: no pasa de 600');
      expect(panel().right, 1000 - 12, reason: 'sigue pegado a la derecha');
    });

    testWidgets('al abrir, el campo tiene el foco pero no saca el teclado hasta tocarlo',
        (tester) async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo')..abrir();
      await abrir(tester, c, ApiFalsa());
      await tester.pump();

      final campo = tester.widget<EditableText>(find.byType(EditableText));
      expect(campo.focusNode.hasFocus, isTrue, reason: 'se ve el cursor en el campo');
      expect(tester.testTextInput.isVisible, isFalse, reason: 'sin teclado al abrir');

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue, reason: 'al tocarlo, teclado');
    });

    testWidgets('detrás del panel hay una capa oscura, y tocarla minimiza', (tester) async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo')..abrir();
      await abrir(tester, c, ApiFalsa());
      await tester.pump(const Duration(milliseconds: 300));

      final capa = tester.widget<ColoredBox>(find
          .descendant(of: find.byType(GAiAssistantOverlay), matching: find.byType(ColoredBox))
          .first);
      expect(capa.color, GColors.scrim);

      await tester.tapAt(const Offset(5, 5)); // fuera del panel
      await tester.pump();
      expect(c.mode, GAiAssistantMode.bubble);
    });

    testWidgets('al reabrir, el chat vuelve a donde se había dejado', (tester) async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo');
      for (var i = 0; i < 30; i++) {
        c.messages.add(GAiMessage('Mensaje número $i', i.isEven));
      }
      c.abrir();
      await abrir(tester, c, ApiFalsa());
      await tester.pump();

      ScrollPosition posicion() =>
          tester.state<ScrollableState>(find.descendant(
              of: find.byType(ListView), matching: find.byType(Scrollable))).position;
      expect(posicion().pixels, posicion().maxScrollExtent,
          reason: 'la primera vez abre por el final');

      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pump(const Duration(seconds: 1)); // el sparkle no para: sin pumpAndSettle
      final dejado = posicion().pixels;
      expect(dejado, lessThan(posicion().maxScrollExtent));

      c.minimizar();
      await tester.pump();
      c.abrir();
      await tester.pump();
      await tester.pump();
      expect(posicion().pixels, dejado);
    });

    testWidgets('tocar "Sobre:" enseña la selección entera, y otro toque la recoge',
        (tester) async {
      final c = GAiAssistantController(api: ApiFalsa(), revisionId: 'x', capituloActual: () => 'un capitulo')
        ..abrir(seleccion: List.filled(30, 'una frase larga').join(' '));
      await abrir(tester, c, ApiFalsa());

      Text sobre() => tester.widget<Text>(find.textContaining('Sobre:'));
      expect(sobre().maxLines, 2);

      await tester.tap(find.textContaining('Sobre:'));
      await tester.pump();
      expect(sobre().maxLines, isNull, reason: 'desplegado, sin recortar');

      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pump();
      expect(sobre().maxLines, 2);
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
