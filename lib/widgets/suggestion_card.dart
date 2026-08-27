import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/answer.dart';
import '../models/suggestion.dart';
import '../services/review_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'app_card.dart';
import 'app_input.dart';
import 'app_pill.dart';

/// Tarjeta de una sugerencia (sustitución o inserción), con sus opciones y el
/// editor de versión propia. Réplica funcional del `cardHTML` del HTML.
class SuggestionCard extends StatelessWidget {
  final int index;
  const SuggestionCard({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ReviewSession>();
    final s = session.suggestionAt(index);
    final a = session.answerAt(index);
    final resolved = session.isResolved(index);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _head(s, resolved),
          const SizedBox(height: AppSpacing.gapMd),
          if ((s.reason ?? '').isNotEmpty) ...[
            _why(s.reason!),
            const SizedBox(height: AppSpacing.gapMd),
          ],
          if (s.isReplace)
            _replaceBody(context, s, a)
          else
            _insertBody(context, s, a),
        ],
      ),
    );
  }

  Widget _head(Suggestion s, bool resolved) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppPill(
              label: s.isReplace ? '↔ Sustitución' : '＋ Inserción',
              color: s.isReplace ? AppColors.pillBg : AppColors.bgElevated,
            ),
            const Spacer(),
            AppPill(
              label: resolved ? 'Resuelta' : 'Pendiente',
              color: resolved ? AppColors.success : AppColors.bgElevated,
              textColor: resolved ? AppColors.textInverse : AppColors.textMuted,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.gapSm),
        Text('${index + 1}. ${s.title ?? 'Sugerencia'}',
            style: AppText.titleSection),
        if ((s.location ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.gapXs),
          Text(s.location!, style: AppText.caption),
        ],
      ],
    );
  }

  Widget _why(String reason) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.card),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: AppRadius.sm,
        ),
        child: Text(reason, style: AppText.subtitle),
      );

  // ---------- Sustitución ----------

  Widget _replaceBody(BuildContext context, Suggestion s, Answer a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Texto original'),
        _box(s.original ?? ''),
        const SizedBox(height: AppSpacing.gapMd),
        _label('Propuesta'),
        _box(s.proposed ?? '', suggested: true),
        const SizedBox(height: AppSpacing.gapMd),
        _choices(context, [
          _Choice('Mantener original', Choice.original),
          _Choice('Aceptar sugerencia', Choice.proposed),
          _Choice('Escribir yo', Choice.custom),
        ], a),
        if (a.choice == Choice.custom)
          _customArea(context, a, insert: false),
      ],
    );
  }

  // ---------- Inserción ----------

  Widget _insertBody(BuildContext context, Suggestion s, Answer a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Posición de la inserción'),
        _positions(context, a),
        const SizedBox(height: AppSpacing.gapMd),
        _label('Punto de inserción'),
        _insertContext(s, a),
        const SizedBox(height: AppSpacing.gapMd),
        _label('Texto propuesto para añadir'),
        _box(s.proposed ?? '', suggested: true),
        const SizedBox(height: AppSpacing.gapMd),
        _choices(context, [
          _Choice('No añadir nada', Choice.original),
          _Choice('Añadir sugerencia', Choice.proposed),
          _Choice('Escribir lo que añadiré', Choice.custom),
        ], a),
        if (a.choice == Choice.custom)
          _customArea(context, a, insert: true),
      ],
    );
  }

  Widget _positions(BuildContext context, Answer a) {
    final mode = a.insertPosition ?? InsertPosition.between;
    Widget seg(String label, String value) {
      final active = mode == value;
      return Expanded(
        child: InkWell(
          onTap: () =>
              context.read<ReviewSession>().setInsertPosition(index, value),
          borderRadius: AppRadius.sm,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
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
        ),
      );
    }

    return Row(
      children: [
        seg('Antes', InsertPosition.before),
        seg('Entre', InsertPosition.between),
        seg('Después', InsertPosition.after),
      ],
    );
  }

  Widget _insertContext(Suggestion s, Answer a) {
    final mode = a.insertPosition ?? InsertPosition.between;
    final prev = (s.previous ?? '').isNotEmpty ? _box(s.previous!) : null;
    final next = (s.next ?? '').isNotEmpty ? _box(s.next!) : null;
    final slot = _slot();

    final children = <Widget>[];
    void add(Widget? w) {
      if (w == null) return;
      if (children.isNotEmpty) children.add(const SizedBox(height: AppSpacing.gapSm));
      children.add(w);
    }

    if (mode == InsertPosition.before) {
      add(slot);
      add(prev);
      add(next);
    } else if (mode == InsertPosition.after) {
      add(prev);
      add(next);
      add(slot);
    } else {
      add(prev);
      add(slot);
      add(next);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _slot() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: AppRadius.sm,
          border: Border.all(color: AppColors.primary, width: 1),
        ),
        child: Text('＋ AÑADIR CONTENIDO AQUÍ',
            style: AppText.caption.copyWith(color: AppColors.primary)),
      );

  // ---------- Comunes ----------

  Widget _choices(BuildContext context, List<_Choice> options, Answer a) {
    return Wrap(
      spacing: AppSpacing.gapSm,
      runSpacing: AppSpacing.gapSm,
      children: options.map((o) {
        final active = a.choice == o.value;
        return InkWell(
          onTap: () => context.read<ReviewSession>().setChoice(index, o.value),
          borderRadius: AppRadius.sm,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.bgCard,
              borderRadius: AppRadius.sm,
              border: Border.all(
                color: active ? AppColors.primary : AppColors.borderStrong,
                width: 1,
              ),
            ),
            child: Text(
              o.label,
              style: AppText.label.copyWith(
                color: active ? AppColors.textInverse : AppColors.text,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _customArea(BuildContext context, Answer a, {required bool insert}) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.gapMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.gapSm,
            runSpacing: AppSpacing.gapSm,
            children: [
              if (!insert) _fill(context, 'Usar original', 'original'),
              _fill(context, 'Usar sugerencia', 'proposed'),
              _fill(context, 'Empezar de cero', 'blank'),
            ],
          ),
          const SizedBox(height: AppSpacing.gapSm),
          _CustomEditor(
            value: a.custom,
            hint: insert
                ? 'Escribe únicamente el texto nuevo que quieres insertar…'
                : 'Escribe aquí tu versión…',
            onChanged: (t) =>
                context.read<ReviewSession>().setCustom(index, t),
          ),
        ],
      ),
    );
  }

  Widget _fill(BuildContext context, String label, String mode) {
    return InkWell(
      onTap: () => context.read<ReviewSession>().fillCustom(index, mode),
      borderRadius: AppRadius.sm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: AppRadius.sm,
        ),
        child: Text(label, style: AppText.caption.copyWith(color: AppColors.text)),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.gapXs),
        child: Text(text.toUpperCase(), style: AppText.caption),
      );

  Widget _box(String text, {bool suggested = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.card),
        decoration: BoxDecoration(
          color: suggested ? AppColors.bgCard : AppColors.bgElevated,
          borderRadius: AppRadius.sm,
          border: suggested
              ? Border.all(color: AppColors.primary, width: 1)
              : null,
        ),
        child: Text(text, style: AppText.bodyText),
      );
}

class _Choice {
  final String label;
  final String value;
  const _Choice(this.label, this.value);
}

/// Editor de versión propia con controlador propio (mantiene foco y cursor).
/// Se sincroniza si el valor cambia por fuera (botones de relleno, reset).
class _CustomEditor extends StatefulWidget {
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  const _CustomEditor({
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  @override
  State<_CustomEditor> createState() => _CustomEditorState();
}

class _CustomEditorState extends State<_CustomEditor> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  /// Último texto ya notificado hacia arriba. Sirve para distinguir un cambio
  /// de texto de un simple movimiento del cursor o de la selección.
  late String _ultimoTexto = widget.value;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    // El controlador avisa de cualquier cambio de su valor, y el valor incluye
    // la selección: mover el cursor o arrastrar para seleccionar una frase
    // también dispara esto. Reenviarlo repintaba el capítulo entero (y
    // reiniciaba el autosave) en cada fotograma del arrastre, que es lo que
    // hacía que el gesto de seleccionar se atascara.
    if (_controller.text == _ultimoTexto) return;
    _ultimoTexto = _controller.text;
    widget.onChanged(_controller.text);
  }

  @override
  void didUpdateWidget(covariant _CustomEditor old) {
    super.didUpdateWidget(old);
    if (widget.value == _controller.text) return;
    // Cambio externo (rellenar desde el original o la sugerencia, empezar de
    // cero, un reset). Se actualiza primero `_ultimoTexto` para no reenviar
    // hacia arriba lo que acaba de llegar de arriba.
    //
    // La selección se fija a mano: el setter `controller.text =` la deja
    // inválida, y con el campo enfocado EditableText resuelve eso mandando el
    // cursor al final del texto por su cuenta.
    _ultimoTexto = widget.value;
    _controller.value = TextEditingValue(
      text: widget.value,
      selection: TextSelection.collapsed(offset: widget.value.length),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppInput(
      controller: _controller,
      hintText: widget.hint,
      keyboardType: TextInputType.multiline,
      maxLines: 10,
      minLines: 3,
    );
  }
}
