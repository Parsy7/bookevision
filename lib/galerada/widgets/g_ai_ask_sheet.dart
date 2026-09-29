import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import 'g_bits.dart';
import 'g_button.dart';
import 'g_field.dart';

/// Hoja "Preguntar a la IA" sobre un fragmento seleccionado: pregunta libre,
/// respuesta en texto, y un botón para convertir esa respuesta en una
/// sugerencia de edición concreta sobre el capítulo.
class GAiAskSheet {
  GAiAskSheet._();

  static Future<void> show(
    BuildContext context, {
    required String seleccion,
    required String revisionId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GColors.sheet,
      shape: const RoundedRectangleBorder(),
      builder: (_) => _AiAskSheet(seleccion: seleccion, revisionId: revisionId),
    );
  }
}

class _AiAskSheet extends StatefulWidget {
  final String seleccion;
  final String revisionId;
  const _AiAskSheet({required this.seleccion, required this.revisionId});

  @override
  State<_AiAskSheet> createState() => _AiAskSheetState();
}

class _AiAskSheetState extends State<_AiAskSheet> {
  final _preguntaController = TextEditingController();
  bool _cargando = false;
  bool _convirtiendo = false;
  String? _respuesta;
  String? _error;

  @override
  void dispose() {
    _preguntaController.dispose();
    super.dispose();
  }

  Future<void> _preguntar() async {
    final pregunta = _preguntaController.text.trim();
    if (pregunta.isEmpty) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final respuesta =
          await context.read<ApiService>().preguntarSeleccion(widget.seleccion, pregunta);
      if (!mounted) return;
      setState(() => _respuesta = respuesta);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo preguntar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _convertirEnSugerencia() async {
    setState(() {
      _convirtiendo = true;
      _error = null;
    });
    try {
      await context.read<ApiService>().generarSugerencias(
        widget.revisionId,
        seed: {
          'selection': widget.seleccion,
          'question': _preguntaController.text.trim(),
          'answer': _respuesta,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SUGERENCIA AÑADIDA AL CAPÍTULO',
              style: GText.mono.copyWith(color: GColors.onInk)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _convirtiendo = false;
        _error = 'No se pudo convertir en sugerencia: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const GMono.muted('Fragmento seleccionado'),
              const SizedBox(height: GSpacing.gapSm),
              Container(
                padding: const EdgeInsets.all(GSpacing.blockV),
                decoration: BoxDecoration(
                  color: GColors.white,
                  border: Border.all(color: GColors.ink, width: GSpacing.border),
                ),
                child: Text(
                  widget.seleccion,
                  style: GText.block.copyWith(fontStyle: FontStyle.italic),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: GSpacing.gap),
              GField(
                label: 'Pregunta',
                controller: _preguntaController,
                hint: '¿Qué quieres saber sobre esto?',
              ),
              const SizedBox(height: GSpacing.gap),
              GButton(
                label: _cargando ? 'Preguntando…' : 'Preguntar',
                fill: GFill.ink,
                onPressed: _cargando ? null : _preguntar,
              ),
              if (_respuesta != null) ...[
                const SizedBox(height: GSpacing.gap),
                const GMono.muted('Respuesta'),
                const SizedBox(height: GSpacing.gapSm),
                Text(_respuesta!, style: GText.block),
                const SizedBox(height: GSpacing.gap),
                GButton(
                  label: _convirtiendo ? 'Convirtiendo…' : 'Convertir en sugerencia',
                  fill: GFill.red,
                  onPressed: _convirtiendo ? null : _convertirEnSugerencia,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: GSpacing.gap),
                GMono.red('✕ ${_error!}'),
              ],
              const SizedBox(height: GSpacing.page),
            ],
          ),
        ),
      ),
    );
  }
}
