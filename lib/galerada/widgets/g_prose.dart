import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/manual_edit.dart';
import '../../services/review_session.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import 'g_bits.dart';

/// Acciones del bloque que se está editando, para que la pantalla las pinte en
/// la barra inferior. Dentro no pueden ir: un bloque puede ser mucho más alto
/// que la pantalla y los botones quedarían fuera de vista.
class GProseEditActions {
  final VoidCallback guardar;
  final VoidCallback cancelar;

  const GProseEditActions({required this.guardar, required this.cancelar});
}

/// Prosa de solo lectura con su número de párrafo en el margen. La usan la
/// vista previa, la confirmación y el capítulo original.
class GProse extends StatelessWidget {
  final String text;
  final int? number;

  const GProse(this.text, {super.key, this.number});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: GSpacing.proseIndent),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(text, style: GText.prose),
          if (number != null)
            Positioned(
              left: -GSpacing.proseIndent,
              top: 4,
              child: Text('¶$number', style: GText.paragraphNo),
            ),
        ],
      ),
    );
  }
}

/// Capítulo entero de solo lectura, con un párrafo numerado por línea en
/// blanco. Lo usan la vista previa, la confirmación y el capítulo original,
/// donde no se edita y por tanto partir el texto sale gratis.
class GProseFlow extends StatelessWidget {
  final String text;

  const GProseFlow(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final parrafos = text.split(RegExp(r'\n{2,}'))
      ..removeWhere((p) => p.trim().isEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < parrafos.length; i++) ...[
          if (i > 0) const SizedBox(height: GSpacing.gap),
          GProse(parrafos[i], number: i + 1),
        ],
      ],
    );
  }
}

/// Bloque de prosa editable del lector. Pulsación larga para editarlo a mano.
///
/// Conserva lo que costó afinar en el diseño anterior, porque es lo que hace
/// que editar no maree:
///
/// - El cursor cae en el carácter pulsado, no al final. Si la selección no es
///   válida al enfocar, `EditableText` la manda al final y luego desplaza el
///   lector para enseñarla: en un bloque largo eso arrastra la vista páginas
///   enteras.
/// - Leer y editar miden **igual**: mismo estilo cerrado, mismo strut, y el
///   texto en lectura reserva el hueco del cursor que `RenderEditable` le
///   quita al ancho de línea. Así no se recompone bajo el dedo.
/// - La caja exterior no depende del modo. La franja roja de 3dp de un bloque
///   editado se come 3dp del sangrado, así que el texto cae en el mismo sitio
///   esté editado o no.
class GProseBlock extends StatefulWidget {
  final String text;
  final int start;
  final int end;
  final int? number;

  /// Aviso de entrada y salida del modo edición, con las mismas acciones a la
  /// ida y a la vuelta para que la pantalla sepa quién avisa.
  final void Function(GProseEditActions acciones, {required bool activa})?
      onEditing;

  const GProseBlock({
    super.key,
    required this.text,
    required this.start,
    required this.end,
    this.number,
    this.onEditing,
  });

  @override
  State<GProseBlock> createState() => _GProseBlockState();
}

class _GProseBlockState extends State<GProseBlock> {
  bool _editing = false;
  bool _showingOriginal = false;
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _textKey = GlobalKey();
  GProseEditActions? _acciones;

  TextStyle get _style => GText.prose;
  StrutStyle get _strut =>
      StrutStyle.fromTextStyle(_style, forceStrutHeight: true);

  String get _blockId => 'b_${widget.start}_${widget.end}';

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  int _clamp(int v, int max) => v < 0 ? 0 : (v > max ? max : v);

  /// Carácter bajo el dedo. Se lo pregunta al `Text` ya medido: rehacer el
  /// layout con un `TextPainter` costaría cientos de milisegundos en un bloque
  /// con el capítulo entero.
  int _caretAt(Offset globalPosition, String text) {
    final box = _textKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return 0;
    if (box is RenderParagraph) {
      return _clamp(
        box.getPositionForOffset(box.globalToLocal(globalPosition)).offset,
        text.length,
      );
    }
    return 0;
  }

  void _startEdit(ManualEdit? edit, Offset globalPosition) {
    final mostrado =
        (edit != null && !_showingOriginal) ? edit.value : widget.text;
    final valor = edit?.value ?? widget.text;
    final caret = _clamp(_caretAt(globalPosition, mostrado), valor.length);

    _controller.value = TextEditingValue(
      text: valor,
      selection: TextSelection.collapsed(offset: caret),
    );
    HapticFeedback.selectionClick();
    setState(() {
      _editing = true;
      _showingOriginal = false;
    });
    final acciones =
        GProseEditActions(guardar: _save, cancelar: _cancel);
    _acciones = acciones;
    widget.onEditing?.call(acciones, activa: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _terminar() {
    _focus.unfocus();
    setState(() => _editing = false);
    final acciones = _acciones;
    _acciones = null;
    if (acciones != null) widget.onEditing?.call(acciones, activa: false);
  }

  void _save() {
    if (!_editing) return;
    context
        .read<ReviewSession>()
        .setManualEdit(widget.start, widget.end, widget.text, _controller.text);
    _terminar();
  }

  void _cancel() {
    if (!_editing) return;
    _terminar();
  }

  void _restore() {
    context.read<ReviewSession>().removeManualEdit(_blockId);
    if (!_editing) {
      setState(() => _showingOriginal = false);
      return;
    }
    _showingOriginal = false;
    _terminar();
  }

  @override
  Widget build(BuildContext context) {
    final edit = context.watch<ReviewSession>().manualEdits[_blockId];
    final editado = edit != null;
    final mostrado = (editado && !_showingOriginal) ? edit.value : widget.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          // La franja se come 3dp del sangrado: el texto cae en el mismo sitio
          // esté el bloque editado o no.
          padding: EdgeInsets.only(
            left: editado
                ? GSpacing.proseIndent - GSpacing.stripe
                : GSpacing.proseIndent,
          ),
          decoration: editado
              ? const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: GColors.red, width: GSpacing.stripe),
                  ),
                )
              : null,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_editing) _campo() else _lectura(edit, mostrado),
              if (widget.number != null)
                Positioned(
                  left: editado
                      ? GSpacing.stripe - GSpacing.proseIndent
                      : -GSpacing.proseIndent,
                  top: 4,
                  child: Text('¶${widget.number}', style: GText.paragraphNo),
                ),
            ],
          ),
        ),
        if (!_editing && editado) ...[
          const SizedBox(height: GSpacing.gapSm),
          Padding(
            padding: const EdgeInsets.only(left: GSpacing.proseIndent),
            child: _chips(),
          ),
        ],
      ],
    );
  }

  Widget _lectura(ManualEdit? edit, String mostrado) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (d) => _startEdit(edit, d.globalPosition),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(right: GSpacing.caretGutter),
        child: Text(mostrado,
            key: _textKey, style: _style, strutStyle: _strut),
      ),
    );
  }

  Widget _campo() {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      style: _style,
      strutStyle: _strut,
      cursorColor: GColors.blue,
      cursorWidth: GSpacing.caret,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      maxLines: null,
      scrollPadding: const EdgeInsets.all(GSpacing.gapSm),
      decoration: const InputDecoration(
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
      ),
    );
  }

  /// Ver original | Ver modificado | Restaurar, como en la pantalla 06.
  Widget _chips() {
    Widget chip(String label, {bool activo = false, Color color = GColors.ink, required VoidCallback onTap}) {
      return InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: activo ? color : null,
            border: Border.all(color: color, width: GSpacing.border),
          ),
          child: GMono(label, color: activo ? GColors.onInk : color),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        chip('Ver original',
            activo: _showingOriginal,
            onTap: () => setState(() => _showingOriginal = true)),
        chip('Ver modificado',
            activo: !_showingOriginal,
            onTap: () => setState(() => _showingOriginal = false)),
        chip('Restaurar', color: GColors.red, onTap: _restore),
      ],
    );
  }
}
