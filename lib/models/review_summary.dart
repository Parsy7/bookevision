/// Fila de la lista de revisiones, con su progreso. Corresponde a
/// `GET /revisiones`.
class ReviewSummary {
  final String id;
  final int? libroId;
  final int? capituloId;
  final String format;
  final String title;
  final String? source;
  final DateTime? updatedAt;
  final int total; // nº de sugerencias
  final int resolved; // resueltas (aceptada/original/personalizada no vacía)
  final int manual; // bloques editados a mano

  /// Solo cuenta en un capítulo suelto: marcado a mano como terminado.
  final bool finalizada;

  const ReviewSummary({
    required this.id,
    this.libroId,
    this.capituloId,
    required this.format,
    required this.title,
    this.source,
    this.updatedAt,
    required this.total,
    required this.resolved,
    required this.manual,
    this.finalizada = false,
  });

  int get pending => total - resolved;
  /// Misma regla que `ReviewController::listarConProgreso` en el servidor:
  /// con sugerencias, todas resueltas; sin ellas, finalizada a mano.
  bool get isComplete => isDocument ? finalizada : resolved >= total;

  /// Capítulo cargado suelto (un `.md`): sin sugerencias que resolver, solo
  /// texto para leer y editar a mano.
  bool get isDocument => total == 0;

  factory ReviewSummary.fromJson(Map<String, dynamic> j) => ReviewSummary(
        id: j['id'] as String,
        libroId: (j['libro_id'] as num?)?.toInt(),
        capituloId: (j['capitulo_id'] as num?)?.toInt(),
        format: (j['format'] as String?) ?? 'la-jaula-rota-review-v4',
        title: (j['title'] as String?) ?? 'Capítulo',
        source: j['source'] as String?,
        updatedAt: DateTime.tryParse((j['updated_at'] as String?) ?? ''),
        total: (j['total'] as num?)?.toInt() ?? 0,
        resolved: (j['resolved'] as num?)?.toInt() ?? 0,
        manual: (j['manual'] as num?)?.toInt() ?? 0,
        finalizada: j['finalizada'] == true || j['finalizada'] == 1,
      );
}
