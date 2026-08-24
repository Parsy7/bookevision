import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Campo de texto base: fondo `bgCard`, borde `border` (`primary` al enfocar),
/// radio `sm`, altura mínima 44dp.
///
/// Al enfocarse se desplaza a la vista por encima del teclado si hace falta
/// (busca el `Scrollable` más cercano; si no hay ninguno, no hace nada). Como
/// es el único campo de texto de la app, esto cubre cualquier formulario sin
/// tocar cada pantalla.
class AppInput extends StatefulWidget {
  final TextEditingController? controller;

  final String? hintText;

  final TextInputType? keyboardType;

  /// Líneas visibles. `1` (por defecto) para una sola línea; más para texto
  /// libre tipo prosa (el campo crece hasta ese máximo).
  final int maxLines;

  /// Mínimo de líneas visibles cuando [maxLines] > 1.
  final int? minLines;

  /// Mayúscula inicial automática por defecto (`sentences`).
  final TextCapitalization textCapitalization;

  const AppInput({
    super.key,
    this.controller,
    this.hintText,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.textCapitalization = TextCapitalization.sentences,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) return;
    // Espera a que el teclado termine de abrirse y el layout se reajuste
    // antes de desplazar el campo a la vista.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 45),
      child: TextField(
        focusNode: _focusNode,
        controller: widget.controller,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        style: AppText.bodyText,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppText.bodyText.copyWith(color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.bgCard,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.card,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: AppRadius.sm,
            borderSide: const BorderSide(color: AppColors.border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.sm,
            borderSide: const BorderSide(color: AppColors.borderStrong, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.sm,
            borderSide: const BorderSide(color: AppColors.primary, width: 1),
          ),
        ),
      ),
    );
  }
}
