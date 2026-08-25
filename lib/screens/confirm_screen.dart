import 'package:flutter/material.dart';
import '../services/review_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../utils/export_md.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';

/// Confirmación final: resumen de decisiones + capítulo definitivo, con copiar
/// y guardar .md. Solo se abre cuando todo está resuelto.
class ConfirmScreen extends StatelessWidget {
  final String title;
  final String text;
  final Counts counts;

  const ConfirmScreen({
    super.key,
    required this.title,
    required this.text,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu capítulo quedará así')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          _summaryItem('${counts.accepted} sugerencias aceptadas',
              'Se aplicará exactamente el texto propuesto.'),
          const SizedBox(height: AppSpacing.gapSm),
          _summaryItem('${counts.originals} originales conservados',
              'Esos fragmentos permanecerán como estaban.'),
          const SizedBox(height: AppSpacing.gapSm),
          _summaryItem('${counts.custom} respuestas personalizadas',
              'Se usarán tus propias versiones.'),
          const SizedBox(height: AppSpacing.gapSm),
          _summaryItem('${counts.manual} bloques editados directamente',
              'Cambios hechos con pulsación larga fuera de las tarjetas.'),
          const SizedBox(height: AppSpacing.gapMd),
          Text('Capítulo definitivo', style: AppText.label),
          const SizedBox(height: AppSpacing.gapSm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.card),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: SelectableText(text, style: AppText.readerText),
          ),
          const SizedBox(height: AppSpacing.gapMd),
          AppButton(
            label: 'Guardar .md',
            icon: Icons.ios_share,
            onPressed: () => ExportMd.share(title, 'definitivo', text),
          ),
          const SizedBox(height: AppSpacing.gapSm),
          AppButton(
            label: 'Copiar todo',
            variant: AppButtonVariant.secondary,
            icon: Icons.copy_all_outlined,
            onPressed: () async {
              await ExportMd.copy(text);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copiado al portapapeles')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String title, String subtitle) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.label),
          const SizedBox(height: AppSpacing.gapXs),
          Text(subtitle, style: AppText.caption),
        ],
      ),
    );
  }
}
