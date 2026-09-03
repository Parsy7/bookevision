import 'dart:convert';

/// Convierte un Markdown suelto en una revisión **sin sugerencias**: solo el
/// capítulo, para leerlo y editarlo a mano (pulsación larga) sin tarjetas.
///
/// No se toca el contenido más allá de normalizar los saltos de línea: lo que
/// entra es lo que se exporta luego. El encabezado, si lo hay, se queda dentro
/// del capítulo como un bloque más; solo se **lee** para poner título.
class ImportMd {
  ImportMd._();

  /// `#`…`######` seguido de texto (con los `#` de cierre opcionales de
  /// ATX cerrado).
  static final RegExp _encabezado = RegExp(r'^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$');

  /// Título: el primer encabezado del documento si la primera línea con algo
  /// escrito lo es; si no, el nombre del archivo sin extensión.
  static String titulo(String nombreArchivo, String contenido) {
    for (final linea in const LineSplitter().convert(contenido)) {
      if (linea.trim().isEmpty) continue;
      final m = _encabezado.firstMatch(linea);
      return m != null ? m.group(1)! : _sinExtension(nombreArchivo);
    }
    return _sinExtension(nombreArchivo);
  }

  /// `revisiones.title` y `revisiones.source` son VARCHAR(255): pasarse hace
  /// que el INSERT falle con un error de servidor poco explicativo.
  static const int _maxColumna = 255;

  /// Se cuenta en runas porque eso es lo que cuenta MySQL en utf8mb4: code
  /// points, no grafemas ni bytes.
  static String _recortar(String texto) {
    final runas = texto.runes;
    if (runas.length <= _maxColumna) return texto;
    return String.fromCharCodes(runas.take(_maxColumna));
  }

  static String _sinExtension(String nombre) {
    final punto = nombre.lastIndexOf('.');
    final base = (punto > 0 ? nombre.substring(0, punto) : nombre).trim();
    return base.isEmpty ? 'Capítulo' : base;
  }

  /// Saltos de línea a `\n`: si se quedan los `\r\n` de Windows, el capítulo no
  /// se parte en párrafos (el separador es `\n\n`).
  static String normalizar(String contenido) =>
      contenido.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

  /// Cuerpo del POST de importación. Sin `id`: la API deriva uno del título más
  /// la fecha, así que se puede cargar el mismo archivo dos veces.
  static Map<String, dynamic> revision(String nombreArchivo, String contenido) {
    return {
      'format': 'la-jaula-rota-review-v4',
      'title': _recortar(titulo(nombreArchivo, contenido)),
      'source': _recortar(nombreArchivo),
      'chapter': normalizar(contenido),
      'suggestions': const <Map<String, dynamic>>[],
    };
  }
}
