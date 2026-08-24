/// Escala única de tamaños de icono (dp). Prohibido escribir tamaños de icono
/// literales; siempre un token de esta clase.
///   Icon(icon, size: AppIcon.sm)
class AppIcon {
  AppIcon._();

  static const double xs = 16; // filas densas, iconos en pills
  static const double sm = 20; // iconos de botón y de sheet
  static const double md = 24; // cabeceras, iconos destacados
  static const double lg = 32; // iconos grandes / acciones principales
  static const double xl = 40; // estados vacíos / ilustración puntual
}
