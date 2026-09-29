import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../services/g_ai_assistant_controller.dart';
import '../../utils/export_md.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import 'g_ai_visuals.dart';
import 'g_bits.dart';

/// Asistente de IA flotante: una burbuja anclada abajo a la derecha que se
/// expande en un panel de chat sin salir de la pantalla que lo aloja (el
/// revisor, o el capítulo original), y que se puede volver a minimizar sin
/// perder la conversación. Colocar como último hijo de un [Stack].
class GAiAssistantOverlay extends StatelessWidget {
  static const _anchoMaxPanel = 600.0;

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
        final bottomSafe = MediaQuery.paddingOf(context).bottom + extraBottomOffset;
        switch (controller.mode) {
          case GAiAssistantMode.hidden:
            return const SizedBox.shrink();
          case GAiAssistantMode.bubble:
            return Positioned(
              right: 12,
              bottom: 12 + bottomSafe,
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
            // Todo el ancho menos el margen de 12 a cada lado; tope de 600
            // para que en tablet no se convierta en una sábana.
            final anchoDisponible = MediaQuery.sizeOf(context).width - 24;
            final ancho = anchoDisponible.clamp(0, _anchoMaxPanel).toDouble();
            final altoDisponible = MediaQuery.sizeOf(context).height - 140 - teclado - extraBottomOffset;
            final alto = controller.panelHeight.clamp(
              GAiAssistantController.minHeight,
              altoDisponible < GAiAssistantController.minHeight
                  ? GAiAssistantController.minHeight
                  : altoDisponible,
            );
            return Positioned(
              right: 12,
              bottom: 12 + bottomSafe + teclado,
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  width: ancho,
                  height: alto,
                  child: _Panel(controller: controller),
                ),
              ),
            );
        }
      },
    );
  }
}

class _Burbuja extends StatelessWidget {
  // 52dp: el mismo alto que GSpacing.actionBtn — pequeña pero sigue siendo
  // un objetivo táctil cómodo, y molesta menos en la esquina.
  static const _tamano = 52.0;

  final GAiAssistantController controller;
  const _Burbuja({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.abrir(),
      child: SizedBox(
        width: _tamano,
        height: _tamano,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const GAiGlow(size: _tamano),
            const GAiOrb(size: _tamano - 4),
            if (controller.hayNuevo)
              Positioned(
                top: 1,
                right: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GColors.red,
                    border: Border.all(color: GColors.paper, width: 2),
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
  final _scroll = ScrollController();

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
    _scrollAlFinal(); // deja ver el mensaje propio y el "escribiendo…" ya mismo
    await envio;
    _scrollAlFinal(); // y de nuevo al llegar la respuesta, por si la lista creció
  }

  Future<void> _copiar(String texto) async {
    await ExportMd.copy(texto);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('COPIADO', style: GText.mono.copyWith(color: GColors.onInk))),
    );
  }

  Future<void> _reintentar(GAiMessage msg) async {
    await widget.controller.reintentar(msg);
    _scrollAlFinal();
  }

  Future<void> _convertir(GAiMessage msg) async {
    final ok = await widget.controller.convertirEnSugerencia(msg);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'SUGERENCIA AÑADIDA AL CAPÍTULO' : 'NO SE PUDO CONVERTIR EN SUGERENCIA',
          style: GText.mono.copyWith(color: GColors.onInk),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Container(
      decoration: BoxDecoration(color: GColors.sheet, border: Border.all(color: GColors.ink, width: GSpacing.border)),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => c.resize(-d.delta.dy),
            child: SizedBox(
              height: 22,
              child: Center(
                child: Container(width: 36, height: 4, color: GColors.grey3),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 2, 8, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
            ),
            child: Row(
              children: [
                const GAiSparkle(size: 15),
                const SizedBox(width: 8),
                const Expanded(child: GMono('Asistente IA')),
                InkWell(
                  onTap: c.minimizar,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(border: Border.all(color: GColors.ink, width: GSpacing.border)),
                    child: Icon(Icons.keyboard_arrow_down, size: 18, color: GColors.ink),
                  ),
                ),
              ],
            ),
          ),
          if (c.seleccionContexto != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(GSpacing.gapSm),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
              ),
              child: Text(
                'Sobre: "${c.seleccionContexto}"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GText.context.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
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
                      if (i == c.messages.length) return const _BurbujaEscribiendo();
                      final mensaje = c.messages[i];
                      return _Burbujita(
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
              border: Border(top: BorderSide(color: GColors.ink, width: GSpacing.border)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: GSpacing.gapSm),
                    decoration: BoxDecoration(
                      color: GColors.white,
                      border: Border.all(color: GColors.ink, width: GSpacing.border),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: GText.field,
                      cursorColor: GColors.blue,
                      cursorWidth: GSpacing.caret,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _enviar(),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: InputBorder.none,
                        hintText: 'Escribe tu mensaje…',
                        hintStyle: GText.field.copyWith(color: GColors.grey3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: GSpacing.gapSm),
                InkWell(
                  onTap: c.enviando ? null : _enviar,
                  child: Container(
                    width: 38,
                    height: 38,
                    color: c.enviando ? GColors.grey3 : GColors.ink,
                    child: Icon(Icons.arrow_upward, size: 18, color: GColors.onInk),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Burbujita extends StatelessWidget {
  final GAiMessage mensaje;
  final VoidCallback onCopiar;
  final VoidCallback onConvertir;
  final VoidCallback onReintentar;
  final bool convirtiendo;

  const _Burbujita({
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
    final esUsuario = mensaje.deUsuario;
    if (esUsuario) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: anchoPanel * 0.8),
          margin: const EdgeInsets.only(bottom: GSpacing.gapSm),
          padding: const EdgeInsets.all(GSpacing.gapSm),
          color: GColors.ink,
          child: Text(mensaje.texto, style: GText.block.copyWith(color: GColors.onInk, fontSize: 14.5)),
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
              decoration: BoxDecoration(color: GColors.white, border: Border.all(color: GColors.ink, width: GSpacing.border)),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 22),
                    // Seleccionable con pulsación larga, como cualquier texto
                    // nativo — para copiar solo un trozo, no el mensaje entero
                    // (eso ya lo hace el icono de copiar de al lado).
                    child: SelectableText(
                      mensaje.texto,
                      style: GText.block.copyWith(
                        fontSize: 14.5,
                        color: mensaje.esError ? GColors.red : null,
                      ),
                      cursorColor: GColors.blue,
                      cursorWidth: GSpacing.caret,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: InkWell(
                      onTap: onCopiar,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(border: Border.all(color: GColors.grey3, width: GSpacing.border)),
                        child: Icon(Icons.copy, size: 11, color: GColors.grey2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (mensaje.esError) ...[
              const SizedBox(height: GSpacing.gapXs),
              InkWell(
                onTap: onReintentar,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: GSpacing.gapSm, vertical: 5),
                  decoration: BoxDecoration(border: Border.all(color: GColors.ink, width: GSpacing.border)),
                  child: const GMono('Reintentar'),
                ),
              ),
            ],
            if (mensaje.seed != null) ...[
              const SizedBox(height: GSpacing.gapXs),
              InkWell(
                onTap: convirtiendo ? null : onConvertir,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: GSpacing.gapSm, vertical: 5),
                  color: convirtiendo ? GColors.grey3 : GColors.red,
                  child: GMono(
                    convirtiendo ? 'Convirtiendo…' : 'Usar como sugerencia',
                    color: GColors.onRed,
                  ),
                ),
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
class _BurbujaEscribiendo extends StatefulWidget {
  const _BurbujaEscribiendo();

  @override
  State<_BurbujaEscribiendo> createState() => _BurbujaEscribiendoState();
}

class _BurbujaEscribiendoState extends State<_BurbujaEscribiendo>
    with SingleTickerProviderStateMixin {
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
  double _salto(int i) {
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
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  decoration: BoxDecoration(
                    color: GColors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border: Border.all(color: GColors.ink, width: GSpacing.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final s = _salto(i);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Transform.translate(
                          offset: Offset(0, -5 * s),
                          child: Transform.scale(
                            scale: 1 + 0.15 * s,
                            child: Container(
                              width: 8,
                              height: 8,
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
                  padding: const EdgeInsets.only(left: 12, top: 3),
                  child: _burbujita(9, 0.7 + 0.3 * respira),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 2),
                  child: _burbujita(5, 0.7 + 0.3 * (1 - respira)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
