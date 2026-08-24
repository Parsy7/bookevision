import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';

/// Tarjeta base: fondo `bgCard`, borde `border`, radio `card`, padding `card`.
/// Sin sombra.
class AppCard extends StatelessWidget {
  /// Contenido de la tarjeta.
  final Widget child;

  /// Si se pasa, envuelve la tarjeta en un [InkWell] tocable.
  final VoidCallback? onTap;

  /// Pulsación larga opcional (p. ej. para editar un bloque de prosa a mano).
  final VoidCallback? onLongPress;

  const AppCard({super.key, required this.child, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: child,
    );

    if (onTap == null && onLongPress == null) return content;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: AppRadius.card,
      child: content,
    );
  }
}
