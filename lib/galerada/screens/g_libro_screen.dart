import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/capitulo.dart';
import '../../models/libro.dart';
import '../../services/api_service.dart';
import '../theme/g_colors.dart';
import '../theme/g_text.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_dialog.dart';
import '../widgets/g_lista.dart';
import 'g_capitulo_form_screen.dart';
import 'g_review_list_screen.dart';

/// Portada de un libro: una fila por capítulo, con su número, cuántas
/// revisiones tiene, el medidor de las que están listas y su sello.
class GLibroScreen extends StatefulWidget {
  final Libro libro;

  const GLibroScreen({super.key, required this.libro});

  @override
  State<GLibroScreen> createState() => _GLibroScreenState();
}

class _GLibroScreenState extends State<GLibroScreen> {
  late Future<List<Capitulo>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<ApiService>().getCapitulos(widget.libro.id);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _nuevoCapitulo() async {
    final capitulo = await Navigator.of(context).push<Capitulo>(
      MaterialPageRoute(
          builder: (_) => GCapituloFormScreen(libroId: widget.libro.id)),
    );
    if (!mounted) return;
    await _refresh();
    if (capitulo != null) _abrir(capitulo);
  }

  void _abrir(Capitulo capitulo) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) =>
              GReviewListScreen(libro: widget.libro, capitulo: capitulo),
        ))
        .then((_) => _refresh());
  }

  Future<void> _opciones(Capitulo c) async {
    final opcion = await GMenu.hoja(
      context,
      titulo: 'Capítulo ${c.numero}',
      items: const [
        GMenuItem(
            label: 'Editar número y título', icon: Icons.edit, value: 'editar'),
        GMenuItem(
            label: 'Borrar capítulo',
            icon: Icons.delete_outline,
            value: 'borrar',
            danger: true),
      ],
    );
    if (!mounted) return;
    switch (opcion) {
      case 'editar':
        final editado = await Navigator.of(context).push<Capitulo>(
          MaterialPageRoute(
            builder: (_) =>
                GCapituloFormScreen(libroId: widget.libro.id, capitulo: c),
          ),
        );
        if (editado != null && mounted) await _refresh();
      case 'borrar':
        await _borrar(c);
    }
  }

  Future<void> _borrar(Capitulo c) async {
    final ok = await GDialog.confirmar(
      context,
      title: 'Borrar',
      keyword: 'capítulo',
      message: c.revisiones == 0
          ? '«${c.titulo}» no tiene revisiones.'
          : '«${c.titulo}» y sus ${c.revisiones} '
              '${c.revisiones == 1 ? 'revisión' : 'revisiones'}, con todas tus '
              'decisiones, se borrarán. Esta acción no se puede deshacer.',
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteCapitulo(c.id);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('NO SE PUDO BORRAR: $e',
              style: GText.mono.copyWith(color: GColors.onInk)),
        ));
      }
    }
  }

  GHero _hero(int numero) => GHero(
        titulo: widget.libro.title,
        subtitulo: '$numero ${numero == 1 ? 'capítulo' : 'capítulos'}',
        meta: 'Libro',
        onVolver: () => Navigator.of(context).maybePop(),
        logo: false,
      );

  String _meta(Capitulo c) => switch (c.revisiones) {
        0 => 'Sin revisiones',
        1 => '1 revisión',
        final n => '$n revisiones',
      };

  @override
  Widget build(BuildContext context) {
    return GPantallaLista<Capitulo>(
      future: _future,
      onRefresh: _refresh,
      hero: (items) => _hero(items.length),
      fila: (c, _) => GFila(
        id: 'capitulo-${c.id}',
        numero: c.numero,
        titulo: c.titulo,
        meta: _meta(c),
        debajo: c.revisiones > 0
            ? GMeter(total: c.revisiones, done: c.listas)
            : null,
        derecha: GStamp(
          c.isComplete ? 'Listo' : (c.revisiones == 0 ? 'Vacío' : 'En curso'),
          filled: c.isComplete,
        ),
        onTap: () => _abrir(c),
        onLongPress: () => _opciones(c),
        onBorrar: () => _borrar(c),
      ),
      vacia: GListaVacia(
        hero: _hero(0),
        texto: 'Crea el primer capítulo para importar sus revisiones dentro.',
        boton: 'Nuevo capítulo',
        onBoton: _nuevoCapitulo,
      ),
      pieLabel: 'Nuevo capítulo',
      pieIcon: Icons.add,
      onPie: _nuevoCapitulo,
    );
  }
}
