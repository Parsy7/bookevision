import 'package:flutter/widgets.dart';

/// Medidas de «Galerada». Prohibido escribir paddings, alturas o grosores
/// literales en la UI: siempre un token de aquí.
class GSpacing {
  GSpacing._();

  /// Padding de página y de los laterales de la barra superior.
  static const double page = 18;

  /// Hueco entre bloques del cuerpo.
  static const double gap = 16;

  /// Padding interior de las tarjetas.
  static const double card = 14;

  /// Padding vertical de los bloques dentro de una tarjeta.
  static const double blockV = 12;

  static const double barTop = 10;
  static const double barBottom = 14;

  /// Botón de icono de la barra superior.
  static const double iconBtn = 40;

  /// Alto de los botones de acción y de los botones de pantalla.
  static const double actionBtn = 52;

  /// Alto de la barra inferior.
  static const double foot = 64;

  /// Alto del botón flotante de la lista.
  static const double fab = 56;

  /// Sangrado de la prosa, donde va el número de párrafo.
  static const double proseIndent = 30;

  /// Franja izquierda de un bloque de prosa editado a mano.
  static const double stripe = 3;

  /// Grosor de todos los bordes de tinta.
  static const double border = 1;

  /// Celdas del medidor de la lista.
  static const double meterW = 14;
  static const double meterH = 6;
  static const double meterGap = 2;

  /// Alto de las celdas de progreso del lector.
  static const double tick = 10;

  /// Ancho del cursor de escritura y hueco que `RenderEditable` reserva a su
  /// derecha (el cursor más 1dp). La prosa en lectura reserva ese mismo hueco
  /// para romper línea exactamente donde lo hará el campo de edición.
  static const double caret = 2;
  static const double caretGutter = caret + 1;

  static const double gapSm = 8;
  static const double gapXs = 4;

  /// Padding de página para un scroll que llega al borde inferior: reserva el
  /// hueco de la barra de navegación de Android.
  static EdgeInsets pageScroll(BuildContext context) => EdgeInsets.fromLTRB(
        page,
        page,
        page,
        page + MediaQuery.paddingOf(context).bottom,
      );
}
