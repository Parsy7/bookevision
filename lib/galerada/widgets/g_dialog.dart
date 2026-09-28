import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import 'g_actions.dart';
import 'g_bits.dart';

/// Diálogo de confirmación de «Galerada»: cabecera mono roja, título grande
/// con la palabra clave en cursiva roja, y los dos botones en la misma rejilla
/// de acciones que las tarjetas.
class GDialog {
  GDialog._();

  static Future<bool?> confirmar(
    BuildContext context, {
    required String title,
    required String keyword,
    required String message,
    String confirmLabel = 'Borrar',
    String cancelLabel = 'Cancelar',
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: GColors.scrim,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(28),
        backgroundColor: GColors.sheet,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: GColors.ink, width: GSpacing.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(GSpacing.card),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: GColors.ink, width: GSpacing.border),
                ),
              ),
              child: const GMono.red('Acción irreversible'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSpacing.card, GSpacing.card, GSpacing.card, GSpacing.gapXs),
              child: Text.rich(
                TextSpan(
                  style: GText.cardTitle,
                  children: [
                    TextSpan(text: '$title '),
                    TextSpan(text: keyword, style: GText.cardTitleEm),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSpacing.card, 0, GSpacing.card, GSpacing.gap),
              child: Text(message, style: GText.dialog),
            ),
            GActions([
              GAction(
                keyLetter: '',
                label: cancelLabel,
                centered: true,
                onTap: () => Navigator.of(ctx).pop(false),
              ),
              GAction(
                keyLetter: '',
                label: confirmLabel,
                tone: GTone.red,
                active: true,
                centered: true,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Una fila del menú de la barra superior.
class GMenuItem {
  final String label;
  final IconData icon;
  final String value;
  final bool danger;

  const GMenuItem({
    required this.label,
    required this.icon,
    required this.value,
    this.danger = false,
  });
}

/// Menú de la barra superior: hoja con borde de tinta, radio 0 y filas en
/// Newsreader. La acción destructiva va en rojo.
class GMenu extends StatelessWidget {
  final List<GMenuItem> items;
  final ValueChanged<String> onSelected;

  const GMenu({super.key, required this.items, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      tooltip: 'Más',
      position: PopupMenuPosition.under,
      color: GColors.sheet,
      elevation: 0,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 230),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: GColors.ink, width: GSpacing.border),
      ),
      itemBuilder: (_) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem<String>(
            value: items[i].value,
            padding: EdgeInsets.zero,
            height: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: GSpacing.gap, vertical: GSpacing.card),
              decoration: BoxDecoration(
                border: i < items.length - 1
                    ? Border(
                        bottom: BorderSide(
                            color: GColors.ink, width: GSpacing.border))
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    items[i].icon,
                    size: 20,
                    color: items[i].danger ? GColors.red : GColors.ink,
                  ),
                  const SizedBox(width: GSpacing.blockV),
                  Flexible(
                    child: Text(
                      items[i].label,
                      style: GText.menu.copyWith(
                        color: items[i].danger ? GColors.red : GColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      child: Container(
        width: GSpacing.iconBtn,
        height: GSpacing.iconBtn,
        decoration: BoxDecoration(
          color: GColors.ink,
          border: Border.all(color: GColors.ink, width: GSpacing.border),
        ),
        child: Icon(Icons.more_horiz, size: 20, color: GColors.onInk),
      ),
    );
  }
}
