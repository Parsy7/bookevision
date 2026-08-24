import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_pill.dart';

/// Pantalla provisional (Fase 2) para validar el tema y los widgets genéricos
/// en el dispositivo. Se sustituirá por la lista de revisiones en la Fase 4.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BookeVision')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text('La jaula rota', style: AppText.titlePage),
          const SizedBox(height: AppSpacing.titleSubtitle),
          Text('Revisor de capítulos · muestrario de estilo',
              style: AppText.subtitle),
          const SizedBox(height: AppSpacing.subtitleBody),

          // Tarjeta de ejemplo con pills de estado.
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sustitución', style: AppText.titleSection),
                const SizedBox(height: AppSpacing.gapSm),
                Wrap(
                  spacing: AppSpacing.gapSm,
                  runSpacing: AppSpacing.gapSm,
                  children: const [
                    AppPill(label: 'Pendiente'),
                    AppPill(
                      label: 'Resuelta',
                      color: AppColors.success,
                      textColor: AppColors.textInverse,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.gapMd),
                Text(
                  'Tragó saliva, sintiendo que la última frase le arañaba la '
                  'garganta al salir. Ella no apartó los ojos de los suyos.',
                  style: AppText.readerText,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.gapMd),

          // Variantes de botón.
          AppButton(label: 'Aceptar sugerencia', onPressed: () {}),
          const SizedBox(height: AppSpacing.gapSm),
          AppButton(
            label: 'Escribir la mía',
            variant: AppButtonVariant.secondary,
            onPressed: () {},
          ),
          const SizedBox(height: AppSpacing.gapSm),
          AppButton(
            label: 'Borrar decisiones',
            variant: AppButtonVariant.danger,
            onPressed: () => AppDialog.confirm(
              context,
              title: 'Borrar decisiones',
              message: 'Se perderán las respuestas y las ediciones manuales.',
              confirmLabel: 'Borrar',
              danger: true,
            ),
          ),
        ],
      ),
    );
  }
}
