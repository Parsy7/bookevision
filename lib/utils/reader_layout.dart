import '../models/review.dart';
import '../models/suggestion.dart';

/// Piezas que componen el lector, en orden. Réplica del `render()` del HTML.
sealed class ReaderPiece {
  const ReaderPiece();
}

/// Bloque de prosa libre editable (un hueco entre sugerencias). Su id estable
/// es `b_<start>_<end>` con los offsets en el capítulo original.
class ProsePiece extends ReaderPiece {
  final String text; // texto original del hueco
  final int start;
  final int end;
  const ProsePiece(this.text, this.start, this.end);

  String get blockId => 'b_${start}_$end';
}

/// Fragmento original afectado por una sustitución (se muestra atenuado; la
/// tarjeta con las opciones va justo debajo).
class AffectedPiece extends ReaderPiece {
  final String text;
  const AffectedPiece(this.text);
}

/// Marcador de posible inserción ("＋ Posible inserción aquí").
class InsertMarkerPiece extends ReaderPiece {
  const InsertMarkerPiece();
}

/// Tarjeta de sugerencia número [index].
class CardPiece extends ReaderPiece {
  final int index;
  const CardPiece(this.index);
}

class _Located {
  final int i;
  final Suggestion s;
  final String needle;
  final int start;
  final int end;
  const _Located(this.i, this.s, this.needle, this.start, this.end);
}

int _insertBasePosition(String chapter, Suggestion s) {
  if (s.insert == 'before') return chapter.indexOf(s.anchor ?? '');
  final p = chapter.indexOf(s.anchor ?? '');
  return p < 0 ? -1 : p + (s.anchor ?? '').length;
}

List<_Located> _locate(Review r) {
  final chapter = r.chapter;
  final list = <_Located>[];
  for (var i = 0; i < r.suggestions.length; i++) {
    final s = r.suggestions[i];
    if (s.isInsert) {
      final pos = _insertBasePosition(chapter, s);
      list.add(_Located(i, s, '', pos, pos));
    } else {
      final needle = s.original ?? '';
      final start = chapter.indexOf(needle);
      list.add(_Located(i, s, needle, start,
          start + (needle.isEmpty ? 0 : needle.length)));
    }
  }
  list.sort((a, b) => a.start != b.start ? a.start - b.start : a.i - b.i);
  return list;
}

/// Recorre el capítulo intercalando prosa, fragmentos afectados, marcadores de
/// inserción y tarjetas, exactamente como el `render()` del HTML.
List<ReaderPiece> buildReaderPieces(Review r) {
  final chapter = r.chapter;
  final pieces = <ReaderPiece>[];
  var cursor = 0;

  for (final it in _locate(r)) {
    if (it.start < 0 || it.start < cursor) continue;

    final gap = chapter.substring(cursor, it.start);
    if (gap.isNotEmpty) pieces.add(ProsePiece(gap, cursor, it.start));

    if (it.s.isReplace) {
      pieces.add(AffectedPiece(it.needle));
      cursor = it.end; // la sustitución se queda con este rango original
    } else {
      pieces.add(const InsertMarkerPiece());
      cursor = it.start; // la inserción no consume caracteres
    }
    pieces.add(CardPiece(it.i));
  }

  final tail = chapter.substring(cursor);
  if (tail.isNotEmpty) {
    pieces.add(ProsePiece(tail, cursor, chapter.length));
  }
  return pieces;
}
