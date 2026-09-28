import 'package:flutter/painting.dart';
import '../../models/tema.dart';
import '../../services/api_service.dart';
import '../../services/tema_store.dart';

/// Paleta «Galerada»: papel, tinta y un acento. Los valores ya no son fijos —
/// vienen del [Tema] activo (ver `GET /temas` y "Mi perfil") — pero cada
/// token sigue teniendo un único significado en toda la UI, igual que antes.
///
/// El verde de «resuelta» desaparece: lo resuelto se marca con relleno de
/// tinta, no con color.
class GColors {
  GColors._();

  static Tema _current = Tema.clasico;

  /// El [Tema] completo activo — para saber cuál está elegido en "Mi perfil".
  static Tema get actual => _current;

  /// Cambia la paleta activa. Se llama al arrancar (con el tema guardado o
  /// el que sincronice el login) y al elegir uno nuevo en "Mi perfil".
  static void aplicar(Tema tema) => _current = tema;

  /// Aplica el último tema guardado localmente, si hay alguno. Se llama en
  /// `main()` antes de `runApp` para no pintar un frame con el Clásico por
  /// defecto y luego saltar al tema real.
  static Future<void> cargarCache() async {
    final guardado = await TemaStore().cargar();
    if (guardado != null) _current = guardado;
  }

  /// Trae el tema elegido por el usuario desde el servidor y lo aplica —
  /// para que, al entrar desde un dispositivo nuevo, se vea el tema de
  /// siempre y no el Clásico por defecto. Best-effort: sin red o sin tema
  /// propio, se queda con lo que ya hubiera.
  static Future<void> sincronizarDesdeServidor(ApiService api) async {
    try {
      final temaId = await api.getMiTemaId();
      if (temaId == null) return;
      final temas = await api.getTemas();
      final tema = temas.firstWhere((t) => t.id == temaId, orElse: () => Tema.clasico);
      _current = tema;
      await TemaStore().guardar(tema);
    } catch (_) {
      // Sin red o fallo del servidor: se sigue con lo que ya había.
    }
  }

  /// Fondo de página.
  static Color get paper => _current.paper;

  /// Tarjetas, diálogos y menús.
  static Color get sheet => _current.sheet;

  /// Bloque de la propuesta y fondo del editor.
  static Color get white => _current.white;

  /// Texto, **todos** los bordes, rellenos y estado activo.
  static Color get ink => _current.ink;

  /// Acento del tema: CTA principal, pendiente, eliminar, tachado.
  static Color get red => _current.acento;

  /// «Escribir yo» y borde del editor.
  static Color get blue => _current.blue;

  /// Cursivas: motivo de la sugerencia, subtítulos.
  static Color get grey1 => _current.grey1;

  /// Metadatos mono y texto de contexto.
  static Color get grey2 => _current.grey2;

  /// Texto tachado (un punto más cálido que [grey2]).
  static Color get strike => _current.strike;

  /// Números de párrafo y deshabilitado.
  static Color get grey3 => _current.grey3;

  /// Velo de los diálogos: tinta al 55%.
  static Color get scrim => _current.scrim;

  // Texto sobre relleno.
  static Color get onInk => _current.onInk;
  static Color get onRed => _current.onRed;
  static Color get onBlue => _current.onBlue;

  /// Sobreimpreso de tinta al 6% para el estado pulsado.
  static Color get press => _current.press;
}
