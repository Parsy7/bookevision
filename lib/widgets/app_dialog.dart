import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';

/// Diálogo base de la app: título, mensaje y hasta dos acciones (confirmar y
/// cancelar) usando siempre [AppButton]. El aspecto del contenedor lo pone el
/// `dialogTheme` global (fondo `bgCard`, radio `card`, sin sombra).
///
/// Uso:
///   final ok = await AppDialog.confirm(
///     context,
///     title: 'Borrar decisiones',
///     message: '¿Seguro? Se perderán las respuestas y ediciones.',
///     confirmLabel: 'Borrar',
///     danger: true,
///   );
class AppDialog extends StatelessWidget {
  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;

  /// Si `true`, el botón de confirmar usa la variante destructiva.
  final bool danger;

  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.confirmLabel = 'Aceptar',
    this.cancelLabel = 'Cancelar',
    this.danger = false,
  });

  /// Muestra el diálogo y devuelve `true` si se confirma, `false`/`null` si no.
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = 'Aceptar',
    String cancelLabel = 'Cancelar',
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        danger: danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title, style: AppText.titleSection),
      content: message == null ? null : Text(message!, style: AppText.bodyText),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.card,
        0,
        AppSpacing.card,
        AppSpacing.card,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: cancelLabel,
                variant: AppButtonVariant.cancel,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: AppSpacing.gapSm),
            Expanded(
              child: AppButton(
                label: confirmLabel,
                variant:
                    danger ? AppButtonVariant.danger : AppButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
