import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../services/g_ai_assistant_controller.dart';
import '../../utils/export_md.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import 'g_ai_markdown.dart';
import 'g_ai_visuals.dart';
import 'g_bits.dart';
import 'g_button.dart';

/// Lo que comparten todas las pantallas con asistente: el botón flotante
/// "Preguntar a la IA" cuando hay texto seleccionado, y la burbuja/panel del
/// chat. La pantalla solo avisa de la selección ([seleccionCambia] /
/// [ocultarPill]) y envuelve su `Scaffold` con [conAsistente].
mixin GAiConAsistente<T extends StatefulWidget> on State<T> {
  String? _seleccion;
  bool _anclable = true;

  /// [anclable] en `false` cuando el fragmento no está tal cual en el
  /// capítulo original (vista previa, "Escribir yo"): se puede preguntar
  /// sobre él, pero la respuesta no se puede convertir en sugerencia.
  void seleccionCambia(String seleccion, {bool anclable = true}) {
    setState(() {
      _seleccion = seleccion;
      _anclable = anclable;
    });
  }

  void ocultarPill() {
    if (!mounted || _seleccion == null) return;
    setState(() => _seleccion = null);
  }

  Widget conAsistente(
    Widget pantalla,
    GAiAssistantController? ai, {
    double extraBottomOffset = 0,
  }) {
    final seleccion = _seleccion;
    return Stack(
      children: [
        pantalla,
        if (ai != null && seleccion != null)
          GAiSelectionPillOverlay(onTap: () {
            ai.abrir(seleccion: seleccion, anclable: _anclable);
            ocultarPill();
          }),
        if (ai != null)
          GAiAssistantOverlay(
              controller: ai, extraBottomOffset: extraBottomOffset),
      ],
    );
  }
}

/// Asistente de IA flotante: una burbuja anclada abajo a la derecha que se
/// expande en un panel de chat sin salir de la pantalla que lo aloja, y que
/// se puede volver a minimizar sin perder la conversación. Colocar como
/// último hijo de un [Stack] (lo hace [GAiConAsistente.conAsistente]).
class GAiAssistantOverlay extends StatelessWidget {
  final GAiAssistantController controller;

  /// Alto de lo que ya ocupe la esquina inferior derecha en esa pantalla
  /// (la barra de navegación del lector, p. ej. `GSpacing.foot`), para que
  /// la burbuja y el panel floten por encima en vez de taparla.
  final double extraBottomOffset;

  const GAiAssistantOverlay({
    super.key,
    required this.controller,
    this.extraBottomOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final bottomSafe =
            MediaQuery.paddingOf(context).bottom + extraBottomOffset;
        switch (controller.mode) {
          case GAiAssistantMode.hidden:
            return const SizedBox.shrink();
          case GAiAssistantMode.bubble:
            return Positioned(
              right: GSpacing.aiEdge,
              bottom: GSpacing.aiEdge + bottomSafe,
              // `Material` porque este widget vive fuera del Scaffold (como
              // hermano suyo en el Stack de la pantalla): sin esto, cualquier
              // InkWell de dentro no encuentra ancestro y revienta.
              child: Material(
                type: MaterialType.transparency,
                child: _Burbuja(controller: controller),
              ),
            );
          case GAiAssistantMode.panel:
            // El teclado ocupa `viewInsets.bottom`: sin sumarlo aquí, el panel
            // (y su campo de texto) se queda debajo del teclado al escribir.
            final teclado = MediaQuery.viewInsetsOf(context).bottom;
            final pantalla = MediaQuery.sizeOf(context);
            final ancho = (pantalla.width - 2 * GSpacing.aiEdge)
                .clamp(0, GSpacing.aiPanelMax)
                .toDouble();
            final altoDisponible = pantalla.height -
                GSpacing.aiPanelTop -
                teclado -
                extraBottomOffset;
            final alto = controller.panelHeight
                .clamp(
                  GAiAssistantController.minHeight,
                  math.max(GAiAssistantController.minHeight, altoDisponible),
                )
                .toDouble();
            return Positioned.fill(
              child: Stack(
                children: [
                  Positioned.fill(child: _Velo(onTap: controller.minimizar)),
                  Positioned(
                    right: GSpacing.aiEdge,
                    bottom: GSpacing.aiEdge + bottomSafe + teclado,
                    child: Material(
                      type: MaterialType.transparency,
                      child: SizedBox(
                        width: ancho,
                        height: alto,
                        child: _Panel(controller: controller),
                      ),
                    ),
                  ),
                ],
              ),
            );
        }
      },
    );
  }
}

/// Capa oscura detrás del panel abierto: lo separa del capítulo y, al
/// tocarla, minimiza el chat.
class _Velo extends StatelessWidget {
  final VoidCallback onTap;
  const _Velo({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = GColors.scrim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 180),
        builder: (context, t, _) =>
            ColoredBox(color: color.withValues(alpha: color.a * t)),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  final GAiAssistantController controller;
  const _Burbuja({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.abrir(),
      child: SizedBox(
        width: GSpacing.aiBubble,
        height: GSpacing.aiBubble,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const GAiGlow(size: GSpacing.aiBubble),
            const GAiOrb(size: GSpacing.aiBubble - GSpacing.gapXs),
            if (controller.hayNuevo)
              Positioned(
                top: GSpacing.border,
                right: GSpacing.border,
                child: Container(
                  width: GSpacing.aiBadge,
                  height: GSpacing.aiBadge,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GColors.red,
                    border: Border.all(
                        color: GColors.paper, width: GSpacing.aiBadgeRing),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatefulWidget {
  final GAiAssistantController controller;
  const _Panel({required this.controller});

  @override
  State<_Panel> createState() => _PanelState();
}

class _PanelState extends State<_Panel> {
  final _controller = TextEditingController();
  late final ScrollController _scroll;

  /// Al abrir, el campo queda enfocado (se ve el cursor) pero sin teclado:
  /// en solo lectura no abre conexión con el teclado. El primer toque lo
  /// pasa a editable y, como ya tiene el foco, el teclado sale entonces.
  bool _soloFoco = true;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _scroll = ScrollController(initialScrollOffset: c.scrollOffset ?? 0)
      ..addListener(() => c.scrollOffset = _scroll.offset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      final guardado = c.scrollOffset;
      if (guardado == null || guardado > max) _scroll.jumpTo(max);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _enviar() async {
    final texto = _controller.text;
    if (texto.trim().isEmpty) return;
    _controller.clear();
    final envio = widget.controller.enviar(texto);
    _scrollAlFinal(); // deja ver el mensaje propio y el "pensando…" ya mismo
    await envio;
    _scrollAlFinal(); // y de nuevo al llegar la respuesta, por si la lista creció
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(texto, style: GText.mono.copyWith(color: GColors.onInk))),
    );
  }

  Future<void> _copiar(String texto) async {
    await ExportMd.copy(GAiMarkdown.textoPlano(texto));
    if (mounted) _avisar('COPIADO');
  }

  Future<void> _reintentar(GAiMessage msg) async {
    await widget.controller.reintentar(msg);
    _scrollAlFinal();
  }

  Future<void> _convertir(GAiMessage msg) async {
    final ok = await widget.controller.convertirEnSugerencia(msg);
    if (mounted) {
      _avisar(ok
          ? 'SUGERENCIA AÑADIDA AL CAPÍTULO'
          : 'NO SE PUDO CONVERTIR EN SUGERENCIA');
    }
  }

  Border get _linea =>
      Border(bottom: BorderSide(color: GColors.ink, width: GSpacing.border));

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Container(
      decoration: BoxDecoration(
        color: GColors.sheet,
        border: Border.all(color: GColors.ink, width: GSpacing.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => c.resize(-d.delta.dy),
            child: SizedBox(
              height: GSpacing.aiHandle,
              child: Center(
                child: Container(
                  width: GSpacing.aiHandleW,
                  height: GSpacing.aiHandleH,
                  color: GColors.grey3,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
                GSpacing.blockV, 0, GSpacing.gapSm, GSpacing.gapSm),
            decoration: BoxDecoration(border: _linea),
            child: Row(
              children: [
                const GAiSparkle(),
                const SizedBox(width: GSpacing.gapSm),
                const Expanded(child: GMono('Asistente IA')),
                GIconButton(
                  icon: Icons.keyboard_arrow_down,
                  tooltip: 'Minimizar',
                  outlined: true,
                  onPressed: c.minimizar,
                ),
              ],
            ),
          ),
          if (c.seleccionContexto != null)
            _Contexto(texto: c.seleccionContexto!),
          Expanded(
            child: c.messages.isEmpty && !c.enviando
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(GSpacing.page),
                      child: Text(
                        'Pregunta lo que sea: ideas, dudas de trama, ayuda con una escena…',
                        style: GText.reason,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(GSpacing.blockV),
                    itemCount: c.messages.length + (c.enviando ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == c.messages.length)
                        return const _BurbujaPensando();
                      final mensaje = c.messages[i];
                      return _Mensaje(
                        mensaje: mensaje,
                        onCopiar: () => _copiar(mensaje.texto),
                        onConvertir: () => _convertir(mensaje),
                        onReintentar: () => _reintentar(mensaje),
                        convirtiendo: c.convirtiendo,
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(GSpacing.gapSm),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: GColors.ink, width: GSpacing.border)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: GSpacing.gapSm),
                      decoration: BoxDecoration(
                        color: GColors.white,
                        border: Border.all(
                            color: GColors.ink, width: GSpacing.border),
                      ),
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        readOnly: _soloFoco,
                        showCursor: true,
                        onTap: () {
                          if (_soloFoco) setState(() => _soloFoco = false);
                        },
                        style: GText.field,
                        cursorColor: GColors.blue,
                        cursorWidth: GSpacing.caret,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _enviar(),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: GSpacing.barTop),
                          border: InputBorder.none,
                          hintText: 'Escribe tu mensaje…',
                          hintStyle: GText.field.copyWith(color: GColors.grey3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: GSpacing.gapSm),
                  GIconButton(
                    icon: Icons.arrow_upward,
                    tooltip: 'Enviar',
                    onPressed: c.enviando ? null : _enviar,
                    stretch: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Sobre: …" — el fragmento por el que se pregunta. Recortado a dos líneas;
/// al tocarlo se ve entero (con scroll si es muy largo), y otro toque lo
/// vuelve a recoger.
class _Contexto extends StatefulWidget {
  final String texto;
  const _Contexto({required this.texto});

  @override
  State<_Contexto> createState() => _ContextoState();
}

class _ContextoState extends State<_Contexto> {
  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final estilo = GText.context.copyWith(fontStyle: FontStyle.italic);
    final texto = 'Sobre: "${widget.texto}"';
    return InkWell(
      onTap: () => setState(() => _abierto = !_abierto),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(GSpacing.gapSm),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _abierto
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxHeight: GSpacing.aiContextMax),
                      child: SingleChildScrollView(
                          child: Text(texto, style: estilo)),
                    )
                  : Text(texto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: estilo),
            ),
            Icon(
              _abierto ? Icons.expand_less : Icons.expand_more,
              color: GColors.grey2,
            ),
          ],
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final GAiMessage mensaje;
  final VoidCallback onCopiar;
  final VoidCallback onConvertir;
  final VoidCallback onReintentar;
  final bool convirtiendo;

  const _Mensaje({
    required this.mensaje,
    required this.onCopiar,
    required this.onConvertir,
    required this.onReintentar,
    required this.convirtiendo,
  });

  @override
  Widget build(BuildContext context) {
    // Proporción del panel, no de la pantalla: en tablet el panel tiene tope
    // de ancho y la pantalla no.
    return LayoutBuilder(
      builder: (context, constraints) => _contenido(constraints.maxWidth),
    );
  }

  Widget _contenido(double anchoPanel) {
    if (mensaje.deUsuario) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: anchoPanel * 0.8),
          margin: const EdgeInsets.only(bottom: GSpacing.gapSm),
          padding: const EdgeInsets.all(GSpacing.gapSm),
          color: GColors.ink,
          child: Text(mensaje.texto,
              style: GText.chat.copyWith(color: GColors.onInk)),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: anchoPanel * 0.88),
        margin: const EdgeInsets.only(bottom: GSpacing.gapSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(GSpacing.gapSm),
              decoration: BoxDecoration(
                color: GColors.white,
                border: Border.all(color: GColors.ink, width: GSpacing.border),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.only(right: GSpacing.aiCopyGutter),
                    // Seleccionable con pulsación larga, para copiar solo un
                    // trozo (el mensaje entero ya lo copia el icono).
                    child: SelectionArea(
                      child: GAiMarkdown(
                        mensaje.texto,
                        color: mensaje.esError ? GColors.red : null,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: InkWell(
                      onTap: onCopiar,
                      child: Container(
                        width: GSpacing.aiCopy,
                        height: GSpacing.aiCopy,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: GColors.grey3, width: GSpacing.border),
                        ),
                        child: Icon(Icons.copy, size: 11, color: GColors.grey2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (mensaje.esError) ...[
              const SizedBox(height: GSpacing.gapXs),
              GChip('Reintentar', onTap: onReintentar),
            ],
            if (mensaje.seed != null) ...[
              const SizedBox(height: GSpacing.gapXs),
              GChip(
                convirtiendo ? 'Convirtiendo…' : 'Usar como sugerencia',
                onTap: convirtiendo ? null : onConvertir,
                color: GColors.red,
                onColor: GColors.onRed,
                filled: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bocadillo de "la IA está pensando": una nube de pensamiento de cómic (con
/// sus dos burbujitas de cola) y tres puntos con los colores de la IA que
/// saltan por turnos mientras se espera la respuesta.
class _BurbujaPensando extends StatefulWidget {
  const _BurbujaPensando();

  @override
  State<_BurbujaPensando> createState() => _BurbujaPensandoState();
}

class _BurbujaPensandoState extends State<_BurbujaPensando>
    with SingleTickerProviderStateMixin {
  // Geometría del dibujo (no son márgenes de maqueta): tamaño de los puntos,
  // altura del salto y las dos burbujitas de la cola, de mayor a menor.
  static const _punto = 8.0;
  static const _salto = 5.0;
  static const _cola = 9.0;
  static const _colita = 5.0;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0 en reposo, 1 en lo alto del salto. Cada punto salta en la primera
  /// mitad de su ciclo y descansa en la segunda, así se ven "por turnos".
  double _altura(int i) {
    final fase = ((_c.value - i * 0.16) % 1.0 + 1.0) % 1.0;
    if (fase > 0.5) return 0;
    return math.sin(fase * 2 * math.pi);
  }

  Widget _burbujita(double tamano, double opacidad) => Opacity(
        opacity: opacidad,
        child: Container(
          width: tamano,
          height: tamano,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GColors.white,
            border: Border.all(color: GColors.ink, width: GSpacing.border),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: GSpacing.gapSm),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            // Las burbujitas de la cola "respiran" un poco, desfasadas.
            final respira = 0.5 + 0.5 * math.sin(_c.value * 2 * math.pi);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: GSpacing.gap, vertical: GSpacing.blockV),
                  decoration: BoxDecoration(
                    color: GColors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border:
                        Border.all(color: GColors.ink, width: GSpacing.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final s = _altura(i);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: GSpacing.gapXs / 2),
                        child: Transform.translate(
                          offset: Offset(0, -_salto * s),
                          child: Transform.scale(
                            scale: 1 + 0.15 * s,
                            child: Container(
                              width: _punto,
                              height: _punto,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: GAiColors.gradient[i],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                      left: GSpacing.blockV, top: GSpacing.gapXs),
                  child: _burbujita(_cola, 0.7 + 0.3 * respira),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                      left: GSpacing.gapSm, top: GSpacing.gapXs / 2),
                  child: _burbujita(_colita, 0.7 + 0.3 * (1 - respira)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
