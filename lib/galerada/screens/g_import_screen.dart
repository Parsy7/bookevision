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

/// Qué se trae a un capítulo.
enum _Modo {
  /// Un `.md` suelto, para leerlo y editarlo a mano.
  md,

  /// Una revisión con sus sugerencias (archivo `.json` o JSON pegado).
  json,

  /// Una página vacía para escribir desde cero.
  blanco,
}

/// Archivo elegido, ya leído: se importa al pulsar la barra, no al elegirlo,
/// para poder verlo (nombre, tamaño) y quitarlo antes.
class _Archivo {
  final String nombre;
  final String contenido;
  final String meta;

  const _Archivo(this.nombre, this.contenido, this.meta);
}

/// «Nuevo»: primero se elige qué se trae al capítulo (`.md`, revisión
/// `.json` o capítulo en blanco) y luego el archivo, el JSON o el título.
class GImportScreen extends StatefulWidget {
  /// Capítulo al que va la revisión importada.
  final int capituloId;

  const GImportScreen({super.key, required this.capituloId});

  @override
  State<GImportScreen> createState() => _GImportScreenState();
}

class _GImportScreenState extends State<GImportScreen> {
  final _json = TextEditingController();
  final _titulo = TextEditingController();
  _Modo _modo = _Modo.md;
  _Archivo? _archivo;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // La barra se activa en cuanto hay JSON pegado.
    _json.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _json.dispose();
    _titulo.dispose();
    super.dispose();
  }

  bool get _listo => switch (_modo) {
        _Modo.blanco => true,
        _Modo.md => _archivo != null,
        _Modo.json => _archivo != null || _json.text.trim().isNotEmpty,
      };

  void _cambiarModo(_Modo modo) {
    if (modo == _modo) return;
    setState(() {
      _modo = modo;
      _archivo = null;
      _error = null;
      _json.clear();
      _titulo.clear();
    });
  }

  static String _kb(int bytes) => '${(bytes / 1024).ceil()} KB';

  static String _miles(int n) => n
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

  Future<void> _elegirArchivo() async {
    setState(() => _error = null);
    final esMd = _modo == _Modo.md;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: esMd ? ['md', 'markdown', 'txt'] : ['json'],
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
      final String meta;
      if (esMd) {
        final texto = ImportMd.normalizar(contenido);
        if (texto.isEmpty) {
          setState(() => _error = 'Ese archivo está vacío.');
          return;
        }
        final palabras = RegExp(r'\S+').allMatches(texto).length;
        meta = '${_kb(bytes.length)} · ${_miles(palabras)} palabras';
      } else {
        final n = _propuestas(contenido);
        meta = n == null
            ? _kb(bytes.length)
            : '${_kb(bytes.length)} · $n ${n == 1 ? 'propuesta' : 'propuestas'}';
      }
      setState(() => _archivo = _Archivo(archivo.name, contenido, meta));
    } catch (e) {
      setState(() => _error = 'No se pudo abrir el archivo: $e');
    }
  }

  /// Cuántas sugerencias trae una revisión, si se deja leer. Solo es para el
  /// rótulo: si no es un JSON válido, el error sale al importar.
  static int? _propuestas(String contenido) {
    try {
      final j = jsonDecode(contenido);
      final s = j is Map ? j['suggestions'] : null;
      return s is List ? s.length : null;
    } catch (_) {
      return null;
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
          .importRevision(json, capituloId: widget.capituloId);
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

  Future<void> _importar() async {
    switch (_modo) {
      case _Modo.blanco:
        await _enviar(ImportMd.enBlanco(_titulo.text));
      case _Modo.md:
        final a = _archivo!;
        await _enviar(ImportMd.revision(a.nombre, a.contenido));
      case _Modo.json:
        final raw = (_archivo?.contenido ?? _json.text).trim();
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
  }

  @override
  Widget build(BuildContext context) {
    final etiqueta = switch (_modo) {
      _Modo.blanco => 'Crear capítulo',
      _Modo.md => 'Importar capítulo',
      _Modo.json => 'Importar revisión',
    };
    final activo = _listo && !_busy;
    return Scaffold(
      appBar: const GAppBar(title: 'Nuevo'),
      body: SingleChildScrollView(
        padding: GSpacing.pageScroll(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(TextSpan(
              style: GText.cardTitle,
              children: [
                const TextSpan(text: 'Trae un '),
                TextSpan(
                  text: 'capítulo',
                  style: GText.cardTitle.copyWith(
                      color: GColors.accentText, fontStyle: FontStyle.italic),
                ),
              ],
            )),
            const SizedBox(height: GSpacing.gapSm),
            Text(
              'Elige qué traes. Un capítulo suelto se lee y se edita a mano; '
              'una revisión llega con sus sugerencias.',
              style: GText.reason,
            ),
            const SizedBox(height: GSpacing.gap),
            const GMono.muted('1 · Qué importas'),
            const SizedBox(height: GSpacing.gapSm),
            _Opciones(
              modo: _modo,
              onCambia: _busy ? null : _cambiarModo,
            ),
            const SizedBox(height: GSpacing.gap),
            if (_modo == _Modo.blanco)
              ..._paso2Titulo()
            else
              ..._paso2Archivo(),
            if (_error != null) ...[
              const SizedBox(height: GSpacing.gap),
              GMono('✕ ${_error!}', color: GColors.danger),
            ],
          ],
        ),
      ),
      bottomNavigationBar: GFoot.unica(
        label: _busy ? 'Importando…' : etiqueta,
        fill: activo ? GFootFill.red : GFootFill.off,
        onTap: activo ? _importar : null,
      ),
    );
  }

  List<Widget> _paso2Titulo() => [
        const GMono.muted('2 · Título'),
        const SizedBox(height: GSpacing.gapSm),
        Container(
          height: GSpacing.actionBtn,
          padding: const EdgeInsets.symmetric(horizontal: GSpacing.blockV),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: GColors.white,
            border: Border.all(color: GColors.ink, width: GSpacing.border),
          ),
          child: TextField(
            controller: _titulo,
            style: GText.field,
            cursorColor: GColors.blue,
            cursorWidth: GSpacing.caret,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: 'Capítulo 8',
              hintStyle: GText.field.copyWith(color: GColors.grey3),
            ),
          ),
        ),
        const SizedBox(height: GSpacing.gapSm),
        Text('Puedes cambiarlo después.', style: GText.reason),
      ];

  List<Widget> _paso2Archivo() {
    final archivo = _archivo;
    final esJson = _modo == _Modo.json;
    return [
      const GMono.muted('2 · Archivo'),
      const SizedBox(height: GSpacing.gapSm),
      if (archivo != null) ...[
        _TarjetaArchivo(
          archivo: archivo,
          onQuitar: _busy ? null : () => setState(() => _archivo = null),
        ),
        const SizedBox(height: GSpacing.gapSm),
        const GMono('✓ Listo para importar'),
      ] else ...[
        GButton(
          label: esJson ? 'Elegir archivo .json' : 'Elegir archivo .md',
          icon: Icons.upload_file,
          onPressed: _busy ? null : _elegirArchivo,
        ),
        if (esJson) ...[
          const SizedBox(height: GSpacing.blockV),
          const Row(
            children: [
              Expanded(child: GRule()),
              SizedBox(width: 10),
              GMono.muted('o pega el json'),
              SizedBox(width: 10),
              Expanded(child: GRule()),
            ],
          ),
          const SizedBox(height: GSpacing.gapSm),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: GColors.white,
              border: Border.all(color: GColors.ink, width: GSpacing.border),
            ),
            padding: const EdgeInsets.all(GSpacing.blockV),
            child: TextField(
              controller: _json,
              enabled: !_busy,
              style: GText.field,
              cursorColor: GColors.blue,
              cursorWidth: GSpacing.caret,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.none,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '{ "format": "la-jaula-rota-review-v4", … }',
                hintStyle: GText.field.copyWith(color: GColors.grey3),
              ),
            ),
          ),
        ],
      ],
    ];
  }
}

/// Las tres opciones en una caja de tinta; la elegida va rellena de tinta.
class _Opciones extends StatelessWidget {
  final _Modo modo;
  final ValueChanged<_Modo>? onCambia;

  const _Opciones({required this.modo, required this.onCambia});

  static const _filas = [
    (
      _Modo.md,
      '¶',
      'Capítulo .md',
      'El texto entero para leer y editar a mano. Sin tarjetas.'
    ),
    (
      _Modo.json,
      '●',
      'Revisión .json',
      'El capítulo con sus propuestas, para decidir una a una.'
    ),
    (
      _Modo.blanco,
      '＋',
      'Capítulo en blanco',
      'Una página vacía para escribir desde cero.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final onCambia = this.onCambia;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: GColors.ink, width: GSpacing.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (m, glifo, titulo, nota)) in _filas.indexed)
            _Opcion(
              glifo: glifo,
              titulo: titulo,
              nota: nota,
              elegida: m == modo,
              raya: i > 0,
              onTap: onCambia == null ? null : () => onCambia(m),
            ),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final String glifo;
  final String titulo;
  final String nota;
  final bool elegida;
  final bool raya;
  final VoidCallback? onTap;

  const _Opcion({
    required this.glifo,
    required this.titulo,
    required this.nota,
    required this.elegida,
    required this.raya,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final texto = elegida ? GColors.onInk : GColors.ink;
    return Semantics(
      selected: elegida,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(GSpacing.blockV),
          decoration: BoxDecoration(
            color: elegida ? GColors.ink : null,
            border: raya
                ? Border(
                    top: BorderSide(color: GColors.ink, width: GSpacing.border))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Text(glifo,
                    style: GText.rowTitle.copyWith(color: texto, height: 1)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: GSpacing.gapXs,
                  children: [
                    Text(titulo, style: GText.rowTitle.copyWith(color: texto)),
                    Text(nota,
                        style: GText.reason.copyWith(
                            color: elegida ? GColors.onInk : GColors.grey1)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: GSpacing.gapXs),
                child: GMono(elegida ? '●' : '○', color: texto),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El archivo elegido: nombre, tamaño y lo que trae; ✕ para quitarlo.
class _TarjetaArchivo extends StatelessWidget {
  final _Archivo archivo;
  final VoidCallback? onQuitar;

  const _TarjetaArchivo({required this.archivo, required this.onQuitar});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GColors.white,
        border: Border.all(color: GColors.ink, width: GSpacing.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(GSpacing.blockV),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(archivo.nombre,
                        style: GText.block,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    GMono.muted(archivo.meta, small: true),
                  ],
                ),
              ),
            ),
            Tooltip(
              message: 'Quitar archivo',
              child: InkWell(
                onTap: onQuitar,
                child: Container(
                  width: GSpacing.iconBtn,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                        left: BorderSide(
                            color: GColors.ink, width: GSpacing.border)),
                  ),
                  child: const GMono('✕'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
