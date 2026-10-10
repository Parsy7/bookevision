import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_actions.dart';
import '../widgets/g_bits.dart';

/// «Exportar capítulo»: el formato y el alcance. De momento solo se puede
/// sacar el capítulo abierto en Markdown; lo demás se ve, apagado, para que se
/// sepa lo que viene. Devuelve `true` si se pulsa «Descargar».
class GExportarDialogo {
  GExportarDialogo._();

  static Future<bool?> mostrar(BuildContext context,
      {required String tituloCapitulo}) {
    return showDialog<bool>(
      context: context,
      barrierColor: GColors.scrim,
      builder: (ctx) => Dialog(
        backgroundColor: GColors.sheet,
        elevation: 0,
        insetPadding: const EdgeInsets.all(GSpacing.page),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: GColors.ink, width: GSpacing.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: GSpacing.escDialogo),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(GSpacing.card),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(
                          color: GColors.ink, width: GSpacing.border)),
                ),
                child: const GMono('Exportar'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    GSpacing.card, GSpacing.card, GSpacing.card, GSpacing.gap),
                child: Text.rich(TextSpan(style: GText.cardTitle, children: [
                  const TextSpan(text: 'Exportar '),
                  TextSpan(text: 'capítulo', style: GText.cardTitleEm),
                ])),
              ),
              const _Seccion('Formato'),
              const _Opcion(
                  icono: Icons.code, rotulo: 'Markdown (.md)', activa: true),
              const _Opcion(
                  icono: Icons.auto_stories,
                  rotulo: 'Libro EPUB',
                  activa: false),
              const _Opcion(
                  icono: Icons.description_outlined,
                  rotulo: 'Word (.docx)',
                  activa: false),
              const _Seccion('Alcance'),
              _Opcion(
                  icono: Icons.article_outlined,
                  rotulo: 'Solo este capítulo: $tituloCapitulo',
                  activa: true),
              const _Opcion(
                  icono: Icons.menu_book_outlined,
                  rotulo: 'El libro entero',
                  activa: false),
              const _Opcion(
                  icono: Icons.edit_note,
                  rotulo: 'Incluir notas críticas y anotaciones',
                  activa: false),
              const SizedBox(height: GSpacing.gap),
              GActions([
                GAction(
                  keyLetter: '',
                  label: 'Cancelar',
                  centered: true,
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
                GAction(
                  keyLetter: '',
                  label: 'Descargar',
                  tone: GTone.red,
                  active: true,
                  centered: true,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String texto;
  const _Seccion(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            GSpacing.card, GSpacing.gapSm, GSpacing.card, GSpacing.gapXs),
        child: GMono.muted(texto),
      );
}

/// Una fila de opción: la activa lleva borde y relleno de tinta, la apagada
/// va en gris y con «Próximamente».
class _Opcion extends StatelessWidget {
  final IconData icono;
  final String rotulo;
  final bool activa;

  const _Opcion(
      {required this.icono, required this.rotulo, required this.activa});

  @override
  Widget build(BuildContext context) {
    final tinta = activa ? GColors.ink : GColors.grey3;
    return Semantics(
      enabled: activa,
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: GSpacing.card, vertical: GSpacing.gapXs),
        padding: const EdgeInsets.all(GSpacing.gapSm),
        decoration: BoxDecoration(
          color: activa ? GColors.white : null,
          border: Border.all(color: tinta, width: GSpacing.border),
        ),
        child: Row(
          children: [
            Icon(icono, size: 20, color: tinta),
            const SizedBox(width: GSpacing.gapSm),
            Expanded(
                child: Text(rotulo, style: GText.menu.copyWith(color: tinta))),
            if (!activa) GMono('Próximamente', color: tinta, small: true),
          ],
        ),
      ),
    );
  }
}
