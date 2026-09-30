import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';

/// Degradado "IA": la única excepción visual de toda la piel Galerada, que
/// por lo demás es plana (papel/tinta, sin degradados ni sombras). Se pintan
/// así a propósito, para que el asistente se lea como un elemento aparte del
/// papel impreso — decisión pedida expresamente, no un descuido de marca.
class GAiColors {
  GAiColors._();

  static const List<Color> gradient = [
    Color(0xFF4F46E5),
    Color(0xFFA21CAF),
    Color(0xFFEC4899),
  ];

  static const LinearGradient linear = LinearGradient(
    colors: gradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Icono "IA" (auto_awesome) con un parpadeo suave — gira y crece un poco de
/// forma continua, para que se note que es interactivo sin necesitar que
/// nada más en la pantalla se mueva.
class GAiSparkle extends StatefulWidget {
  final double size;

  /// Si se da, pinta el icono sólido en ese color (p.ej. blanco sobre el
  /// orbe); si no, lo rellena con el degradado.
  final Color? solidColor;

  const GAiSparkle({super.key, this.size = 16, this.solidColor});

  @override
  State<GAiSparkle> createState() => _GAiSparkleState();
}

class _GAiSparkleState extends State<GAiSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icono = widget.solidColor != null
        ? Icon(Icons.auto_awesome, size: widget.size, color: widget.solidColor)
        : ShaderMask(
            shaderCallback: (rect) => GAiColors.linear.createShader(rect),
            child: Icon(Icons.auto_awesome, size: widget.size, color: Colors.white),
          );
    return AnimatedBuilder(
      animation: _c,
      child: icono,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.rotate(
          angle: t * 0.17,
          child: Transform.scale(scale: 1 + t * 0.2, child: child),
        );
      },
    );
  }
}

/// Halo desenfocado detrás de un botón o burbuja "IA": solo respira en
/// intensidad, sin girar (el giro de 360° se probó y no convenció).
class GAiGlow extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? radius;

  const GAiGlow({super.key, required double size, this.radius})
      : width = size,
        height = size;

  /// Rellena el hueco que le dé su padre (pensado para ir dentro de un
  /// [Positioned.fill] dentro de un [Stack] cuyo tamaño ya lo pone otro
  /// hijo) — para cuando ese tamaño no se conoce de antemano, como el ancho
  /// de una píldora cuyo texto se ajusta a su contenido.
  const GAiGlow.fill({super.key})
      : width = null,
        height = null,
        radius = const BorderRadius.all(Radius.circular(999));

  @override
  State<GAiGlow> createState() => _GAiGlowState();
}

class _GAiGlowState extends State<GAiGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width, h = widget.height;
    final blur = w == null || h == null ? 16.0 : (w < h ? w : h) * 0.45;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final opacity = 0.2 + Curves.easeInOut.transform(_c.value) * 0.28;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              shape: widget.radius == null ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: widget.radius,
              boxShadow: [
                BoxShadow(
                  color: GAiColors.gradient[1].withValues(alpha: opacity),
                  blurRadius: blur,
                  spreadRadius: blur * 0.13,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Botón flotante "Preguntar a la IA": aparece junto a una selección de
/// texto y late mientras la selección siga viva.
class GAiSelectionPill extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const GAiSelectionPill({super.key, required this.onTap, this.label = 'Preguntar a la IA'});

  @override
  Widget build(BuildContext context) {
    // Sin ancho fijo: un tamaño de letra distinto (fuente de verdad en el
    // móvil vs. la de respaldo en los tests, o el texto agrandado del
    // sistema) no debe recortar el rótulo — la píldora se ajusta a lo que
    // ocupe de verdad.
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(child: GAiGlow.fill()),
          GAiGradientBorder(
            innerColor: GColors.sheet,
            child: Container(
              height: GSpacing.aiPill,
              // Sin `alignment`: con él, `Container` envuelve el hijo en un
              // `Align` que se expande hasta el máximo disponible aunque el
              // contenido sea pequeño — la píldora acababa ocupando todo el
              // ancho de la pantalla en vez de ajustarse al texto.
              padding: const EdgeInsets.symmetric(horizontal: GSpacing.aiPillH),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const GAiSparkle(),
                  const SizedBox(width: GSpacing.gapSm),
                  GAiGradientText(label, style: GText.mono),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Píldora con borde de degradado: la capa exterior hace de borde, la interior
/// lleva el color real de fondo.
class GAiGradientBorder extends StatelessWidget {
  final Widget child;
  final Color innerColor;
  final double borderWidth;

  const GAiGradientBorder({
    super.key,
    required this.child,
    required this.innerColor,
    this.borderWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(999)),
        gradient: GAiColors.linear,
      ),
      padding: EdgeInsets.all(borderWidth),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          color: innerColor,
        ),
        child: child,
      ),
    );
  }
}

/// Texto con relleno degradado, para el rótulo del botón "IA".
class GAiGradientText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const GAiGradientText(this.text, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => GAiColors.linear.createShader(rect),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

/// Coloca el botón "Preguntar a la IA" en un sitio fijo bajo la barra
/// superior, en vez de perseguir el punto exacto donde el dedo soltó la
/// selección (no siempre disponible a tiempo). Colocar como hijo de un
/// [Stack] que envuelva toda la pantalla.
class GAiSelectionPillOverlay extends StatelessWidget {
  final VoidCallback onTap;

  const GAiSelectionPillOverlay({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: GSpacing.aiPillTop + MediaQuery.paddingOf(context).top,
      left: 0,
      right: 0,
      child: Center(child: GAiSelectionPill(onTap: onTap)),
    );
  }
}

/// Orbe circular relleno de degradado, con el sparkle en blanco dentro —
/// la burbuja minimizada del asistente.
class GAiOrb extends StatelessWidget {
  final double size;

  const GAiOrb({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: GAiColors.linear),
      alignment: Alignment.center,
      child: GAiSparkle(size: size * 0.4, solidColor: Colors.white),
    );
  }
}
