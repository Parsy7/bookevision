import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/g_marca.dart';
import '../theme/g_spacing.dart';

/// Pantalla de carga al abrir la app: la B del logo aparece poco a poco
/// sobre el azul de la marca, se queda un momento y se funde con la app.
///
/// [child] se construye desde el principio, debajo, para que vaya cargando
/// (sesión, libros) mientras dura la animación en vez de después.
class GSplash extends StatefulWidget {
  final Widget child;

  const GSplash({super.key, required this.child});

  /// Lo que dura todo: aparecer, quedarse y fundirse con la app.
  static const duracion = Duration(milliseconds: 2800);

  @override
  State<GSplash> createState() => _GSplashState();
}

class _GSplashState extends State<GSplash> with TickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: GSplash.duracion)..forward();

  // Tramos sobre la duración total: la B aparece en el primer 50%, se queda,
  // y la pantalla entera se funde en el último 15%.
  late final Animation<double> _logo =
      CurvedAnimation(parent: _c, curve: const Interval(0, 0.5, curve: Curves.easeInOut));
  late final Animation<double> _salida = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.85, 1, curve: Curves.easeOut)));

  // Mientras la B está en pantalla, late: va de opacidad 1 a 0.3 y vuelve,
  // una y otra vez, para que el efecto se note de verdad.
  late final AnimationController _latidoC =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);
  late final Animation<double> _latido = Tween<double>(begin: 1, end: 0.3)
      .animate(CurvedAnimation(parent: _latidoC, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    _latidoC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _c,
          builder: (context, logo) {
            if (_c.isCompleted) return const SizedBox.shrink();
            return IgnorePointer(
              // Deja de tapar los toques en cuanto empieza a fundirse.
              ignoring: _salida.value < 1,
              child: Opacity(opacity: _salida.value, child: logo),
            );
          },
          // Iconos claros en la barra de estado mientras el fondo es azul.
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: ColoredBox(
              color: GMarca.fondo,
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_logo, _latido]),
                  child: Image.asset(
                    GMarca.marca,
                    height: GSpacing.logoArranque,
                    semanticLabel: 'bookevision',
                  ),
                  builder: (context, imagen) => Opacity(
                    opacity: _logo.value * _latido.value,
                    child: imagen,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
