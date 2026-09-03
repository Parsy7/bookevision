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
      // El capítulo definitivo puede ser larguísimo: si los botones van al
      // final del scroll, hay que recorrerlo entero para llegar a ellos. Van
      // fijos abajo, como en la vista previa.
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                if (counts.total > 0) ...[
                _summaryItem(
                    _cuenta(counts.accepted, 'sugerencia aceptada',
                        'sugerencias aceptadas'),
                    'Se aplicará exactamente el texto propuesto.'),
                const SizedBox(height: AppSpacing.gapSm),
                _summaryItem(
                    _cuenta(counts.originals, 'original conservado',
                        'originales conservados'),
                    'Esos fragmentos permanecerán como estaban.'),
                const SizedBox(height: AppSpacing.gapSm),
                _summaryItem(
                    _cuenta(counts.custom, 'respuesta personalizada',
                        'respuestas personalizadas'),
                    'Se usarán tus propias versiones.'),
                const SizedBox(height: AppSpacing.gapSm),
                _summaryItem(
                    _cuenta(counts.omitted, 'fragmento eliminado',
                        'fragmentos eliminados'),
                    'Esos fragmentos no aparecerán en el capítulo.'),
                const SizedBox(height: AppSpacing.gapSm),
                ],
                _summaryItem(
                    _cuenta(counts.manual, 'bloque editado directamente',
                        'bloques editados directamente'),
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
              ],
            ),
          ),
          _acciones(context),
        ],
      ),
    );
  }

  /// Barra fija: los dos botones, siempre a mano, sin scroll.
  Widget _acciones(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.gapSm),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Guardar .md',
                onPressed: () => ExportMd.share(title, 'definitivo', text),
              ),
            ),
            const SizedBox(width: AppSpacing.gapSm),
            Expanded(
              child: AppButton(
                label: 'Copiar todo',
                variant: AppButtonVariant.secondary,
                onPressed: () async {
                  await ExportMd.copy(text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copiado al portapapeles')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// «1 fragmento eliminado» / «2 fragmentos eliminados».
  String _cuenta(int n, String singular, String plural) =>
      '$n ${n == 1 ? singular : plural}';

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
