/// Un proyecto de libro: agrupa las revisiones (capítulos) de su dueño.
/// Corresponde a `GET /libros`.
class Libro {
  final int id;
  final String title;
  final int capitulos;
  final DateTime? updatedAt;

  const Libro({
    required this.id,
    required this.title,
    required this.capitulos,
    this.updatedAt,
  });

  factory Libro.fromJson(Map<String, dynamic> j) => Libro(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String,
        capitulos: (j['capitulos'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse((j['updated_at'] as String?) ?? ''),
      );
}
