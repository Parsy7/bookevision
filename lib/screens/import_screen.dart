import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/import_md.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

/// Importa un capítulo: pegando el JSON de una revisión, cargando un `.json`,
/// o cargando un `.md` suelto (que entra como capítulo sin sugerencias, solo
/// para leerlo y editarlo a mano). Devuelve el id al hacer `pop`.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return; // cancelado
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        setState(() => _error = 'No se pudo leer el archivo.');
        return;
      }
      _controller.text = utf8.decode(bytes);
      setState(() {});
    } catch (e) {
      setState(() => _error = 'No se pudo abrir el archivo: $e');
    }
  }

  Future<void> _pickMarkdown() async {
    setState(() => _error = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown', 'txt'],
        withData: true,
      );
      if (result == null) return; // cancelado
      final archivo = result.files.single;
      final bytes = archivo.bytes;
      if (bytes == null) {
        setState(() => _error = 'No se pudo leer el archivo.');
        return;
      }
      final contenido = utf8.decode(bytes);
      if (ImportMd.normalizar(contenido).isEmpty) {
        setState(() => _error = 'Ese archivo está vacío.');
        return;
      }
      await _enviar(ImportMd.revision(archivo.name, contenido));
    } catch (e) {
      setState(() => _error = 'No se pudo abrir el archivo: $e');
    }
  }

  /// POST común de las tres vías de importación.
  Future<void> _enviar(Map<String, dynamic> json) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final review = await context.read<ApiService>().importRevision(json);
      if (!mounted) return;
      Navigator.of(context).pop(review.id);
    } catch (e) {
      final msg = e.toString().contains('409')
          ? 'Ya existe una revisión con ese id. Bórrala antes de reimportar.'
          : 'No se pudo importar: $e';
      setState(() {
        _busy = false;
        _error = msg;
      });
    }
  }

  Future<void> _import() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Pega el JSON o carga un archivo primero.');
      return;
    }

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        setState(() => _error = 'El JSON debe ser un objeto de revisión.');
        return;
      }
      json = decoded;
    } catch (_) {
      setState(() => _error = 'El texto no es un JSON válido.');
      return;
    }

    await _enviar(json);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar revisión')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text(
            'Carga un capítulo en .md para leerlo y editarlo a mano, o importa '
            'una revisión con sus sugerencias: pega el JSON (formato '
            'la-jaula-rota-review-v4) o carga el archivo .json.',
            style: AppText.subtitle,
          ),
          const SizedBox(height: AppSpacing.gapMd),
          AppButton(
            label: 'Cargar capítulo .md',
            icon: Icons.article_outlined,
            onPressed: _busy ? null : _pickMarkdown,
          ),
          const SizedBox(height: AppSpacing.gapSm),
          Text(
            'Sin tarjetas: el capítulo entero, editable con pulsación larga.',
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpacing.gapMd),
          AppButton(
            label: 'Cargar revisión .json',
            variant: AppButtonVariant.secondary,
            icon: Icons.upload_file_outlined,
            onPressed: _busy ? null : _pickFile,
          ),
          const SizedBox(height: AppSpacing.gapMd),
          AppInput(
            controller: _controller,
            hintText: 'Pega aquí el JSON…',
            keyboardType: TextInputType.multiline,
            maxLines: 14,
            minLines: 8,
            textCapitalization: TextCapitalization.none,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.gapMd),
            Text(_error!, style: AppText.label.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.gapMd),
          AppButton(
            label: _busy ? 'Importando…' : 'Importar',
            onPressed: _busy ? null : _import,
          ),
        ],
      ),
    );
  }
}
