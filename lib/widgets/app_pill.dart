import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text.dart';

/// Etiqueta pequeña redondeada (pill/badge). Radio `pill`, texto `AppText.xs`.
/// Por defecto usa el tono "etiqueta" del libro (arena + marrón).
class AppPill extends StatelessWidget {
  /// Texto de la etiqueta.
  final String label;

  /// Color de fondo. Por defecto `AppColors.pillBg`.
  final Color color;

  /// Color del texto. Por defecto `AppColors.pillText`.
  final Color? textColor;

  const AppPill({
    super.key,
    required this.label,
    this.color = AppColors.pillBg,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.pill),
      child: Text(
        label,
        style: AppText.label.copyWith(
          color: textColor ?? AppColors.pillText,
          fontSize: AppText.xs,
        ),
      ),
    );
  }
}
