import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/libro.dart';
import '../../services/api_service.dart';
import '../theme/g_spacing.dart';
import '../widgets/g_app_bar.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_field.dart';
import '../widgets/g_foot.dart';

/// Dar de alta un libro nuevo: solo pide un título.
class GCreateLibroScreen extends StatefulWidget {
  const GCreateLibroScreen({super.key});

  @override
  State<GCreateLibroScreen> createState() => _GCreateLibroScreenState();
}

class _GCreateLibroScreenState extends State<GCreateLibroScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    final titulo = _controller.text.trim();
    if (titulo.isEmpty) {
      setState(() => _error = 'Ponle un título al libro primero.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Libro libro = await context.read<ApiService>().createLibro(titulo);
      if (!mounted) return;
      Navigator.of(context).pop(libro);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'No se pudo crear: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GAppBar(title: 'Nuevo libro'),
      body: SingleChildScrollView(
        padding: GSpacing.pageScroll(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GField(
              label: 'Título',
              controller: _controller,
              hint: 'El nombre de tu libro',
            ),
            if (_error != null) ...[
              const SizedBox(height: GSpacing.gap),
              GMono.red('✕ ${_error!}'),
            ],
          ],
        ),
      ),
      bottomNavigationBar: GFoot.unica(
        label: _busy ? 'Creando…' : 'Crear libro',
        fill: _busy ? GFootFill.off : GFootFill.red,
        onTap: _busy ? null : _crear,
      ),
    );
  }
}
