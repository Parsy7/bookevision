/// Piel visual de la app. Las dos conviven enteras y comparten `models/`,
/// `services/` y `utils/`: solo cambia la capa de vista.
///
/// - [pergamino]: el diseño original, cálido y de libro (`lib/theme`,
///   `lib/widgets`, `lib/screens`).
/// - [galerada]: el rediseño de prueba de imprenta —papel, tinta y el rojo del
///   corrector— en `lib/galerada`.
enum Piel { pergamino, galerada }

class AppConfig {
  AppConfig._();

  /// Cambia esta constante y la app entera cambia de piel. No hay más
  /// interruptores: nada más en el código pregunta por la piel.
  static const Piel piel = Piel.galerada;

  /// Base de la API PHP (apunta al index.php del backend). Cambia el dominio
  /// por el tuyo cuando subas `api/` al servidor.
  static const String apiBaseUrl =
      'https://letsshuffle.es/bookevision/api/index.php';
}
