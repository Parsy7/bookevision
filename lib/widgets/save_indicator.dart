import 'package:flutter/material.dart';
import '../services/review_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_icon.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Indicador compacto del estado de guardado (autosave): Guardando… / Guardado
/// / Sin guardar / Error. Pensado para la cabecera del lector.
class SaveIndicator extends StatelessWidget {
  final SaveStatus status;

  const SaveIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late final IconData? icon;
    late final String text;
    late final Color color;
    Widget? leading;

    switch (status) {
      case SaveStatus.saving:
        leading = const SizedBox(
          width: AppIcon.xs,
          height: AppIcon.xs,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.textMuted),
          ),
        );
        icon = null;
        text = 'Guardando…';
        color = AppColors.textMuted;
        break;
      case SaveStatus.saved:
      case SaveStatus.idle:
        icon = Icons.check_rounded;
        text = 'Guardado';
        color = AppColors.textMuted;
        break;
      case SaveStatus.pending:
        icon = Icons.cloud_upload_outlined;
        text = 'Sin guardar';
        color = AppColors.textMuted;
        break;
      case SaveStatus.error:
        icon = Icons.error_outline_rounded;
        text = 'Error al guardar';
        color = AppColors.error;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) leading,
        if (icon != null) Icon(icon, size: AppIcon.xs, color: color),
        const SizedBox(width: AppSpacing.gapXs),
        Text(text, style: AppText.caption.copyWith(color: color)),
      ],
    );
  }
}
