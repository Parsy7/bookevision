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

  /// Ancho máximo de la app: en una ventana más ancha (escritorio, tablet en
  /// horizontal) queda como una columna centrada de este ancho.
  static const double anchoApp = 640;

  /// Aire sobre la marca en la cabecera (hero) de las portadas.
  static const double heroTop = 22;

  /// Alto reservado bajo el título de la barra superior para una segunda
  /// línea (hueco incluido), p. ej. el estado del autoguardado.
  static const double appBarSubtitulo = 18;

  /// Columna del número grande en las filas de una portada (01, 02…).
  static const double rowNumber = 44;

  /// Logo junto a «bookevision» en el hero, y la B de la pantalla de carga.
  static const double logoMarca = 40;
  static const double logoArranque = 140;

  /// Logo centrado sobre «bookevision» en el login.
  static const double logoLogin = 72;

  /// Padding de los chips en mono (Ver original, Reintentar…).
  static const double chipH = 7;
  static const double chipV = 5;
  static const double chipGap = 6;

  // ── Asistente de IA ──

  /// Margen de la burbuja y del panel contra los bordes de la pantalla.
  static const double aiEdge = 12;

  /// Ancho máximo del panel del chat: en tablet no pasa de aquí.
  static const double aiPanelMax = 600;

  /// Aire que el panel deja siempre por encima (barra superior incluida).
  static const double aiPanelTop = 140;

  /// Diámetro de la burbuja minimizada: el alto de un botón de acción.
  static const double aiBubble = actionBtn;

  /// Punto de "respuesta nueva" sobre la burbuja, y su aro de papel.
  static const double aiBadge = 12;
  static const double aiBadgeRing = 2;

  /// Zona táctil del tirador que estira el panel, y la barrita visible.
  static const double aiHandle = 22;
  static const double aiHandleW = 36;
  static const double aiHandleH = 2;

  /// Botoncito de copiar de cada respuesta, y el hueco que se le reserva al
  /// texto para no quedar debajo.
  static const double aiCopy = 20;
  static const double aiCopyGutter = aiCopy + 2;

  /// Píldora "Preguntar a la IA": alto, padding lateral y distancia a la
  /// barra superior.
  static const double aiPill = 44;
  static const double aiPillH = 15;
  static const double aiPillTop = 80;

  /// Alto máximo del "Sobre: …" desplegado; más allá hace scroll.
  static const double aiContextMax = 160;

  /// Padding de página para un scroll que llega al borde inferior: reserva el
  /// hueco de la barra de navegación de Android.
  static EdgeInsets pageScroll(BuildContext context) => EdgeInsets.fromLTRB(
        page,
        page,
        page,
        page + MediaQuery.paddingOf(context).bottom,
      );
}
