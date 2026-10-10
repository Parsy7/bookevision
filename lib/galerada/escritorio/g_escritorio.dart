import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Cuándo la app se pinta con el diseño de escritorio (tres columnas) y cómo
/// se entra y se sale de él.
///
/// Solo en un **ordenador Windows** o una **tablet grande en horizontal**; el
/// móvil y la tablet en vertical siguen con el diseño de siempre.
class GEscritorio {
  GEscritorio._();

  /// Ancho de ventana, en dp, a partir del cual hay sitio para las tres
  /// columnas.
  static const double anchoMinimo = 900;

  /// Lado corto mínimo para considerar que un dispositivo es una tablet.
  static const double ladoCortoTablet = 600;

  /// Para los tests: simula (o niega) que se corre en Windows.
  @visibleForTesting
  static bool? forzarWindows;

  static bool get _esWindows => forzarWindows ?? Platform.isWindows;

  /// Mide la **ventana**, no el `MediaQuery`: dentro de [GAnchoApp] el
  /// `MediaQuery` ya dice el ancho de la columna (640) y nunca llegaría.
  static bool esEscritorio(BuildContext context) {
    final vista = View.of(context);
    final tamano = vista.physicalSize / vista.devicePixelRatio;
    if (tamano.width < anchoMinimo) return false;
    return _esWindows || tamano.shortestSide >= ladoCortoTablet;
  }

  static final ValueNotifier<int> _abiertas = ValueNotifier(0);

  /// `true` mientras hay una pantalla de escritorio abierta: la app deja de
  /// ser una columna estrecha centrada y ocupa la ventana entera.
  static ValueListenable<int> get abiertas => _abiertas;

  /// Abre [pantalla] a ventana completa. La cuenta sube antes de empujar la
  /// ruta (así el primer fotograma ya es ancho) y baja cuando la ruta se ha
  /// ido del todo, **después** de su animación de salida y también si la
  /// quitan de golpe (cambiar de tema o cerrar sesión vacía la pila): si
  /// bajara al hacer `pop`, la pantalla se encogería a la columna estrecha
  /// mientras aún se está yendo.
  static Future<T?> abrir<T>(BuildContext context, Widget pantalla) {
    _abiertas.value++;
    final ruta = MaterialPageRoute<T>(builder: (_) => pantalla);
    Navigator.of(context).push<T>(ruta);
    return ruta.completed.whenComplete(() => _abiertas.value--);
  }
}
