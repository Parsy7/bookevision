import 'package:flutter/material.dart';

/// Paleta "Pergamino" del revisor de «La jaula rota»: tema claro, cálido y
/// literario, tomado del lector HTML del libro. Mismo criterio que Anotto:
/// ningún color se escribe suelto en la UI, siempre un token de aquí.
class AppColors {
  AppColors._();

  // Fondos.
  static const Color bg = Color(0xFFF6F1E9); // pergamino (fondo de página)
  static const Color bgCard = Color(0xFFFFFAF2); // tarjeta, un punto más clara
  static const Color bgElevated = Color(0xFFF3E7D3); // hover / superficie elevada

  // Acento (marrón terracota del libro).
  static const Color primary = Color(0xFF8A5A44);
  static const Color primaryDark = Color(0xFF6D4636);
  static const Color primaryLight = Color(0xFFB98A6E);

  // Bordes.
  static const Color border = Color(0xFFE2D7C6); // línea sutil (cards)
  static const Color borderStrong = Color(0xFFCBB79E); // inputs, dividers, press

  // Texto.
  static const Color text = Color(0xFF2B2622); // tinta
  static const Color textMuted = Color(0xFF7A6A58); // sepia
  static const Color textInverse = Color(0xFFFBF6EE); // texto sobre relleno de acento

  // Etiqueta / pill del libro (fondo arena, texto marrón).
  static const Color pillBg = Color(0xFFDCC9A8);
  static const Color pillText = Color(0xFF6D5738);

  // Semánticos (tonos apagados que no rompen el pergamino).
  static const Color success = Color(0xFF5E7A52); // "resuelta", aceptada
  static const Color warning = Color(0xFFB98A3C);

  /// Rojo ladrillo para acciones destructivas. Sobre relleno sólido usar
  /// [onError] para el texto/icono (blanco cálido), no [text].
  static const Color error = Color(0xFF9E4B36);
  static const Color onError = Color(0xFFFBF6EE);
}
