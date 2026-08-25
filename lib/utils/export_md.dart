import 'dart:io';
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

  /// Escribe el texto en un .md temporal y abre el diálogo de compartir.
  /// [suffix] suele ser 'avance' (parcial) o 'definitivo' (final).
  static Future<void> share(String title, String suffix, String text) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${fileName(title, suffix)}');
    await file.writeAsString(text);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  /// Copia el texto al portapapeles.
  static Future<void> copy(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}
