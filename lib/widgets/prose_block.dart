import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/manual_edit.dart';
import '../services/review_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'app_input.dart';

/// Bloque de prosa libre del capítulo. Pulsación larga para editarlo a mano
/// (equivale al doble toque del HTML). Si está editado, muestra un conmutador
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
  late final TextEditingController _controller = TextEditingController();

  String get _blockId => 'b_${widget.start}_${widget.end}';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEdit(ManualEdit? edit) {
    _controller.text = edit?.value ?? widget.text;
    setState(() => _editing = true);
  }

  void _save() {
    context
        .read<ReviewSession>()
        .setManualEdit(widget.start, widget.end, widget.text, _controller.text);
    setState(() {
      _editing = false;
      _showingOriginal = false;
    });
  }

  void _restore() {
    context.read<ReviewSession>().removeManualEdit(_blockId);
    setState(() {
      _editing = false;
      _showingOriginal = false;
    });
  }

  void _cancel() => setState(() => _editing = false);

  @override
  Widget build(BuildContext context) {
    final edit = context.watch<ReviewSession>().manualEdits[_blockId];
    final changed = edit != null;

    if (_editing) return _buildEditor();

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

  Widget _viewSwitch() {
    return Wrap(
      spacing: AppSpacing.gapSm,
      runSpacing: AppSpacing.gapSm,
      children: [
        _miniToggle('Ver original', _showingOriginal,
            () => setState(() => _showingOriginal = true)),
        _miniToggle('Ver modificado', !_showingOriginal,
            () => setState(() => _showingOriginal = false)),
        _miniToggle('Restaurar original', false, _restore),
      ],
    );
  }

  Widget _miniToggle(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.sm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.bgElevated,
          borderRadius: AppRadius.sm,
        ),
        child: Text(
          label,
          style: AppText.caption.copyWith(
            color: active ? AppColors.textInverse : AppColors.text,
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.borderStrong, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Editar bloque', style: AppText.label),
          const SizedBox(height: AppSpacing.gapSm),
          AppInput(
            controller: _controller,
            keyboardType: TextInputType.multiline,
            maxLines: 12,
            minLines: 4,
          ),
          const SizedBox(height: AppSpacing.gapMd),
          Row(
            children: [
              Expanded(
                child: AppButton(label: 'Guardar bloque', onPressed: _save),
              ),
              const SizedBox(width: AppSpacing.gapSm),
              Expanded(
                child: AppButton(
                  label: 'Cancelar',
                  variant: AppButtonVariant.cancel,
                  onPressed: _cancel,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapSm),
          AppButton(
            label: 'Restaurar original',
            variant: AppButtonVariant.ghost,
            onPressed: _restore,
          ),
        ],
      ),
    );
  }
}
