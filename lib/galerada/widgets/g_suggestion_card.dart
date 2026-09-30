import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/answer.dart';
import '../../models/suggestion.dart';
import '../../services/review_session.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import 'g_actions.dart';
import 'g_bits.dart';
import 'g_card.dart';

/// Tarjeta de una sugerencia en «Galerada». Misma lógica que la tarjeta
/// anterior —las decisiones y el autoguardado no cambian— con la forma de una
/// prueba de imprenta: bordes de tinta, rejilla de acciones con teclas y la
/// marca roja «Propuesta» montada sobre la línea.
class GSuggestionCard extends StatelessWidget {
  final int index;

  /// Párrafo donde cae la sugerencia, para la cabecera («¶6», «¶3–¶4»).
  final String paragraphs;

  /// Seleccionar texto dentro de "Escribir yo" avisa con el fragmento, para
  /// que la pantalla muestre el botón flotante "Preguntar a la IA".
  final void Function(String seleccion)? onSeleccionCambia;
  final VoidCallback? onSeleccionVacia;

  const GSuggestionCard({
    super.key,
    required this.index,
    required this.paragraphs,
    this.onSeleccionCambia,
    this.onSeleccionVacia,
  });

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ReviewSession>();
    final s = session.suggestionAt(index);
    final a = session.answerAt(index);
    final resuelta = session.isResolved(index);

    return GCard(
      children: [
        GCardTop(
          left: '${s.isReplace ? '↔ Sustitución' : '＋ Inserción'} · $paragraphs',
          right: resuelta ? 'Resuelta' : 'Pendiente',
          pending: !resuelta,
        ),
        GCardTitle(
          number: index + 1,
          title: s.title ?? 'Sugerencia',
          keyword: _palabraClave(s.title ?? ''),
        ),
        if ((s.reason ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSpacing.card, 0, GSpacing.card, GSpacing.blockV),
            child: Text(s.reason!, style: GText.reason),
          ),
        if (s.isReplace) ..._sustitucion(context, s, a) else ..._insercion(context, s, a),
        _acciones(context, s, a),
        if (a.choice == Choice.custom)
          _Editor(
            index: index,
            insert: s.isInsert,
            onSeleccionCambia: onSeleccionCambia,
            onSeleccionVacia: onSeleccionVacia,
          ),
        if (a.choice == Choice.omit)
          const GWarn('El fragmento desaparecerá del capítulo. No se pone '
              'nada en su lugar.'),
      ],
    );
  }

  /// La palabra clave que va en cursiva roja: si el título es de una sola
  /// palabra, entera; si no, la última, que es donde cae el peso.
  String _palabraClave(String titulo) {
    final limpio = titulo.trim();
    if (limpio.isEmpty) return '';
    final partes = limpio.split(' ');
    return partes.length == 1 ? limpio : partes.last;
  }

  List<Widget> _sustitucion(BuildContext context, Suggestion s, Answer a) => [
        GBlock(s.original ?? '', kind: GBlockKind.strike),
        GBlock(s.proposed ?? '', kind: GBlockKind.proposal, mark: 'Propuesta'),
      ];

  List<Widget> _insercion(BuildContext context, Suggestion s, Answer a) {
    final modo = a.insertPosition ?? InsertPosition.between;
    final previo = (s.previous ?? '').isNotEmpty ? s.previous! : null;
    final siguiente = (s.next ?? '').isNotEmpty ? s.next! : null;

    final contexto = <Widget>[];
    void anadir(Widget? w) {
      if (w != null) contexto.add(w);
    }

    const hueco = GSlot();
    if (modo == InsertPosition.before) {
      anadir(hueco);
      anadir(previo == null ? null : GBlock(previo, kind: GBlockKind.context));
      anadir(siguiente == null ? null : GBlock(siguiente, kind: GBlockKind.context));
    } else if (modo == InsertPosition.after) {
      anadir(previo == null ? null : GBlock(previo, kind: GBlockKind.context));
      anadir(siguiente == null ? null : GBlock(siguiente, kind: GBlockKind.context));
      anadir(hueco);
    } else {
      anadir(previo == null ? null : GBlock(previo, kind: GBlockKind.context));
      anadir(hueco);
      anadir(siguiente == null ? null : GBlock(siguiente, kind: GBlockKind.context));
    }

    return [
      GSegmented(
        labels: const ['Antes', 'Entre', 'Después'],
        values: const [
          InsertPosition.before,
          InsertPosition.between,
          InsertPosition.after,
        ],
        selected: modo,
        onChanged: (v) =>
            context.read<ReviewSession>().setInsertPosition(index, v),
      ),
      ...contexto,
      GBlock(s.proposed ?? '', kind: GBlockKind.proposal, mark: 'Propuesta'),
    ];
  }

  Widget _acciones(BuildContext context, Suggestion s, Answer a) {
    void elegir(String v) => context.read<ReviewSession>().setChoice(index, v);

    if (s.isInsert) {
      return GActions([
        GAction(
          keyLetter: 'O',
          label: 'No añadir nada',
          active: a.choice == Choice.original,
          onTap: () => elegir(Choice.original),
        ),
        GAction(
          keyLetter: 'A',
          label: 'Añadir propuesta',
          active: a.choice == Choice.proposed,
          onTap: () => elegir(Choice.proposed),
        ),
        GAction(
          keyLetter: 'E',
          label: 'Escribir yo',
          tone: GTone.blue,
          full: true,
          active: a.choice == Choice.custom,
          onTap: () => elegir(Choice.custom),
        ),
      ]);
    }

    return GActions([
      GAction(
        keyLetter: 'O',
        label: 'Texto original',
        active: a.choice == Choice.original,
        onTap: () => elegir(Choice.original),
      ),
      GAction(
        keyLetter: 'A',
        label: 'Aceptar propuesta',
        active: a.choice == Choice.proposed,
        onTap: () => elegir(Choice.proposed),
      ),
      GAction(
        keyLetter: 'E',
        label: 'Escribir yo',
        tone: GTone.blue,
        active: a.choice == Choice.custom,
        onTap: () => elegir(Choice.custom),
      ),
      GAction(
        keyLetter: 'X',
        label: 'Eliminar original',
        tone: GTone.red,
        active: a.choice == Choice.omit,
        onTap: () => elegir(Choice.omit),
      ),
    ]);
  }
}

/// Editor de la versión propia: sobre blanco, con chips de relleno en mono y
/// un área de texto con borde azul.
class _Editor extends StatefulWidget {
  final int index;
  final bool insert;
  final void Function(String seleccion)? onSeleccionCambia;
  final VoidCallback? onSeleccionVacia;

  const _Editor({
    required this.index,
    required this.insert,
    this.onSeleccionCambia,
    this.onSeleccionVacia,
  });

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final TextEditingController _controller;
  late String _ultimoTexto;
  bool _avisoSeleccion = false;

  @override
  void initState() {
    super.initState();
    _ultimoTexto =
        context.read<ReviewSession>().answerAt(widget.index).custom;
    _controller = TextEditingController(text: _ultimoTexto)
      ..addListener(_onChanged)
      ..addListener(_onSeleccion);
  }

  void _onSeleccion() {
    final sel = _controller.selection;
    final texto = sel.isValid ? sel.textInside(_controller.text).trim() : '';
    if (texto.isNotEmpty) {
      _avisoSeleccion = true;
      widget.onSeleccionCambia?.call(texto);
    } else if (_avisoSeleccion) {
      _avisoSeleccion = false;
      widget.onSeleccionVacia?.call();
    }
  }

  void _onChanged() {
    // El controlador avisa también cuando solo cambia la selección. Reenviar
    // eso repintaría el capítulo entero mientras arrastras para seleccionar.
    if (_controller.text == _ultimoTexto) return;
    _ultimoTexto = _controller.text;
    context.read<ReviewSession>().setCustom(widget.index, _controller.text);
  }

  @override
  void dispose() {
    // Al cambiar de opción el editor desaparece: si tenía el botón a la
    // vista, se quita — después del frame, porque aquí el árbol está bloqueado.
    if (_avisoSeleccion) {
      final vacia = widget.onSeleccionVacia;
      WidgetsBinding.instance.addPostFrameCallback((_) => vacia?.call());
    }
    _controller.removeListener(_onChanged);
    _controller.removeListener(_onSeleccion);
    _controller.dispose();
    super.dispose();
  }

  void _rellenar(String modo) {
    final s = context.read<ReviewSession>();
    s.fillCustom(widget.index, modo);
    final valor = s.answerAt(widget.index).custom;
    _ultimoTexto = valor;
    // La selección se fija a mano: dejarla inválida hace que el cursor salte
    // al final por su cuenta.
    _controller.value = TextEditingValue(
      text: valor,
      selection: TextSelection.collapsed(offset: valor.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final externo = context.watch<ReviewSession>().answerAt(widget.index).custom;
    if (externo != _controller.text && externo != _ultimoTexto) {
      _ultimoTexto = externo;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.text != externo) {
          _controller.value = TextEditingValue(
            text: externo,
            selection: TextSelection.collapsed(offset: externo.length),
          );
        }
      });
    }

    Widget chip(String label, String modo) =>
        GChip(label, onTap: () => _rellenar(modo));

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GSpacing.card, vertical: GSpacing.blockV),
      decoration: BoxDecoration(
        color: GColors.white,
        border: Border(top: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: GSpacing.chipGap,
            runSpacing: GSpacing.chipGap,
            children: [
              if (!widget.insert) chip('Usar original', 'original'),
              chip('Usar propuesta', 'proposed'),
              chip('De cero', 'blank'),
            ],
          ),
          const SizedBox(height: GSpacing.barTop),
          Container(
            constraints: const BoxConstraints(minHeight: 90),
            decoration: BoxDecoration(
              color: GColors.white,
              border: Border.all(color: GColors.blue, width: GSpacing.border),
            ),
            padding: const EdgeInsets.all(GSpacing.barTop),
            child: TextField(
              controller: _controller,
              style: GText.block,
              cursorColor: GColors.blue,
              cursorWidth: GSpacing.caret,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              minLines: 3,
              scrollPadding: const EdgeInsets.all(GSpacing.gapSm),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: widget.insert
                    ? 'Escribe únicamente el texto nuevo que quieres insertar…'
                    : 'Escribe aquí tu versión…',
                hintStyle: GText.block.copyWith(color: GColors.grey3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
