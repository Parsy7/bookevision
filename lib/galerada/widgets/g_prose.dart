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
///
/// Si se pasa [onSeleccionCambia], el texto se vuelve seleccionable: en vez
/// del menú nativo, cada cambio de selección avisa a quien la use con el
/// fragmento elegido, para que muestre su propio botón flotante "Preguntar a
/// la IA" — el menú nativo de copiar/seleccionar todo se suprime para no
/// duplicar affordances. La notificación va por `onSelectionChanged`, no por
/// `contextMenuBuilder`: ese último solo se invoca cuando Flutter decide que
/// toca *mostrar* el menú (p.ej. al soltar el dedo tras arrastrar), no en
/// cada cambio, así que depender de él dejaba el botón sin aparecer en buena
/// parte de los gestos de selección reales. Sin `onSeleccionCambia` (vista
/// previa, confirmación) no hay selección: el texto ahí es la versión ya
/// compuesta, no el capítulo original literal, así que un fragmento suyo no
/// tiene por qué localizarse dentro del original para convertirse en
/// sugerencia.
class GProseFlow extends StatefulWidget {
  final String text;
  final void Function(String seleccion)? onSeleccionCambia;
  final VoidCallback? onSeleccionVacia;

  const GProseFlow(this.text, {super.key, this.onSeleccionCambia, this.onSeleccionVacia});

  @override
  State<GProseFlow> createState() => _GProseFlowState();
}

class _GProseFlowState extends State<GProseFlow> {
  @override
  Widget build(BuildContext context) {
    final parrafos = widget.text.split(RegExp(r'\n{2,}'))
      ..removeWhere((p) => p.trim().isEmpty);
    final columna = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < parrafos.length; i++) ...[
          if (i > 0) const SizedBox(height: GSpacing.gap),
          GProse(parrafos[i], number: i + 1),
        ],
      ],
    );

    final onSeleccionCambia = widget.onSeleccionCambia;
    if (onSeleccionCambia == null) return columna;

    return SelectionArea(
      onSelectionChanged: (content) {
        final texto = content?.plainText.trim();
        if (texto == null || texto.isEmpty) {
          widget.onSeleccionVacia?.call();
        } else {
          onSeleccionCambia(texto);
        }
      },
      // Sin barra nativa: el propio botón flotante "Preguntar a la IA" es la
      // única affordance sobre la selección.
      contextMenuBuilder: (context, selectableRegionState) => const SizedBox.shrink(),
      child: columna,
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

  /// Con esto puesto, arrastrar el dedo tras la pulsación larga selecciona
  /// texto en vez de entrar en edición, y seleccionar dentro del campo ya en
  /// modo edición también avisa — en ambos casos aparece el mismo botón
  /// flotante "Preguntar a la IA" que ya usan "Ver original" y "Vista previa".
  final void Function(String seleccion)? onSeleccionCambia;
  final VoidCallback? onSeleccionVacia;

  const GProseBlock({
    super.key,
    required this.text,
    required this.start,
    required this.end,
    this.number,
    this.onEditing,
    this.onSeleccionCambia,
    this.onSeleccionVacia,
  });

  @override
  State<GProseBlock> createState() => _GProseBlockState();
}

class _GProseBlockState extends State<GProseBlock> {
  /// Cuánto tiene que moverse el dedo tras la pulsación larga para que
  /// cuente como "seleccionar texto" en vez de "entrar a editar". Por debajo,
  /// aunque haya temblado un poco, sigue siendo una pulsación larga normal.
  static const _umbralArrastre = 8.0;

  bool _editing = false;
  bool _showingOriginal = false;
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _textKey = GlobalKey();
  GProseEditActions? _acciones;

  Offset? _inicioPulsacion;
  int? _inicioSeleccion;
  int? _finSeleccion;
  bool _seleccionando = false;

  TextStyle get _style => GText.prose;
  StrutStyle get _strut =>
      StrutStyle.fromTextStyle(_style, forceStrutHeight: true);

  String get _blockId => 'b_${widget.start}_${widget.end}';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSeleccionEnCampo);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSeleccionEnCampo);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Ya en modo edición, seleccionar con las asas nativas del campo también
  /// avisa — mismo botón flotante que el arrastre en modo lectura, en vez de
  /// meterlo en el menú nativo de Cortar/Copiar/Pegar (que además de él ya
  /// puede llevar 4 botones, y uno más ahí se recorta a una segunda página
  /// fácil de no ver).
  void _onSeleccionEnCampo() {
    if (!_editing) return;
    final seleccion =
        _controller.selection.textInside(_controller.text).trim();
    if (seleccion.isEmpty) {
      widget.onSeleccionVacia?.call();
    } else {
      widget.onSeleccionCambia?.call(seleccion);
    }
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

  void _onLongPressStart(Offset globalPosition) {
    _inicioPulsacion = globalPosition;
    _inicioSeleccion = null;
    _finSeleccion = null;
    // Una pulsación nueva invalida cualquier selección (y botón) anterior.
    if (_seleccionando) {
      setState(() => _seleccionando = false);
      widget.onSeleccionVacia?.call();
    }
  }

  /// Si el dedo se mueve más que el umbral, esto deja de ser "pulsación larga
  /// para editar" y pasa a ser "arrastre para seleccionar": se resalta en
  /// vivo el fragmento entre el punto de partida y el dedo actual.
  void _onLongPressMoveUpdate(Offset globalPosition, String mostrado) {
    final inicio = _inicioPulsacion;
    if (inicio == null) return;

    if (!_seleccionando) {
      if ((globalPosition - inicio).distance < _umbralArrastre) return;
      HapticFeedback.selectionClick();
      setState(() {
        _seleccionando = true;
        _inicioSeleccion = _caretAt(inicio, mostrado);
        _finSeleccion = _caretAt(globalPosition, mostrado);
      });
      return;
    }
    setState(() => _finSeleccion = _caretAt(globalPosition, mostrado));
  }

  void _onLongPressEnd(ManualEdit? edit, String mostrado) {
    if (_seleccionando) {
      final ini = _inicioSeleccion, fin = _finSeleccion;
      _inicioPulsacion = null;
      final desde = (ini != null && fin != null) ? (ini < fin ? ini : fin) : null;
      final hasta = (ini != null && fin != null) ? (ini < fin ? fin : ini) : null;
      final fragmento =
          (desde != null && hasta != null) ? mostrado.substring(desde, hasta).trim() : '';
      if (fragmento.isEmpty) {
        setState(() {
          _seleccionando = false;
          _inicioSeleccion = null;
          _finSeleccion = null;
        });
        widget.onSeleccionVacia?.call();
      } else {
        // El resaltado se queda a la vista mientras el botón flotante espera
        // el toque — desaparece al empezar una edición o una nueva selección.
        widget.onSeleccionCambia?.call(fragmento);
      }
      return;
    }
    final inicio = _inicioPulsacion;
    _inicioPulsacion = null;
    if (inicio != null) _startEdit(edit, inicio);
  }

  void _startEdit(ManualEdit? edit, Offset globalPosition) {
    widget.onSeleccionVacia?.call();
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
    widget.onSeleccionVacia?.call();
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
              ? BoxDecoration(
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
      onLongPressStart: (d) => _onLongPressStart(d.globalPosition),
      onLongPressMoveUpdate: (d) => _onLongPressMoveUpdate(d.globalPosition, mostrado),
      onLongPressEnd: (_) => _onLongPressEnd(edit, mostrado),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(right: GSpacing.caretGutter),
        child: _seleccionando
            ? _textoResaltado(mostrado)
            : Text(mostrado, key: _textKey, style: _style, strutStyle: _strut),
      ),
    );
  }

  /// El mismo texto que `_lectura`, pero con el tramo entre el inicio y el
  /// dedo actual resaltado — sin tocar el estilo base ni el strut, para no
  /// recomponer la línea bajo el dedo mientras se arrastra.
  Widget _textoResaltado(String mostrado) {
    final ini = _inicioSeleccion, fin = _finSeleccion;
    if (ini == null || fin == null) {
      return Text(mostrado, key: _textKey, style: _style, strutStyle: _strut);
    }
    final desde = ini < fin ? ini : fin;
    final hasta = ini < fin ? fin : ini;
    return Text.rich(
      TextSpan(
        style: _style,
        children: [
          TextSpan(text: mostrado.substring(0, desde)),
          TextSpan(
            text: mostrado.substring(desde, hasta),
            style: TextStyle(backgroundColor: GColors.blue.withValues(alpha: 0.22)),
          ),
          TextSpan(text: mostrado.substring(hasta)),
        ],
      ),
      key: _textKey,
      strutStyle: _strut,
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
      // Menú nativo de Cortar/Copiar/Pegar de siempre, sin tocar: "Preguntar
      // a la IA" va en el botón flotante (ver _onSeleccionEnCampo), no aquí.
    );
  }

  /// Ver original | Ver modificado | Restaurar, como en la pantalla 06.
  Widget _chips() {
    return Wrap(
      spacing: GSpacing.chipGap,
      runSpacing: GSpacing.chipGap,
      children: [
        GChip('Ver original',
            filled: _showingOriginal,
            onTap: () => setState(() => _showingOriginal = true)),
        GChip('Ver modificado',
            filled: !_showingOriginal,
            onTap: () => setState(() => _showingOriginal = false)),
        GChip('Restaurar', color: GColors.red, onTap: _restore),
      ],
    );
  }
}
