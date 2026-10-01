/// Capítulo de un libro: agrupa sus revisiones (p. ej. una ronda de
/// sugerencias y luego el .md final). Corresponde a `GET /capitulos`.
class Capitulo {
  final int id;
  final int libroId;
  final int numero;
  final String titulo;

  /// Cuántas revisiones tiene, y cuántas de ellas están listas.
  final int revisiones;
  final int listas;
  final DateTime? updatedAt;

  const Capitulo({
    required this.id,
    required this.libroId,
    required this.numero,
    required this.titulo,
    this.revisiones = 0,
    this.listas = 0,
    this.updatedAt,
  });

  /// Listo cuando tiene revisiones y todas lo están.
  bool get isComplete => revisiones > 0 && listas >= revisiones;

  factory Capitulo.fromJson(Map<String, dynamic> j) => Capitulo(
        id: (j['id'] as num).toInt(),
        libroId: (j['libro_id'] as num).toInt(),
        numero: (j['numero'] as num).toInt(),
        titulo: j['titulo'] as String,
        revisiones: (j['revisiones'] as num?)?.toInt() ?? 0,
        listas: (j['listas'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse((j['updated_at'] as String?) ?? ''),
      );
}
