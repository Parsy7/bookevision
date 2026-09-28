/// Numeración de párrafos del capítulo, que en «Galerada» se ve en el margen
/// («¶3») y en la cabecera de cada tarjeta.
///
/// Un párrafo es lo que separa una línea en blanco, igual que en el resto del
/// motor. El primero es el ¶1.
class GParagraphs {
  GParagraphs._();

  static const String _separador = '\n\n';

  /// Número de párrafo en el que cae [offset] del capítulo original.
  static int at(String chapter, int offset) {
    if (offset <= 0) return 1;
    final hasta = offset > chapter.length ? chapter.length : offset;
    return _separador.allMatches(chapter.substring(0, hasta)).length + 1;
  }

  /// Etiqueta de la cabecera: «¶6» para una sustitución, «¶3–¶4» para una
  /// inserción, que cae entre dos párrafos.
  static String label(String chapter, int start, {int? end}) {
    final a = at(chapter, start);
    if (end == null) return '¶$a';
    final b = at(chapter, end);
    return a == b ? '¶$a' : '¶$a–¶$b';
  }
}
