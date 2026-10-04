import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Utilidades de exportación del capítulo como Markdown, réplica de `exportMd`
/// del HTML (mismo criterio de nombre de archivo).
class ExportMd {
  ExportMd._();

  /// Nombre de archivo: título saneado + sufijo + .md
  static String fileName(String title, String suffix) {
    final safe = (title.isEmpty ? 'capitulo' : title)
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
    return '$safe - $suffix.md';
  }

  static bool get _escritorio =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// En el móvil, escribe el texto en un .md temporal y abre el diálogo de
  /// compartir; en escritorio, «Guardar como» (el panel de compartir del
  /// sistema ahí no sirve para guardar un archivo).
  /// [suffix] suele ser 'avance' (parcial) o 'definitivo' (final).
  static Future<void> share(String title, String suffix, String text) async {
    if (_escritorio) return _guardarComo(fileName(title, suffix), text);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${fileName(title, suffix)}');
    await file.writeAsString(text);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  static Future<void> _guardarComo(String nombre, String text) async {
    final ruta = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar como',
      fileName: nombre,
      type: FileType.custom,
      allowedExtensions: const ['md'],
    );
    if (ruta == null) return; // cancelado
    // El diálogo de Windows no siempre añade la extensión.
    final conExtension = ruta.toLowerCase().endsWith('.md') ? ruta : '$ruta.md';
    await File(conExtension).writeAsString(text);
  }

  /// Copia el texto al portapapeles.
  static Future<void> copy(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}
