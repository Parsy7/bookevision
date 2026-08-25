import 'suggestion.dart';

/// Revisión completa: el capítulo entero más sus sugerencias ordenadas.
/// Corresponde a `GET /revisiones/{id}`.
class Review {
  final String id;
  final String format;
  final String title;
  final String? source;
  final String chapter;
  final List<Suggestion> suggestions;

  const Review({
    required this.id,
    required this.format,
    required this.title,
    this.source,
    required this.chapter,
    required this.suggestions,
  });

  int get replaceCount => suggestions.where((s) => s.isReplace).length;
  int get insertCount => suggestions.where((s) => s.isInsert).length;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'] as String,
        format: (j['format'] as String?) ?? 'la-jaula-rota-review-v4',
        title: (j['title'] as String?) ?? 'Capítulo',
        source: j['source'] as String?,
        chapter: j['chapter'] as String,
        suggestions: ((j['suggestions'] as List?) ?? const [])
            .map((e) => Suggestion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
