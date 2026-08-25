/// Una sugerencia de edición dentro de una revisión. Dos tipos:
///  - `replace`: sustituye `original` por `proposed`.
///  - `insert`: añade texto nuevo cerca de un `anchor`, con contexto
///    `previous`/`next` y un lado `insert` (`before`/`after`).
///
/// Solo lectura: llega de la API y no se reenvía (la importación manda el JSON
/// original tal cual). El identificador dentro de la revisión es [orden].
class Suggestion {
  final int orden;
  final String type; // 'replace' | 'insert'
  final String? title;
  final String? location;
  final String? reason;
  final String? proposed;

  // Solo en replace.
  final String? original;

  // Solo en insert.
  final String? anchor;
  final String? insert; // 'before' | 'after'
  final String? previous;
  final String? next;

  const Suggestion({
    required this.orden,
    required this.type,
    this.title,
    this.location,
    this.reason,
    this.proposed,
    this.original,
    this.anchor,
    this.insert,
    this.previous,
    this.next,
  });

  bool get isReplace => type == 'replace';
  bool get isInsert => type == 'insert';

  factory Suggestion.fromJson(Map<String, dynamic> j) => Suggestion(
        orden: j['orden'] as int,
        type: j['type'] as String,
        title: j['title'] as String?,
        location: j['location'] as String?,
        reason: j['reason'] as String?,
        proposed: j['proposed'] as String?,
        original: j['original'] as String?,
        anchor: j['anchor'] as String?,
        insert: j['insert'] as String?,
        previous: j['previous'] as String?,
        next: j['next'] as String?,
      );
}
