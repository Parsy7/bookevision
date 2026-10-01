import 'suggestion.dart';

/// Revisión completa: el capítulo entero más sus sugerencias ordenadas.
/// Corresponde a `GET /revisiones/{id}`.
class Review {
  final String id;
  final int? libroId;
  final int? capituloId;
  final String format;
  final String title;
  final String? source;
  final String chapter;
  final List<Suggestion> suggestions;

  /// Capítulo suelto (sin sugerencias) marcado a mano como terminado.
  final bool finalizada;

  const Review({
    required this.id,
    this.libroId,
    this.capituloId,
    required this.format,
    required this.title,
    this.source,
    required this.chapter,
    required this.suggestions,
    this.finalizada = false,
  });

  Review copyWith({bool? finalizada}) => Review(
        id: id,
        libroId: libroId,
        capituloId: capituloId,
        format: format,
        title: title,
        source: source,
        chapter: chapter,
        suggestions: suggestions,
        finalizada: finalizada ?? this.finalizada,
      );

  int get replaceCount => suggestions.where((s) => s.isReplace).length;
  int get insertCount => suggestions.where((s) => s.isInsert).length;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'] as String,
        libroId: (j['libro_id'] as num?)?.toInt(),
        capituloId: (j['capitulo_id'] as num?)?.toInt(),
        format: (j['format'] as String?) ?? 'la-jaula-rota-review-v4',
        title: (j['title'] as String?) ?? 'Capítulo',
        source: j['source'] as String?,
        chapter: j['chapter'] as String,
        suggestions: ((j['suggestions'] as List?) ?? const [])
            .map((e) => Suggestion.fromJson(e as Map<String, dynamic>))
            .toList(),
        finalizada: j['finalizada'] == true || j['finalizada'] == 1,
      );
}
