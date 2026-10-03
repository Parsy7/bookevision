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
                  bottom:
                      BorderSide(color: GColors.ink, width: GSpacing.border),
                ),
              ),
              child: const GMono('Acción irreversible', color: GColors.danger),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSpacing.card, GSpacing.card, GSpacing.card, GSpacing.gapXs),
              child: Text.rich(
                TextSpan(
                  style: GText.cardTitle,
                  children: [
                    TextSpan(text: '$title '),
                    TextSpan(
                        text: keyword,
                        style: GText.cardTitleEm
                            .copyWith(color: GColors.danger)),
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
                tone: GTone.danger,
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

  /// Fracción del alto de pantalla que puede ocupar [hoja] (como en Anotto
  /// para las hojas de selección).
  static const _altoMaxHoja = 0.7;

  /// Las mismas filas, en una hoja desde abajo (las opciones de una fila al
  /// mantenerla pulsada). Devuelve el `value` elegido, o `null` si se cierra.
  static Future<String?> hoja(
    BuildContext context, {
    required String titulo,
    required List<GMenuItem> items,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      // Como mucho el 70% del alto, y con scroll: la lista (p. ej. todos los
      // capítulos de un libro) puede ser mucho más larga que la pantalla.
      constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * _altoMaxHoja),
      backgroundColor: GColors.sheet,
      barrierColor: GColors.scrim,
      elevation: 0,
      shape:
          Border(top: BorderSide(color: GColors.ink, width: GSpacing.border)),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(GSpacing.gap),
              decoration: BoxDecoration(
                border: Border(
                    bottom:
                        BorderSide(color: GColors.ink, width: GSpacing.border)),
              ),
              child: GMono.muted(titulo),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) => InkWell(
                  onTap: () => Navigator.of(ctx).pop(items[i].value),
                  child:
                      _GMenuFila(item: items[i], ultima: i == items.length - 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      tooltip: 'Más',
      position: PopupMenuPosition.under,
      color: GColors.sheet,
      elevation: 0,
      padding: EdgeInsets.zero,
      menuPadding: EdgeInsets.zero,
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
            child: _GMenuFila(item: items[i], ultima: i == items.length - 1),
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

/// Una fila de [GMenu], igual en el desplegable y en [GMenu.hoja].
class _GMenuFila extends StatelessWidget {
  final GMenuItem item;
  final bool ultima;

  const _GMenuFila({required this.item, required this.ultima});

  @override
  Widget build(BuildContext context) {
    final color = item.danger ? GColors.danger : GColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GSpacing.gap, vertical: GSpacing.card),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : Border(
                bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 20, color: color),
          const SizedBox(width: GSpacing.blockV),
          Flexible(
              child:
                  Text(item.label, style: GText.menu.copyWith(color: color))),
        ],
      ),
    );
  }
}
