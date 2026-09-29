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
/// aloja (`GReviewerScreen` o `GOriginalScreen`), cada una con su propia
/// instancia — sin histórico entre pantallas ni entre sesiones, igual que ya
/// era el chat de IA antes de este rediseño.
class GAiAssistantController extends ChangeNotifier {
  GAiAssistantController({required this.api, required this.revisionId});

  final ApiService api;
  final String revisionId;

  static const double minHeight = 300;
  static const double maxHeight = 720;

  GAiAssistantMode mode = GAiAssistantMode.hidden;
  double panelHeight = 440;
  final List<GAiMessage> messages = [];
  String? seleccionContexto;
  bool enviando = false;
  bool convirtiendo = false;
  bool hayNuevo = false;

  /// Abre el panel. Con [seleccion], todas las preguntas de esta sesión se
  /// hacen sobre ese fragmento (vía `/ai/preguntar-seleccion`) en vez de
  /// chat libre.
  void abrir({String? seleccion}) {
    mode = GAiAssistantMode.panel;
    hayNuevo = false;
    if (seleccion != null) seleccionContexto = seleccion;
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

  Future<void> _pedir(String mensaje) async {
    enviando = true;
    notifyListeners();
    try {
      final seleccion = seleccionContexto;
      final respuesta = seleccion != null
          ? await api.preguntarSeleccion(seleccion, mensaje)
          : await api.chat(mensaje);
      messages.add(GAiMessage(
        respuesta,
        false,
        seed: seleccion != null
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
