import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/libro.dart';
import '../../services/api_service.dart';
import '../theme/g_colors.dart';
import '../widgets/g_lista.dart';
import 'g_create_libro_screen.dart';
import 'g_libro_screen.dart';
import 'g_profile_screen.dart';

/// «Mis libros»: portada de la piel tras el login. Cada fila es un proyecto
/// de libro; entrar en uno lleva a sus capítulos.
class GLibroListScreen extends StatefulWidget {
  const GLibroListScreen({super.key});

  @override
  State<GLibroListScreen> createState() => _GLibroListScreenState();
}

class _GLibroListScreenState extends State<GLibroListScreen> {
  late Future<List<Libro>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<ApiService>().getLibros();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _nuevoLibro() async {
    final libro = await Navigator.of(context).push<Libro>(
      MaterialPageRoute(builder: (_) => const GCreateLibroScreen()),
    );
    if (!mounted) return;
    await _refresh();
    if (libro != null) _abrirLibro(libro);
  }

  void _abrirLibro(Libro libro) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GLibroScreen(libro: libro)))
        .then((_) => _refresh());
  }

  void _abrirPerfil() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const GProfileScreen()));
  }

  GHero _hero(int numero) => GHero(
        titulo: 'Mis ',
        tituloEm: 'libros',
        subtitulo: '$numero ${numero == 1 ? 'libro' : 'libros'}',
        accion: 'Mi perfil',
        onAccion: _abrirPerfil,
      );

  @override
  Widget build(BuildContext context) {
    return GPantallaLista<Libro>(
      future: _future,
      onRefresh: _refresh,
      hero: (items) => _hero(items.length),
      fila: (libro, _) => GFila(
        id: 'libro-${libro.id}',
        titulo: libro.title,
        meta:
            '${libro.capitulos} ${libro.capitulos == 1 ? 'capítulo' : 'capítulos'}',
        derecha: Icon(Icons.chevron_right, color: GColors.ink),
        onTap: () => _abrirLibro(libro),
      ),
      vacia: GListaVacia(
        hero: _hero(0),
        texto: 'Da de alta tu primer libro para empezar a importar y '
            'revisar capítulos.',
        boton: 'Nuevo libro',
        onBoton: _nuevoLibro,
      ),
      pieLabel: 'Nuevo libro',
      pieIcon: Icons.add,
      onPie: _nuevoLibro,
    );
  }
}
