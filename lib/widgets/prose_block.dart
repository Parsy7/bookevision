import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/manual_edit.dart';
import '../services/review_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// Bloque de prosa libre del capítulo. Pulsación larga para editarlo a mano
/// (equivale al doble toque del HTML).
///
/// La edición ocurre **en el mismo sitio, con la misma caja y el cursor donde
/// has pulsado**, igual que el `contentEditable` del HTML. Tres cosas lo
/// consiguen, y las tres importan:
///
/// 1. **El cursor va al carácter pulsado, no al final.** Si la selección no es
///    válida al enfocar, `EditableText` la manda al final del texto y acto
///    seguido desplaza el `Scrollable` del lector para enseñar ese cursor: en
///    un bloque largo eso arrastra la vista páginas enteras y se pierde la
///    frase que se iba a editar. Fijando la selección **antes** de enfocar, el
///    lector solo se mueve lo justo para que el cursor no quede bajo el
///    teclado.
/// 2. **Leer y editar miden exactamente igual.** El `Text` y el `TextField`
///    comparten estilo (con `inherit: false`, para que no se cuele el estilo
///    por defecto del contexto, que es distinto en cada uno y traería su
///    propio `letterSpacing`) y strut, y el `Text` reserva a su derecha el
///    hueco del cursor ([AppSpacing.caretGutter]) que `RenderEditable` le
///    quita al ancho de línea. Así el texto rompe línea en el mismo sitio y no
///    se recompone bajo el dedo.
/// 3. **La caja exterior no depende del modo.** La franja y el sangrado son de
///    "bloque editado", no de "bloque en edición": entrar a editar no cambia
///    ni la altura ni el ancho útil. El modo edición se ve por el fondo, que
///    no ocupa espacio.
/// Acciones del bloque que se está editando, para que la pantalla las pinte
/// **fuera** de él. Dentro no pueden ir: un bloque de capítulo puede ser mucho
/// más alto que la pantalla, así que unos botones al final del bloque quedan
/// fuera de vista justo cuando hacen falta.
/// Solo Guardar y Cancelar: un tercer botón no cabe a lo ancho en un móvil
/// estrecho sin bajar de los 44dp de área táctil. Restaurar el original sigue
/// donde estaba, en el conmutador del bloque ya editado.
class ProseEditActions {
  final VoidCallback guardar;
  final VoidCallback cancelar;

  const ProseEditActions({required this.guardar, required this.cancelar});
}

class ProseBlock extends StatefulWidget {
  final String text; // texto original del hueco
  final int start;
  final int end;

  /// Aviso de entrada y salida del modo edición. Si se pasa, el bloque deja de
  /// pintar sus propios botones y espera que la pantalla los ponga en una barra
  /// fija; si no, los pinta debajo del texto para poder usarse suelto.
  ///
  /// Al salir se reenvían las **mismas** acciones que se enviaron al entrar,
  /// para que la pantalla distinga quién está avisando: si mientras editas un
  /// bloque empiezas a editar otro, el primero avisa de su salida *después* de
  /// que el segundo haya avisado de su entrada.
  final void Function(ProseEditActions acciones, {required bool activa})?
      onEditing;

  const ProseBlock({
    super.key,
    required this.text,
    required this.start,
    required this.end,
    this.onEditing,
  });

  @override
  State<ProseBlock> createState() => _ProseBlockState();
}

class _ProseBlockState extends State<ProseBlock> {
  bool _editing = false;
  bool _showingOriginal = false;
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// Sobre el `Text` de lectura: da la caja contra la que se mide en qué
  /// carácter se ha pulsado.
  final _textKey = GlobalKey();

  /// Las acciones que se enviaron a la pantalla al entrar en edición.
  ProseEditActions? _acciones;

  /// Estilo del bloque ya resuelto y **cerrado** (`inherit: false`).
  ///
  /// Sin cerrarlo, cada modo heredaría de un sitio distinto: `Text` completa
  /// lo que le falta con el `DefaultTextStyle` del contexto (`bodyMedium`) y
  /// `TextField` con `textTheme.bodyLarge`, que traen `letterSpacing`
  /// distintos y romperían línea en sitios distintos. Se parte del mismo
  /// `DefaultTextStyle` de siempre, así que el lector se ve exactamente igual
  /// que antes.
  TextStyle get _style => DefaultTextStyle.of(context)
      .style
      .merge(AppText.readerText)
      .copyWith(inherit: false);

  /// El strut que `EditableText` calcula solo para su campo. Dándoselo también
  /// al `Text`, las dos cajas miden idéntico.
  StrutStyle get _strut =>
      StrutStyle.fromTextStyle(_style, forceStrutHeight: true);

  String get _blockId => 'b_${widget.start}_${widget.end}';

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  int _clampOffset(int value, int max) =>
      value < 0 ? 0 : (value > max ? max : value);

  /// Carácter de [text] que hay bajo [globalPosition], medido sobre la misma
  /// caja que se está viendo.
  int _caretOffsetAt(Offset globalPosition, String text) {
    final box = _textKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return 0;
    final style = _style;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: box.size.width);
    final offset =
        painter.getPositionForOffset(box.globalToLocal(globalPosition)).offset;
    painter.dispose();
    return _clampOffset(offset, text.length);
  }

  void _startEdit(ManualEdit? edit, Offset globalPosition) {
    final shown = (edit != null && !_showingOriginal) ? edit.value : widget.text;
    final value = edit?.value ?? widget.text;
    final caret =
        _clampOffset(_caretOffsetAt(globalPosition, shown), value.length);

    // La selección se fija ANTES de que el campo exista: cuando reciba el foco
    // ya será válida y el cursor no saltará al final del bloque.
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: caret),
    );
    HapticFeedback.selectionClick();
    setState(() {
      _editing = true;
      _showingOriginal = false;
    });
    final acciones = ProseEditActions(guardar: _save, cancelar: _cancel);
    _acciones = acciones;
    widget.onEditing?.call(acciones, activa: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// Sale del modo edición y avisa a la pantalla de que su barra sobra.
  void _terminar() {
    _focus.unfocus();
    setState(() => _editing = false);
    final acciones = _acciones;
    _acciones = null;
    if (acciones != null) {
      widget.onEditing?.call(acciones, activa: false);
    }
  }

  void _save() {
    if (!_editing) return;
    context
        .read<ReviewSession>()
        .setManualEdit(widget.start, widget.end, widget.text, _controller.text);
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

  void _cancel() {
    if (!_editing) return;
    _terminar();
  }

  @override
  Widget build(BuildContext context) {
    final edit = context.watch<ReviewSession>().manualEdits[_blockId];
    final changed = edit != null;
    final shown = (changed && !_showingOriginal) ? edit.value : widget.text;

    return Container(
      width: double.infinity,
      // Franja y sangrado dependen solo de si el bloque está editado, nunca de
      // si se está editando: así entrar a editar no recoloca nada.
      padding: EdgeInsets.only(left: changed ? AppSpacing.card : 0),
      decoration: BoxDecoration(
        color: _editing ? AppColors.bgCard : null,
        border: changed
            ? const Border(
                left: BorderSide(color: AppColors.primary, width: 3),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_editing) _field() else _readable(edit, shown),
          if (_editing && widget.onEditing == null) ...[
            const SizedBox(height: AppSpacing.gapSm),
            _editTools(),
          ] else if (!_editing && changed) ...[
            const SizedBox(height: AppSpacing.gapSm),
            _viewSwitch(),
          ],
        ],
      ),
    );
  }

  /// Modo lectura. Ocupa todo el ancho (para que la pulsación larga valga en
  /// toda la línea) y reserva a la derecha el hueco del cursor.
  Widget _readable(ManualEdit? edit, String shown) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (d) => _startEdit(edit, d.globalPosition),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(right: AppSpacing.caretGutter),
        child: Text(
          shown,
          key: _textKey,
          style: _style,
          strutStyle: _strut,
        ),
      ),
    );
  }

  /// Modo edición: el mismo texto, en el mismo sitio y del mismo tamaño. Sin
  /// tarjeta, sin etiqueta, sin borde y sin auto-scroll propio.
  Widget _field() {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      style: _style,
      strutStyle: _strut,
      cursorColor: AppColors.primary,
      cursorWidth: AppSpacing.caret,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      maxLines: null,
      // Aire mínimo al revelar el cursor: cuanto más pequeño, menos se mueve
      // el lector al abrirse el teclado.
      scrollPadding: const EdgeInsets.all(AppSpacing.gapSm),
      decoration: const InputDecoration(
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
      ),
    );
  }

  Widget _editTools() {
    return Row(
      children: [
        _chip('Guardar', primary: true, onTap: _save),
        const SizedBox(width: AppSpacing.gapSm),
        _chip('Cancelar', onTap: _cancel),
        const Spacer(),
        _chip('Restaurar', onTap: _restore),
      ],
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
