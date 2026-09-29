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
  final GAiAssistantController controller;

  const GAiAssistantOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final bottomSafe = MediaQuery.paddingOf(context).bottom;
        switch (controller.mode) {
          case GAiAssistantMode.hidden:
            return const SizedBox.shrink();
          case GAiAssistantMode.bubble:
            return Positioned(
              right: 16,
              bottom: 16 + bottomSafe,
              child: _Burbuja(controller: controller),
            );
          case GAiAssistantMode.panel:
            // El teclado ocupa `viewInsets.bottom`: sin sumarlo aquí, el panel
            // (y su campo de texto) se queda debajo del teclado al escribir.
            final teclado = MediaQuery.viewInsetsOf(context).bottom;
            final anchoDisponible = MediaQuery.sizeOf(context).width - 24;
            final ancho = anchoDisponible.clamp(0, 340).toDouble();
            final altoDisponible = MediaQuery.sizeOf(context).height - 140 - teclado;
            final alto = controller.panelHeight.clamp(
              GAiAssistantController.minHeight,
              altoDisponible < GAiAssistantController.minHeight
                  ? GAiAssistantController.minHeight
                  : altoDisponible,
            );
            return Positioned(
              right: 12,
              bottom: 12 + bottomSafe + teclado,
              child: SizedBox(
                width: ancho,
                height: alto,
                child: _Panel(controller: controller),
              ),
            );
        }
      },
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
        width: 64,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const GAiGlow(size: 64),
            const GAiOrb(size: 60),
            if (controller.hayNuevo)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
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
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Column(
                children: [
                  Container(width: 36, height: 4, color: GColors.grey3),
                  const SizedBox(height: 2),
                  Text('arrastra para estirar',
                      style: GText.monoSm.copyWith(color: GColors.grey3, fontSize: 8)),
                ],
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
  final bool convirtiendo;

  const _Burbujita({
    required this.mensaje,
    required this.onCopiar,
    required this.onConvertir,
    required this.convirtiendo,
  });

  @override
  Widget build(BuildContext context) {
    final esUsuario = mensaje.deUsuario;
    if (esUsuario) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
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
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
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
                    child: Text(mensaje.texto, style: GText.block.copyWith(fontSize: 14.5)),
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

/// Bocadillo de "la IA está escribiendo": tres puntos que se van iluminando
/// en cadena, mientras se espera la respuesta.
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

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: GSpacing.gapSm),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: GColors.white, border: Border.all(color: GColors.ink, width: GSpacing.border)),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final fase = ((_c.value - i * 0.22) % 1.0 + 1.0) % 1.0;
                final opacidad = 0.25 + 0.75 * (1 - (fase * 2 - 1).abs()).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Opacity(
                    opacity: opacidad,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: GColors.grey2),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
