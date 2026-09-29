import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_app_bar.dart';

class _Mensaje {
  final String texto;
  final bool deUsuario;
  const _Mensaje(this.texto, this.deUsuario);
}

/// Chat libre con la IA para pensar en voz alta: ideas, dudas de trama, ayuda
/// con una escena. Sin histórico persistido — se pierde al salir.
class GChatScreen extends StatefulWidget {
  const GChatScreen({super.key});

  @override
  State<GChatScreen> createState() => _GChatScreenState();
}

class _GChatScreenState extends State<GChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_Mensaje> _mensajes = [];
  bool _enviando = false;

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
    final texto = _controller.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() {
      _mensajes.add(_Mensaje(texto, true));
      _controller.clear();
      _enviando = true;
    });
    _scrollAlFinal();
    try {
      final respuesta = await context.read<ApiService>().chat(texto);
      if (!mounted) return;
      setState(() => _mensajes.add(_Mensaje(respuesta, false)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _mensajes.add(_Mensaje('✕ No se pudo responder: $e', false)));
    } finally {
      if (mounted) setState(() => _enviando = false);
      _scrollAlFinal();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GAppBar(title: 'Chat con la IA'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _mensajes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(GSpacing.page),
                        child: Text(
                          'Pregunta lo que sea: ideas, dudas de trama, ayuda '
                          'con una escena…',
                          style: GText.reason,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(GSpacing.page),
                      itemCount: _mensajes.length,
                      itemBuilder: (_, i) => _Burbuja(mensaje: _mensajes[i]),
                    ),
            ),
            _CampoDeEntrada(
              controller: _controller,
              enviando: _enviando,
              onEnviar: _enviar,
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoDeEntrada extends StatelessWidget {
  final TextEditingController controller;
  final bool enviando;
  final VoidCallback onEnviar;

  const _CampoDeEntrada({
    required this.controller,
    required this.enviando,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GSpacing.page),
      decoration: BoxDecoration(
        color: GColors.paper,
        border: Border(top: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: GSpacing.blockV),
              decoration: BoxDecoration(
                color: GColors.white,
                border: Border.all(color: GColors.ink, width: GSpacing.border),
              ),
              child: TextField(
                controller: controller,
                style: GText.field,
                cursorColor: GColors.blue,
                cursorWidth: GSpacing.caret,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onEnviar(),
                decoration: InputDecoration(
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                  hintText: 'Escribe tu mensaje…',
                  hintStyle: GText.field.copyWith(color: GColors.grey3),
                ),
              ),
            ),
          ),
          const SizedBox(width: GSpacing.blockV),
          InkWell(
            onTap: enviando ? null : onEnviar,
            child: Container(
              width: GSpacing.actionBtn,
              height: GSpacing.actionBtn,
              decoration: BoxDecoration(
                color: enviando ? GColors.grey3 : GColors.ink,
                border: Border.all(
                  color: enviando ? GColors.grey3 : GColors.ink,
                  width: GSpacing.border,
                ),
              ),
              child: Icon(Icons.arrow_upward, color: GColors.onInk),
            ),
          ),
        ],
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  final _Mensaje mensaje;
  const _Burbuja({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final esUsuario = mensaje.deUsuario;
    return Align(
      alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        margin: const EdgeInsets.only(bottom: GSpacing.gapSm),
        padding: const EdgeInsets.all(GSpacing.blockV),
        decoration: BoxDecoration(
          color: esUsuario ? GColors.ink : GColors.sheet,
          border: Border.all(color: GColors.ink, width: GSpacing.border),
        ),
        child: Text(
          mensaje.texto,
          style: GText.block.copyWith(color: esUsuario ? GColors.onInk : GColors.ink),
        ),
      ),
    );
  }
}
