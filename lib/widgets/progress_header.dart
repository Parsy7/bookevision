import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Franja de progreso del lector: contador "X/Y resueltas" y barra. Sin sombra;
/// la barra se distingue por color de relleno sobre la pista.
class ProgressHeader extends StatelessWidget {
  final int done;
  final int total;

  const ProgressHeader({super.key, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 1.0 : done / total;
    final pending = total - done;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.gapSm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$done/$total resueltas', style: AppText.label),
              const Spacer(),
              if (pending > 0)
                Text('$pending pendientes', style: AppText.caption)
              else
                Text('Completado', style: AppText.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.gapSm),
          ClipRRect(
            borderRadius: AppRadius.pill,
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.bgElevated,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
