/// Fila de la lista de revisiones, con su progreso. Corresponde a
/// `GET /revisiones`.
class ReviewSummary {
  final String id;
  final String format;
  final String title;
  final String? source;
  final DateTime? updatedAt;
  final int total; // nº de sugerencias
  final int resolved; // resueltas (aceptada/original/personalizada no vacía)
  final int manual; // bloques editados a mano

  const ReviewSummary({
    required this.id,
    required this.format,
    required this.title,
    this.source,
    this.updatedAt,
    required this.total,
    required this.resolved,
    required this.manual,
  });

  int get pending => total - resolved;
  bool get isComplete => total > 0 && resolved >= total;

  factory ReviewSummary.fromJson(Map<String, dynamic> j) => ReviewSummary(
        id: j['id'] as String,
        format: (j['format'] as String?) ?? 'la-jaula-rota-review-v4',
        title: (j['title'] as String?) ?? 'Capítulo',
        source: j['source'] as String?,
        updatedAt: DateTime.tryParse((j['updated_at'] as String?) ?? ''),
        total: (j['total'] as num?)?.toInt() ?? 0,
        resolved: (j['resolved'] as num?)?.toInt() ?? 0,
        manual: (j['manual'] as num?)?.toInt() ?? 0,
      );
}
