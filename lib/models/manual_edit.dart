/// Edición manual de un bloque de prosa libre (doble toque en el lector).
/// La clave del mapa es `block_id = b_<start>_<end>`; aquí guardamos los
/// offsets en coordenadas del capítulo original, el texto original y el nuevo.
class ManualEdit {
  final int start;
  final int end;
  final String original;
  String value;

  ManualEdit({
    required this.start,
    required this.end,
    required this.original,
    required this.value,
  });

  /// Id estable del bloque, igual que en el HTML.
  String get blockId => 'b_${start}_$end';

  factory ManualEdit.fromJson(Map<String, dynamic> j) => ManualEdit(
        start: (j['start'] as num).toInt(),
        end: (j['end'] as num).toInt(),
        original: (j['original'] as String?) ?? '',
        value: (j['value'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'original': original,
        'value': value,
      };
}
