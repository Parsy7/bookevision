import 'package:flutter/widgets.dart';

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

  /// Padding de página para un scroll que llega hasta el borde inferior de la
  /// pantalla: reserva además el hueco de la barra de navegación de Android,
  /// que si no tapa el último elemento de la lista (y no hay forma de seguir
  /// bajando para descubrirlo).
  ///
  /// No hace falta cuando el scroll tiene debajo una barra fija con
  /// `SafeArea`: allí el hueco ya lo reserva la barra.
  static EdgeInsets pageScroll(BuildContext context) => EdgeInsets.fromLTRB(
        page,
        page,
        page,
        page + MediaQuery.paddingOf(context).bottom,
      );
}
