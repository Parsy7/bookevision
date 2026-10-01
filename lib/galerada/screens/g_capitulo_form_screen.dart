import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/capitulo.dart';
import '../../services/api_service.dart';
import '../theme/g_spacing.dart';
import '../widgets/g_app_bar.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_field.dart';
import '../widgets/g_foot.dart';

/// Crear un capítulo, o editar el número y el título de [capitulo]. Devuelve
/// el capítulo guardado al cerrarse.
class GCapituloFormScreen extends StatefulWidget {
  final int libroId;
  final Capitulo? capitulo;

  const GCapituloFormScreen({super.key, required this.libroId, this.capitulo});

  @override
  State<GCapituloFormScreen> createState() => _GCapituloFormScreenState();
}

class _GCapituloFormScreenState extends State<GCapituloFormScreen> {
  late final _numero = TextEditingController(text: widget.capitulo?.numero.toString() ?? '');
  late final _titulo = TextEditingController(text: widget.capitulo?.titulo ?? '');
  bool _busy = false;
  String? _error;

  bool get _editando => widget.capitulo != null;

  @override
  void dispose() {
    _numero.dispose();
    _titulo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final titulo = _titulo.text.trim();
    final textoNumero = _numero.text.trim();
    final numero = int.tryParse(textoNumero);
    if (titulo.isEmpty) {
      setState(() => _error = 'Ponle un título al capítulo.');
      return;
    }
    if (textoNumero.isNotEmpty && (numero == null || numero < 1)) {
      setState(() => _error = 'El número tiene que ser 1 o más.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final capitulo = _editando
          ? await api.updateCapitulo(widget.capitulo!.id, titulo: titulo, numero: numero)
          : await api.createCapitulo(widget.libroId, titulo, numero: numero);
      if (!mounted) return;
      Navigator.of(context).pop(capitulo);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      appBar: GAppBar(title: _editando ? 'Editar capítulo' : 'Nuevo capítulo'),
      body: SingleChildScrollView(
        padding: GSpacing.pageScroll(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GField(
              label: 'Número',
              controller: _numero,
              hint: _editando ? null : 'Vacío: el siguiente al último',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: GSpacing.gap),
            GField(
              label: 'Título',
              controller: _titulo,
              hint: 'Por ejemplo: XIV · Primero la promesa',
            ),
            if (error != null) ...[
              const SizedBox(height: GSpacing.gap),
              GMono.red('✕ $error'),
            ],
          ],
        ),
      ),
      bottomNavigationBar: GFoot.unica(
        label: _busy ? 'Guardando…' : (_editando ? 'Guardar' : 'Crear capítulo'),
        fill: _busy ? GFootFill.off : GFootFill.red,
        onTap: _busy ? null : _guardar,
      ),
    );
  }
}
