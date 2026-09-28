import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import 'g_bits.dart';

/// Campo de texto de una línea: etiqueta mono arriba, caja de tinta, error
/// opcional abajo. Mismo recorte visual que el `TextField` de importar JSON.
class GField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? hint;

  const GField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GMono(label),
        const SizedBox(height: 6),
        Container(
          height: GSpacing.actionBtn,
          padding: const EdgeInsets.symmetric(horizontal: GSpacing.blockV),
          decoration: BoxDecoration(
            color: GColors.white,
            border: Border.all(color: GColors.ink, width: GSpacing.border),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: GText.field,
            cursorColor: GColors.blue,
            cursorWidth: GSpacing.caret,
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: GText.field.copyWith(color: GColors.grey3),
            ),
          ),
        ),
      ],
    );
  }
}
