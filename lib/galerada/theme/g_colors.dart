import 'package:flutter/painting.dart';

/// Paleta «Galerada»: una prueba de imprenta. Papel, tinta negra y el rojo del
/// corrector. Mismo criterio que la paleta Pergamino de `AppColors`: ningún
/// color se escribe suelto en la UI, siempre un token de aquí.
///
/// El verde de «resuelta» desaparece: lo resuelto se marca con relleno de
/// tinta, no con color.
class GColors {
  GColors._();

  /// Fondo de página.
  static const Color paper = Color(0xFFF3F0E8);

  /// Tarjetas, diálogos y menús.
  static const Color sheet = Color(0xFFFBFAF6);

  /// Bloque de la propuesta y fondo del editor.
  static const Color white = Color(0xFFFFFFFF);

  /// Texto, **todos** los bordes, rellenos y estado activo.
  static const Color ink = Color(0xFF141414);

  /// Acento del corrector: CTA principal, pendiente, eliminar, tachado.
  static const Color red = Color(0xFFE4401C);

  /// «Escribir yo» y borde del editor.
  static const Color blue = Color(0xFF2449D8);

  /// Cursivas: motivo de la sugerencia, subtítulos.
  static const Color grey1 = Color(0xFF5E594F);

  /// Metadatos mono y texto de contexto.
  static const Color grey2 = Color(0xFF6B665E);

  /// Texto tachado (un punto más cálido que [grey2]).
  static const Color strike = Color(0xFF6D675D);

  /// Números de párrafo y deshabilitado.
  static const Color grey3 = Color(0xFF8A847A);

  /// Velo de los diálogos: rgba(20,20,20,.55).
  static const Color scrim = Color(0x8C141414);

  // Texto sobre relleno.
  static const Color onInk = paper;
  static const Color onRed = Color(0xFFFFFFFF);
  static const Color onBlue = Color(0xFFFFFFFF);

  /// Sobreimpreso de tinta al 6% para el estado pulsado.
  static const Color press = Color(0x0F141414);
}
