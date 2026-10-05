import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import 'g_bits.dart';

/// Color de un botón de acción. El tono solo cambia el color; la forma es
/// siempre la misma.
enum GTone { ink, red, blue, danger }

/// Una acción de la rejilla: tecla mono, rótulo y estado.
class GAction {
  final String keyLetter;
  final String label;
  final GTone tone;
  final bool active;
  final VoidCallback onTap;

  /// Ocupa las dos columnas (p. ej. «Escribir yo» en las inserciones).
  final bool full;

  /// Centra el rótulo, sin tecla (los botones de un diálogo).
  final bool centered;

  const GAction({
    required this.keyLetter,
    required this.label,
    required this.onTap,
    this.tone = GTone.ink,
    this.active = false,
    this.full = false,
    this.centered = false,
  });
}

/// Rejilla de acciones 2×2 con líneas de tinta, al pie de una tarjeta.
///
/// Sin animación: al pulsar, el relleno cambia al instante. Activo = relleno
/// del color del tono con el texto en claro.
class GActions extends StatelessWidget {
  final List<GAction> actions;

  const GActions(this.actions, {super.key});

  @override
  Widget build(BuildContext context) {
    // Se reparten en filas de dos, salvo las que ocupan el ancho entero.
    final filas = <List<GAction>>[];
    for (final a in actions) {
      if (a.full ||
          filas.isEmpty ||
          filas.last.length == 2 ||
          filas.last.first.full) {
        filas.add([a]);
      } else {
        filas.last.add(a);
      }
    }

    return Container(
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Column(
        children: [
          for (var f = 0; f < filas.length; f++)
            Row(
              children: [
                for (var i = 0; i < filas[f].length; i++)
                  Expanded(
                    child: _Boton(
                      accion: filas[f][i],
                      conBordeDerecho: i < filas[f].length - 1,
                      conBordeInferior: f < filas.length - 1,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Boton extends StatelessWidget {
  final GAction accion;
  final bool conBordeDerecho;
  final bool conBordeInferior;

  const _Boton({
    required this.accion,
    required this.conBordeDerecho,
    required this.conBordeInferior,
  });

  @override
  Widget build(BuildContext context) {
    final tono = switch (accion.tone) {
      GTone.ink => GColors.ink,
      GTone.red => GColors.accent,
      GTone.blue => GColors.blue,
      GTone.danger => GColors.danger,
    };
    final sobre = switch (accion.tone) {
      GTone.ink => GColors.onInk,
      GTone.red => GColors.onRed,
      GTone.blue => GColors.onBlue,
      GTone.danger => GColors.onDanger,
    };
    final color = accion.active ? sobre : tono;

    return InkWell(
      onTap: accion.onTap,
      child: Container(
        height: GSpacing.actionBtn,
        padding: const EdgeInsets.symmetric(horizontal: GSpacing.blockV),
        decoration: BoxDecoration(
          color: accion.active ? tono : null,
          border: Border(
            right: conBordeDerecho
                ? BorderSide(color: GColors.ink, width: GSpacing.border)
                : BorderSide.none,
            bottom: conBordeInferior
                ? BorderSide(color: GColors.ink, width: GSpacing.border)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: accion.centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            if (!accion.centered) ...[
              GKey(accion.keyLetter, color: color),
              const SizedBox(width: GSpacing.gapSm),
            ],
            Flexible(
              child: Text(
                accion.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GText.action.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
