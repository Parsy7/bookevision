import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/manual_edit.dart';
import '../services/review_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Bloque de prosa libre del capítulo. Pulsación larga para editarlo a mano
/// (equivale al doble toque del HTML). La edición ocurre **en el mismo sitio y
/// con el mismo tamaño**: el texto se vuelve editable tal cual, sin cambiar la
/// altura ni desplazar la vista. Si está editado, muestra un conmutador
/// ver original / ver modificado / restaurar.
class ProseBlock extends StatefulWidget {
  final String text; // texto original del hueco
  final int start;
  final int end;

  const ProseBlock({
    super.key,
    required this.text,
    required this.start,
    required this.end,
  });

  @override
  State<ProseBlock> createState() => _ProseBlockState();
}

class _ProseBlockState extends State<ProseBlock> {
  bool _editing = false;
  bool _showingOriginal = false;
  final _controller = TextEditingController();
  final _focus = FocusNode();

  String get _blockId => 'b_${widget.start}_${widget.end}';

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit(ManualEdit? edit) {
    _controller.text = edit?.value ?? widget.text;
    setState(() {
      _editing = true;
      _showingOriginal = false;
    });
    // Enfoca tras el frame, sin forzar ningún scroll: el bloque se queda donde
    // está. El teclado solo revelará el cursor si hiciera falta (comportamiento
    // estándar), pero no se recoloca la vista.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _save() {
    context
        .read<ReviewSession>()
        .setManualEdit(widget.start, widget.end, widget.text, _controller.text);
    _focus.unfocus();
    setState(() => _editing = false);
  }

  void _restore() {
    context.read<ReviewSession>().removeManualEdit(_blockId);
    _focus.unfocus();
    setState(() {
      _editing = false;
      _showingOriginal = false;
    });
  }

  void _cancel() {
    _focus.unfocus();
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final edit = context.watch<ReviewSession>().manualEdits[_blockId];
    final changed = edit != null;

    if (_editing) return _editor();

    final shown =
        (edit != null && !_showingOriginal) ? edit.value : widget.text;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(left: changed ? AppSpacing.card : 0),
      decoration: changed
          ? const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.primary, width: 3),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _startEdit(edit),
            behavior: HitTestBehavior.opaque,
            child: Text(shown, style: AppText.readerText),
          ),
          if (changed) ...[
            const SizedBox(height: AppSpacing.gapSm),
            _viewSwitch(),
          ],
        ],
      ),
    );
  }

  /// Editor en el sitio: el campo usa el mismo estilo y crece con el contenido,
  /// así que ocupa prácticamente lo mismo que el texto. Sin tarjeta, sin
  /// etiqueta, sin auto-scroll: la vista no salta.
  Widget _editor() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: AppSpacing.card),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focus,
            style: AppText.readerText,
            cursorColor: AppColors.primary,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: AppSpacing.gapSm),
          Row(
            children: [
              _chip('Guardar', primary: true, onTap: _save),
              const SizedBox(width: AppSpacing.gapSm),
              _chip('Cancelar', onTap: _cancel),
              const Spacer(),
              _chip('Restaurar', onTap: _restore),
            ],
          ),
        ],
      ),
    );
  }

  Widget _viewSwitch() {
    return Wrap(
      spacing: AppSpacing.gapSm,
      runSpacing: AppSpacing.gapSm,
      children: [
        _chip('Ver original', primary: _showingOriginal,
            onTap: () => setState(() => _showingOriginal = true)),
        _chip('Ver modificado', primary: !_showingOriginal,
            onTap: () => setState(() => _showingOriginal = false)),
        _chip('Restaurar original', onTap: _restore),
      ],
    );
  }

  Widget _chip(String label, {bool primary = false, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.sm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: primary ? AppColors.primary : AppColors.bgElevated,
          borderRadius: AppRadius.sm,
        ),
        child: Text(
          label,
          style: AppText.caption.copyWith(
            color: primary ? AppColors.textInverse : AppColors.text,
          ),
        ),
      ),
    );
  }
}
