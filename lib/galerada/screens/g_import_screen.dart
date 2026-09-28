import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../utils/import_md.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_app_bar.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_button.dart';
import '../widgets/g_foot.dart';

/// Importar un capítulo: un `.md` suelto para leerlo y editarlo a mano, o una
/// revisión con sus sugerencias (archivo `.json` o JSON pegado).
class GImportScreen extends StatefulWidget {
  final String libroId;

  const GImportScreen({super.key, required this.libroId});

  @override
  State<GImportScreen> createState() => _GImportScreenState();
}

class _GImportScreenState extends State<GImportScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickJson() async {
    setState(() => _error = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return;
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
      if (result == null) return;
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

  Future<void> _enviar(Map<String, dynamic> json) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final review = await context
          .read<ApiService>()
          .importRevision(json, libroId: widget.libroId);
      if (!mounted) return;
      Navigator.of(context).pop(review.id);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().contains('409')
            ? 'Ya existe una revisión con ese id. Bórrala antes de reimportar.'
            : 'No se pudo importar: $e';
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
      appBar: const GAppBar(title: 'Importar'),
      body: SingleChildScrollView(
        padding: GSpacing.pageScroll(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Carga un capítulo en .md para leerlo y editarlo a mano, o '
              'importa una revisión con sus sugerencias.',
              style: GText.reason.copyWith(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: GSpacing.gap),
            GButton(
              label: 'Cargar capítulo .md',
              icon: Icons.article,
              fill: GFill.ink,
              onPressed: _busy ? null : _pickMarkdown,
            ),
            const SizedBox(height: GSpacing.gapSm),
            const GMono.muted('Sin tarjetas · el capítulo entero, editable'),
            const SizedBox(height: GSpacing.gap),
            GButton(
              label: 'Cargar revisión .json',
              icon: Icons.upload_file,
              onPressed: _busy ? null : _pickJson,
            ),
            const SizedBox(height: GSpacing.gap),
            const GMono('O pega el JSON'),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(minHeight: 180),
              decoration: BoxDecoration(
                color: GColors.white,
                border: Border.all(color: GColors.ink, width: GSpacing.border),
              ),
              padding: const EdgeInsets.all(GSpacing.blockV),
              child: TextField(
                controller: _controller,
                style: GText.field,
                cursorColor: GColors.blue,
                cursorWidth: GSpacing.caret,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.none,
                maxLines: null,
                minLines: 8,
                scrollPadding: const EdgeInsets.all(GSpacing.gapSm),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: '{ "format": "la-jaula-rota-review-v4", …',
                  hintStyle: GText.field.copyWith(color: GColors.grey3),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: GSpacing.gap),
              GMono.red('✕ ${_error!}'),
            ],
          ],
        ),
      ),
      bottomNavigationBar: GFoot.unica(
        label: _busy ? 'Importando…' : 'Importar',
        fill: _busy ? GFootFill.off : GFootFill.red,
        onTap: _busy ? null : _import,
      ),
    );
  }
}
