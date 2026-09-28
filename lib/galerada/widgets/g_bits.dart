import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';

enum _GMonoVariant { normal, muted, red }

/// Etiqueta mono en mayúsculas: metadatos, estados, cabeceras de tarjeta.
///
/// El color por defecto de cada variante (`GColors.ink`/`grey2`/`red`) ya no
/// es constante de compilación —depende del tema activo—, así que se resuelve
/// en `build()` a partir de [_variant] en vez de fijarse en el constructor:
/// así los tres constructores pueden seguir siendo `const`.
class GMono extends StatelessWidget {
  final String label;
  final Color? color;
  final _GMonoVariant _variant;
  final bool small;

  const GMono(this.label, {super.key, this.color, this.small = false})
      : _variant = _GMonoVariant.normal;

  const GMono.muted(this.label, {super.key, this.small = false})
      : color = null,
        _variant = _GMonoVariant.muted;

  const GMono.red(this.label, {super.key, this.small = false})
      : color = null,
        _variant = _GMonoVariant.red;

  @override
  Widget build(BuildContext context) {
    final resuelto = color ??
        switch (_variant) {
          _GMonoVariant.normal => GColors.ink,
          _GMonoVariant.muted => GColors.grey2,
          _GMonoVariant.red => GColors.red,
        };
    return Text(
      label.toUpperCase(),
      style: (small ? GText.monoSm : GText.mono).copyWith(color: resuelto),
    );
  }
}

/// Sello de estado de la lista: contorno de tinta, o relleno si está listo.
class GStamp extends StatelessWidget {
  final String label;
  final bool filled;

  const GStamp(this.label, {super.key, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? GColors.ink : null,
        border: Border.all(color: GColors.ink, width: GSpacing.border),
      ),
      child: Text(
        label.toUpperCase(),
        style: GText.monoSm
            .copyWith(color: filled ? GColors.onInk : GColors.ink),
      ),
    );
  }
}

/// Medidor de la lista: una celda por sugerencia, rellena si está resuelta.
class GMeter extends StatelessWidget {
  final int total;
  final int done;

  const GMeter({super.key, required this.total, required this.done});

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    return Wrap(
      spacing: GSpacing.meterGap,
      runSpacing: GSpacing.meterGap,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: GSpacing.meterW,
            height: GSpacing.meterH,
            decoration: BoxDecoration(
              color: i < done ? GColors.ink : null,
              border: Border.all(color: GColors.ink, width: GSpacing.border),
            ),
          ),
      ],
    );
  }
}

/// Celdas de progreso del lector: como el medidor, pero a todo el ancho.
class GTicks extends StatelessWidget {
  final int total;
  final int done;

  const GTicks({super.key, required this.total, required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: Container(
              height: GSpacing.tick,
              decoration: BoxDecoration(
                color: i < done ? GColors.ink : null,
                border: Border.all(color: GColors.ink, width: GSpacing.border),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Tecla de un botón de acción: letra mono con contorno del color del rótulo.
class GKey extends StatelessWidget {
  final String letter;
  final Color color;

  const GKey(this.letter, {super.key, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: GSpacing.border),
        ),
        child: Text(letter, style: GText.monoSm.copyWith(color: color)),
      );
}

/// Línea de tinta de 1px. Separa bloques dentro de una tarjeta y secciones de
/// pantalla; en Galerada todo lo que no es fondo es un borde.
class GRule extends StatelessWidget {
  const GRule({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: GSpacing.border, color: GColors.ink);
}
