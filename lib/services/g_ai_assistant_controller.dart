import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Burbuja minimizada, panel abierto, o del todo oculto (antes de la primera
/// vez que se usa, en pantallas donde no hay burbuja persistente).
enum GAiAssistantMode { hidden, bubble, panel }

/// Un mensaje del chat flotante. `seed` solo está presente en una respuesta
/// nacida de una pregunta sobre texto seleccionado: es lo que hace falta
/// para poder convertirla en una sugerencia concreta del capítulo. `esError`
/// + `origenParaReintentar` permiten reintentar la misma pregunta con un
/// toque, sin tener que volver a escribirla.
class GAiMessage {
  final String texto;
  final bool deUsuario;
  final Map<String, dynamic>? seed;
  final bool esError;
  final String? origenParaReintentar;

  const GAiMessage(
    this.texto,
    this.deUsuario, {
    this.seed,
    this.esError = false,
    this.origenParaReintentar,
  });
}

/// Estado del asistente flotante de IA: vive tanto como la pantalla que lo
/// aloja, cada una con su propia instancia. Dentro de esa pantalla la IA
/// recuerda la conversación (se le mandan los últimos turnos en cada
/// petición); entre pantallas y entre sesiones, no.
class GAiAssistantController extends ChangeNotifier {
  GAiAssistantController({
    required this.api,
    required this.revisionId,
    required this.capituloActual,
  });

  final ApiService api;
  final String revisionId;

  /// El texto que se manda como contexto en cada mensaje — se llama de
  /// nuevo en cada envío, nunca se guarda en frío, para que si haces una
  /// edición a mitad de conversación la siguiente pregunta ya la vea. Cada
  /// pantalla decide qué es "el capítulo" para ella: el compuesto con las
  /// decisiones ya tomadas (revisor, vista previa) o el original literal
  /// ("Ver original").
  final String Function() capituloActual;

  static const double minHeight = 300;
  static const double maxHeight = 720;

  GAiAssistantMode mode = GAiAssistantMode.hidden;
  double panelHeight = 440;
  final List<GAiMessage> messages = [];
  String? seleccionContexto;
  bool enviando = false;
  bool convirtiendo = false;
  bool hayNuevo = false;

  /// Dónde se quedó el scroll del chat al minimizarlo, para volver ahí al
  /// reabrirlo. `null` = al final (primera vez, o hay una respuesta nueva
  /// que no has visto).
  double? scrollOffset;

  /// Si el fragmento en [seleccionContexto] no es una copia literal del
  /// capítulo original (p. ej. viene de la vista previa, ya compuesta con
  /// ediciones aplicadas), "Usar como sugerencia" no puede anclarlo — se
  /// puede preguntar sobre él igualmente, solo no convertir la respuesta.
  bool _seleccionAnclable = true;

  /// Abre el panel. Con [seleccion], todas las preguntas de esta sesión se
  /// hacen sobre ese fragmento (vía `/ai/preguntar-seleccion`) en vez de
  /// chat libre. [anclable] en `false` cuando ese fragmento no se puede
  /// localizar tal cual en el capítulo original (vista previa).
  void abrir({String? seleccion, bool anclable = true}) {
    mode = GAiAssistantMode.panel;
    if (hayNuevo) scrollOffset = null;
    hayNuevo = false;
    if (seleccion != null) {
      seleccionContexto = seleccion;
      _seleccionAnclable = anclable;
    }
    notifyListeners();
  }

  void minimizar() {
    mode = GAiAssistantMode.bubble;
    notifyListeners();
  }

  void resize(double deltaAltura) {
    panelHeight = (panelHeight + deltaAltura).clamp(minHeight, maxHeight);
    notifyListeners();
  }

  Future<void> enviar(String texto) async {
    final mensaje = texto.trim();
    if (mensaje.isEmpty || enviando) return;
    messages.add(GAiMessage(mensaje, true));
    await _pedir(mensaje);
  }

  /// Repite la pregunta que falló, sin tener que volver a escribirla ni
  /// duplicar la burbuja del usuario — solo quita el aviso de error.
  Future<void> reintentar(GAiMessage error) async {
    if (!error.esError || error.origenParaReintentar == null || enviando) return;
    messages.remove(error);
    notifyListeners();
    await _pedir(error.origenParaReintentar!);
  }

  /// Turnos que se mandan como memoria de la conversación: suficientes para
  /// que "hazlo más corto" o "¿y la segunda opción?" tengan sentido, sin
  /// disparar el tamaño de cada petición.
  static const int maxTurnosHistorial = 12;

  /// La conversación antes de [mensaje], sin los avisos de error (no son
  /// parte de lo hablado) ni el propio [mensaje], que va aparte.
  List<Map<String, String>> _historialAntesDe(String mensaje) {
    final previos = messages.where((m) => !m.esError).toList();
    if (previos.isNotEmpty && previos.last.deUsuario && previos.last.texto == mensaje) {
      previos.removeLast();
    }
    final desde = previos.length > maxTurnosHistorial ? previos.length - maxTurnosHistorial : 0;
    return [
      for (final m in previos.skip(desde))
        {'rol': m.deUsuario ? 'autor' : 'ia', 'texto': m.texto},
    ];
  }

  Future<void> _pedir(String mensaje) async {
    enviando = true;
    notifyListeners();
    try {
      final seleccion = seleccionContexto;
      final capitulo = capituloActual();
      final historial = _historialAntesDe(mensaje);
      final respuesta = seleccion != null
          ? await api.preguntarSeleccion(seleccion, mensaje,
              revisionId: revisionId, capitulo: capitulo, historial: historial)
          : await api.chat(mensaje,
              revisionId: revisionId, capitulo: capitulo, historial: historial);
      messages.add(GAiMessage(
        respuesta,
        false,
        seed: seleccion != null && _seleccionAnclable
            ? {'selection': seleccion, 'question': mensaje, 'answer': respuesta}
            : null,
      ));
      if (mode != GAiAssistantMode.panel) hayNuevo = true;
    } catch (e) {
      messages.add(GAiMessage(
        '✕ No se pudo responder: $e',
        false,
        esError: true,
        origenParaReintentar: mensaje,
      ));
    } finally {
      enviando = false;
      notifyListeners();
    }
  }

  /// `true` si se pudo convertir — quien llama decide cómo avisarlo (snackbar).
  Future<bool> convertirEnSugerencia(GAiMessage msg) async {
    final seed = msg.seed;
    if (seed == null || convirtiendo) return false;
    convirtiendo = true;
    notifyListeners();
    try {
      await api.generarSugerencias(revisionId, seed: seed);
      return true;
    } catch (_) {
      return false;
    } finally {
      convirtiendo = false;
      notifyListeners();
    }
  }
}
