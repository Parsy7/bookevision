/// Escala de espaciado (dp). Prohibido escribir paddings/gaps literales en la
/// UI: siempre un token de esta clase.
class AppSpacing {
  AppSpacing._();

  static const double page = 20;
  static const double card = 16;
  static const double btnX = 16;
  static const double btnY = 12;
  static const double gapSm = 8;
  static const double gapXs = 4;
  static const double gapMd = 16;
  static const double titleSubtitle = 4;
  static const double subtitleBody = 24;
  static const double iconText = 8;

  /// Ancho del cursor de escritura (`TextField.cursorWidth`).
  static const double caret = 2;

  /// Hueco que Flutter reserva a la derecha del texto cuando es editable: el
  /// cursor más 1dp de aire (`RenderEditable._kCaretGap`). El texto en modo
  /// lectura reserva ese mismo hueco para romper línea exactamente donde lo
  /// hará el campo de edición.
  static const double caretGutter = caret + 1;
}
