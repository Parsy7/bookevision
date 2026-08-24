class AppConfig {
  AppConfig._();

  /// Base de la API PHP (apunta al index.php del backend). Cambia el dominio
  /// por el tuyo cuando subas `api/` al servidor.
  static const String apiBaseUrl =
      'https://letsshuffle.es/bookevision/api/index.php';
}
