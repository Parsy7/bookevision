import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';

/// Relleno de la CTA de la barra inferior.
enum GFootFill { red, ink, off }

/// Botón cuadrado de solo icono a la derecha de la CTA ([GFoot.conIconos]).
/// Sin [onTap] se pinta deshabilitado.
class GFootIcono {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const GFootIcono({required this.icon, required this.tooltip, this.onTap});
}

/// Barra inferior de 64dp, pegada abajo y con borde superior de tinta.
///
/// Tres formas: navegación + CTA ([GFoot.navegada]), una sola CTA
/// ([GFoot.unica]) o dos mitades ([GFoot.partida]). El hueco de la barra de
/// Android se reserva aquí, no en el scroll.
class GFoot extends StatelessWidget {
  final List<Widget> children;

  const GFoot._(this.children);

  /// ↑ | CTA | ↓ — el lector.
  factory GFoot.navegada({
    required String label,
    required GFootFill fill,
    required VoidCallback? onMain,
    required VoidCallback? onUp,
    required VoidCallback? onDown,
  }) {
    return GFoot._([
      _Nav(icon: Icons.north, tooltip: 'Pendiente anterior', onTap: onUp),
      Expanded(child: _Main(label: label, fill: fill, onTap: onMain)),
      _Nav(
        icon: Icons.south,
        tooltip: 'Pendiente siguiente',
        onTap: onDown,
        alFinal: true,
      ),
    ]);
  }

  /// Una sola CTA a todo el ancho.
  factory GFoot.unica({
    required String label,
    required GFootFill fill,
    required VoidCallback? onTap,
    IconData? icon,
  }) {
    return GFoot._([
      Expanded(child: _Main(label: label, fill: fill, onTap: onTap, icon: icon)),
    ]);
  }

  /// CTA | icono | icono… — p. ej. Revisar y confirmar con las acciones del
  /// editor de un capítulo suelto. Los iconos usan la misma celda que ↑/↓.
  factory GFoot.conIconos({
    required String label,
    required GFootFill fill,
    required VoidCallback? onMain,
    required List<GFootIcono> iconos,
  }) {
    return GFoot._([
      Expanded(child: _Main(label: label, fill: fill, onTap: onMain)),
      for (final i in iconos)
        _Nav(icon: i.icon, tooltip: i.tooltip, onTap: i.onTap, alFinal: true),
    ]);
  }

  /// Dos mitades: Guardar .md | Copiar todo, o Guardar | Cancelar al editar.
  factory GFoot.partida({
    required String leftLabel,
    required String rightLabel,
    required VoidCallback onLeft,
    required VoidCallback onRight,
    GFootFill leftFill = GFootFill.red,
    GFootFill rightFill = GFootFill.ink,
  }) {
    return GFoot._([
      Expanded(
        child: _Main(label: leftLabel, fill: leftFill, onTap: onLeft, conBorde: true),
      ),
      Expanded(
        child: _Main(label: rightLabel, fill: rightFill, onTap: onRight),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GColors.paper,
        border: Border(top: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: GSpacing.foot,
          // El `Row` sin `stretch` deja que cada hijo se encoja a su
          // contenido (el texto o el icono) y lo centra dentro de los 64dp,
          // dejando un hueco de papel arriba y abajo — el botón rojo no
          // llenaba la barra. `stretch` fuerza a todos los hijos (las flechas
          // y la CTA) a ocupar el alto entero.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool alFinal;

  const _Nav({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.alFinal = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: GSpacing.foot,
            decoration: BoxDecoration(
              border: Border(
                right: alFinal
                    ? BorderSide.none
                    : BorderSide(color: GColors.ink, width: GSpacing.border),
                left: alFinal
                    ? BorderSide(color: GColors.ink, width: GSpacing.border)
                    : BorderSide.none,
              ),
            ),
            child: Icon(icon,
                size: 20, color: onTap == null ? GColors.grey3 : GColors.ink),
          ),
        ),
      );
}

class _Main extends StatelessWidget {
  final String label;
  final GFootFill fill;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool conBorde;

  const _Main({
    required this.label,
    required this.fill,
    required this.onTap,
    this.icon,
    this.conBorde = false,
  });

  @override
  Widget build(BuildContext context) {
    final (Color? fondo, Color texto) = switch (fill) {
      GFootFill.red => (GColors.red, GColors.onRed),
      GFootFill.ink => (GColors.ink, GColors.onInk),
      GFootFill.off => (null, GColors.grey3),
    };

    return InkWell(
      onTap: onTap,
      child: Container(
        color: fondo,
        foregroundDecoration: conBorde
            ? BoxDecoration(
                border: Border(
                  right: BorderSide(color: GColors.ink, width: GSpacing.border),
                ),
              )
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: texto),
              const SizedBox(width: GSpacing.barTop),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GText.footButton.copyWith(color: texto),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
