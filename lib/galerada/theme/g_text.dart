import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';
import 'g_colors.dart';

/// Tipografía de «Galerada», calcada de `galerada.css`. Tres familias con
/// papeles que no se mezclan:
///
/// - **Instrument Serif** para los titulares (hero, barra, tarjetas, botones).
/// - **Newsreader** para todo lo que se lee de corrido.
/// - **JetBrains Mono** en mayúsculas para etiquetas, metadatos y estados.
///
/// Los estilos van **cerrados** (`inherit: false`, con su `textBaseline`, que
/// `TextField` exige en ese caso): así un `Text` y un
/// `TextField` con el mismo token miden exactamente igual, que es lo que
/// permite que la prosa se vuelva editable sin recomponerse. Sin cerrarlos,
/// cada uno completaría lo que le falta de un sitio distinto.
class GText {
  GText._();

  static TextStyle _serif({
    required double size,
    required double height,
    Color? color,
    FontStyle style = FontStyle.normal,
    double? letterSpacing,
  }) =>
      GoogleFonts.instrumentSerif(
        fontSize: size,
        height: height,
        color: color ?? GColors.ink,
        fontStyle: style,
        letterSpacing: letterSpacing,
        fontWeight: FontWeight.w400,
      ).copyWith(inherit: false, textBaseline: TextBaseline.alphabetic);

  static TextStyle _read({
    required double size,
    required double height,
    Color? color,
    FontStyle style = FontStyle.normal,
    FontWeight weight = FontWeight.w400,
  }) =>
      GoogleFonts.newsreader(
        fontSize: size,
        height: height,
        color: color ?? GColors.ink,
        fontStyle: style,
        fontWeight: weight,
      ).copyWith(inherit: false, textBaseline: TextBaseline.alphabetic);

  static TextStyle _mono({
    required double size,
    required double height,
    Color? color,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        height: height,
        color: color ?? GColors.ink,
        fontWeight: FontWeight.w600,
        letterSpacing: size * 0.08, // .08em
      ).copyWith(inherit: false, textBaseline: TextBaseline.alphabetic);

  // ---------- Titulares (Instrument Serif) ----------

  /// Hero de la lista: «La jaula rota» a 64px.
  static TextStyle get hero =>
      _serif(size: 64, height: 1.05, letterSpacing: -0.64); // -.01em

  /// Hero de un capítulo, cuyo título suele ser largo («XV. El precio del
  /// silencio»): el mismo titular a 52 (mismo interlineado y espaciado que
  /// [hero]).
  static TextStyle get heroSm =>
      _serif(size: 52, height: 1.05, letterSpacing: -0.64);

  /// Título de la barra superior.
  static TextStyle get appBar => _serif(size: 26, height: 1);

  /// Título de una tarjeta de sugerencia.
  static TextStyle get cardTitle => _serif(size: 28, height: 1.05);

  /// La palabra clave del título, en rojo y cursiva.
  static TextStyle get cardTitleEm => _serif(
      size: 28, height: 1.05, color: GColors.accent, style: FontStyle.italic);

  /// Título de una fila de la lista.
  static TextStyle get rowTitle => _serif(size: 22, height: 1.1);

  /// Número de capítulo de la lista y de los recuentos.
  static TextStyle get bigNumber => _serif(size: 40, height: 1);

  /// Etiqueta de un recuento en la confirmación.
  static TextStyle get statLabel => _serif(size: 18, height: 1.2);

  /// Rótulo de un botón de pantalla, del FAB y de la barra inferior.
  static TextStyle get button => _serif(size: 20, height: 1);

  /// Rótulo de la CTA de la barra inferior.
  static TextStyle get footButton => _serif(size: 22, height: 1);

  // ---------- Lectura (Newsreader) ----------

  /// Prosa del capítulo.
  static TextStyle get prose => _read(size: 17, height: 1.65);

  /// Bloques de texto dentro de una tarjeta (original y propuesta).
  static TextStyle get block => _read(size: 16, height: 1.55);

  /// Párrafos de contexto de una inserción.
  static TextStyle get context =>
      _read(size: 15, height: 1.5, color: GColors.grey2);

  /// Motivo de la sugerencia.
  static TextStyle get reason => _read(
        size: 14,
        height: 1.45,
        color: GColors.grey1,
        style: FontStyle.italic,
      );

  /// Subtítulo del hero.
  static TextStyle get heroSub => _read(
        size: 16,
        height: 1.4,
        color: GColors.grey1,
        style: FontStyle.italic,
      );

  /// Explicación de un recuento en la confirmación.
  static TextStyle get statNote => _read(
        size: 13,
        height: 1.4,
        color: GColors.grey1,
        style: FontStyle.italic,
      );

  /// Rótulo de un botón de la rejilla de acciones.
  static TextStyle get action =>
      _read(size: 14, height: 1, weight: FontWeight.w500);

  /// Fila de menú.
  static TextStyle get menu => _read(size: 16, height: 1);

  /// Cuerpo de un diálogo.
  static TextStyle get dialog => _read(size: 15, height: 1.5);

  /// Mensajes del chat con la IA.
  static TextStyle get chat => _read(size: 14.5, height: 1.55);

  /// Títulos ("### Opción 1") dentro de una respuesta de la IA: titular de
  /// la casa, como el de las tarjetas pero a escala del chat.
  static TextStyle get chatTitle => _serif(size: 21, height: 1.15);

  // ---------- Etiquetas (JetBrains Mono, MAYÚSCULAS) ----------

  /// Etiquetas, metadatos, estados y sellos.
  static TextStyle get mono => _mono(size: 12, height: 1.3);

  /// Teclas de las acciones, números de párrafo y sellos de estado.
  static TextStyle get monoSm => _mono(size: 10, height: 1);

  /// Número de párrafo en el margen.
  static TextStyle get paragraphNo =>
      _mono(size: 10, height: 1, color: GColors.grey3);

  /// Campo de pegado de JSON.
  static TextStyle get field => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        height: 1.5,
        color: GColors.ink,
        fontWeight: FontWeight.w400,
      ).copyWith(inherit: false, textBaseline: TextBaseline.alphabetic);
}
