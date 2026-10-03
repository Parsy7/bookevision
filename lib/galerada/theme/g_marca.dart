import 'package:flutter/painting.dart';

/// La marca de bookevision: el logo y sus dos colores. A diferencia de
/// `GColors`, **no cambian con el tema** elegido en «Mi perfil»: son los del
/// logo, y los usan solo el icono, la pantalla de carga y el sello del hero.
/// Ver BRAND_GUIDE.md → «Marca».
class GMarca {
  GMarca._();

  /// Azul del fondo del logo (y del icono y del arranque).
  static const Color fondo = Color(0xFF232A42);

  /// Dorado de las hojas del libro dentro de la B.
  static const Color dorado = Color(0xFFC9A06A);

  /// Logo cuadrado con su fondo azul.
  static const String logo = 'assets/logo/logo.png';

  /// Solo la B, sobre transparente (para ponerla sobre el azul de [fondo]).
  static const String marca = 'assets/logo/marca.png';
}
