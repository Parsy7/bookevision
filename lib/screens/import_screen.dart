import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

/// Importa una revisión: pegando el JSON o cargando un archivo `.json`.
/// Devuelve `true` al hacer `pop` si se importó algo (para refrescar la lista).
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar revisión')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text(
            'Pega el JSON de la revisión (formato la-jaula-rota-review-v4) o '
            'carga un archivo .json.',
            style: AppText.subtitle,
          ),
          const SizedBox(height: AppSpacing.gapMd),
          AppButton(
            label: 'Cargar archivo .json',
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
