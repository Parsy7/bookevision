import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/answer.dart';
import '../models/manual_edit.dart';
import '../models/review.dart';
import '../models/review_state.dart';
import '../models/suggestion.dart';
import 'api_service.dart';

enum LoadStatus { idle, loading, ready, error }

/// Estado del guardado, para el indicador y el botón "Guardar".
enum SaveStatus { idle, pending, saving, saved, error }

/// Desglose de decisiones para el progreso y la confirmación final.
class Counts {
  final int total, done, pending, accepted, originals, custom, manual;
  const Counts({
    required this.total,
    required this.done,
    required this.pending,
    required this.accepted,
    required this.originals,
    required this.custom,
    required this.manual,
  });
}

/// Sesión de revisión abierta: mantiene la revisión, las respuestas y las
/// ediciones manuales, aplica el motor de composición del texto y persiste el
/// estado en la API (autosave con debounce + guardado manual inmediato).
///
/// El motor (`currentText`, posiciones de inserción, `chosenText`) es una
/// réplica literal del revisor HTML: operaciones en coordenadas del capítulo
/// original, ordenadas de final a principio, con prioridades
/// manual 30 › replace 20 › insert 10.
class ReviewSession extends ChangeNotifier {
  ReviewSession({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  static const Duration _debounceDelay = Duration(milliseconds: 1500);

  Review? _review;
  List<Answer> _answers = [];
  Map<String, ManualEdit> _manualEdits = {};

  LoadStatus _loadStatus = LoadStatus.idle;
  SaveStatus _saveStatus = SaveStatus.idle;
  Object? _lastError;

  Timer? _debounce;
  bool _saving = false;
  bool _queued = false;

  // ---------- Getters de lectura ----------

  Review? get review => _review;
  List<Suggestion> get suggestions => _review?.suggestions ?? const [];
  List<Answer> get answers => _answers;
  Map<String, ManualEdit> get manualEdits => _manualEdits;

  LoadStatus get loadStatus => _loadStatus;
  SaveStatus get saveStatus => _saveStatus;
  Object? get lastError => _lastError;

  /// El botón "Guardar" solo tiene sentido si hay algo pendiente o falló.
  bool get canSave =>
      _saveStatus == SaveStatus.pending || _saveStatus == SaveStatus.error;

  Answer answerAt(int orden) => _answers[orden];
  Suggestion suggestionAt(int orden) => _review!.suggestions[orden];

  bool isResolved(int orden) => _answers[orden].isResolved;

  bool get allResolved =>
      _answers.isNotEmpty && _answers.every((a) => a.isResolved);

  // ---------- Carga ----------

  Future<void> load(String id) async {
    _loadStatus = LoadStatus.loading;
    _lastError = null;
    notifyListeners();
    try {
      final review = await _api.getRevision(id);
      final state = await _api.getEstado(id);

      final byOrden = {for (final a in state.answers) a.orden: a};
      _answers = List.generate(review.suggestions.length, (i) {
        final s = review.suggestions[i];
        final a = byOrden[i] ?? Answer(orden: i);
        a.insertPosition ??= s.isInsert ? InsertPosition.between : null;
        return a;
      });
      _manualEdits = Map.of(state.manualEdits);

      _review = review;
      _saveStatus = SaveStatus.saved;
      _loadStatus = LoadStatus.ready;
    } catch (e) {
      _lastError = e;
      _loadStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  // ---------- Mutadores (todos disparan autosave) ----------

  void setChoice(int orden, String choice) {
    final a = _answers[orden];
    a.choice = choice;
    if (choice == Choice.custom) {
      // deja el custom como esté (posiblemente vacío), igual que el HTML
    }
    _touch();
  }

  void setCustom(int orden, String text) {
    final a = _answers[orden];
    a.custom = text;
    a.choice = Choice.custom;
    _touch();
  }

  /// Rellena el campo personalizado desde el original, la propuesta, o vacío
  /// ('original' | 'proposed' | 'blank'), y marca la elección como `custom`.
  void fillCustom(int orden, String mode) {
    final s = suggestionAt(orden);
    final a = _answers[orden];
    a.choice = Choice.custom;
    a.custom = mode == 'original'
        ? (s.original ?? '')
        : mode == 'proposed'
            ? (s.proposed ?? '')
            : '';
    _touch();
  }

  void setInsertPosition(int orden, String pos) {
    _answers[orden].insertPosition = pos;
    _touch();
  }

  void setManualEdit(int start, int end, String original, String value) {
    final edit = ManualEdit(
      start: start,
      end: end,
      original: original,
      value: value,
    );
    _manualEdits[edit.blockId] = edit;
    _touch();
  }

  void removeManualEdit(String blockId) {
    if (_manualEdits.remove(blockId) != null) _touch();
  }

  // ---------- Reset ----------

  Future<void> reset() async {
    final r = _review;
    if (r == null) return;
    await _api.resetEstado(r.id);
    for (final a in _answers) {
      a.choice = null;
      a.custom = '';
      a.insertPosition =
          suggestionAt(a.orden).isInsert ? InsertPosition.between : null;
    }
    _manualEdits.clear();
    _debounce?.cancel();
    _saveStatus = SaveStatus.saved;
    notifyListeners();
  }

  // ---------- Autosave ----------

  void _touch() {
    _saveStatus = SaveStatus.pending;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, _persist);
  }

  /// Guardado manual inmediato (botón "Guardar").
  Future<void> saveNow() async {
    _debounce?.cancel();
    await _persist();
  }

  Future<void> _persist() async {
    final r = _review;
    if (r == null) return;
    if (_saving) {
      _queued = true; // hay cambios mientras se guardaba: reintenta al acabar
      return;
    }
    _saving = true;
    _saveStatus = SaveStatus.saving;
    notifyListeners();
    try {
      await _api.putEstado(
        r.id,
        ReviewState(answers: _answers, manualEdits: _manualEdits),
      );
      _saveStatus = _queued ? SaveStatus.pending : SaveStatus.saved;
      _lastError = null;
    } catch (e) {
      _lastError = e;
      _saveStatus = SaveStatus.error;
    } finally {
      _saving = false;
      notifyListeners();
      if (_queued) {
        _queued = false;
        _persist();
      }
    }
  }

  // ---------- Progreso ----------

  Counts counts() {
    final total = _answers.length;
    final done = _answers.where((a) => a.isResolved).length;
    return Counts(
      total: total,
      done: done,
      pending: total - done,
      accepted: _answers.where((a) => a.choice == Choice.proposed).length,
      originals: _answers.where((a) => a.choice == Choice.original).length,
      custom: _answers.where((a) => a.choice == Choice.custom).length,
      manual: _manualEdits.length,
    );
  }

  // ---------- Motor de composición (réplica literal del HTML) ----------

  /// Texto elegido para una sugerencia según la decisión actual.
  String _chosenText(Suggestion s, Answer a) {
    if (a.choice == Choice.original) return s.isInsert ? '' : (s.original ?? '');
    if (a.choice == Choice.proposed) return s.proposed ?? '';
    if (a.choice == Choice.custom) return a.custom;
    return s.isInsert ? '' : (s.original ?? '');
  }

  bool _truthy(String? v) => v != null && v.isNotEmpty;

  int _insertBasePosition(Suggestion s) {
    final original = _review!.chapter;
    if (s.insert == 'before') return original.indexOf(s.anchor ?? '');
    final p = original.indexOf(s.anchor ?? '');
    return p < 0 ? -1 : p + (s.anchor ?? '').length;
  }

  int _insertChosenPosition(Suggestion s, Answer a) {
    final original = _review!.chapter;
    final mode = a.insertPosition ?? InsertPosition.between;

    if (mode == InsertPosition.before && _truthy(s.previous)) {
      return original.indexOf(s.previous!);
    }
    if (mode == InsertPosition.after && _truthy(s.next)) {
      final p = original.indexOf(s.next!);
      return p < 0 ? -1 : p + s.next!.length;
    }
    if (_truthy(s.previous)) {
      final p = original.indexOf(s.previous!);
      return p < 0 ? -1 : p + s.previous!.length;
    }
    return _insertBasePosition(s);
  }

  /// Compone el texto actual del capítulo con todas las decisiones aplicadas.
  String currentText() {
    final r = _review;
    if (r == null) return '';
    final original = r.chapter;
    final ops = <_Op>[];

    for (var i = 0; i < r.suggestions.length; i++) {
      final s = r.suggestions[i];
      final replacement = _chosenText(s, _answers[i]);

      if (s.isReplace) {
        final start = original.indexOf(s.original ?? '');
        if (start >= 0) {
          ops.add(_Op(
            'replace',
            start,
            start + (s.original ?? '').length,
            replacement,
            20,
          ));
        }
        continue;
      }

      if (s.isInsert && replacement.isNotEmpty) {
        final pos = _insertChosenPosition(s, _answers[i]);
        if (pos >= 0) ops.add(_Op('insert', pos, pos, replacement, 10));
      }
    }

    _manualEdits.forEach((_, e) {
      ops.add(_Op('manual', e.start, e.end, e.value, 30));
    });

    // De final a principio; a igual posición, mayor prioridad primero.
    ops.sort((a, b) {
      if (a.start != b.start) return b.start - a.start;
      return b.priority - a.priority;
    });

    var text = original;
    for (final op in ops) {
      if (op.kind == 'insert') {
        text = text.substring(0, op.start) +
            '\n\n${op.text}\n\n' +
            text.substring(op.start);
      } else {
        text = text.substring(0, op.start) + op.text + text.substring(op.end);
      }
    }
    return text;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

class _Op {
  final String kind; // 'replace' | 'insert' | 'manual'
  final int start;
  final int end;
  final String text;
  final int priority;
  const _Op(this.kind, this.start, this.end, this.text, this.priority);
}
