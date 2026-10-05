import 'package:flutter/material.dart';
import '../../services/review_session.dart';
import '../../utils/export_md.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import '../widgets/g_button.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_foot.dart';
import '../widgets/g_prose.dart';

/// Confirmación final: los recuentos como filas de galerada —número grande a
/// la izquierda, etiqueta y explicación a la derecha— y el capítulo definitivo
/// debajo. La barra se parte en Guardar .md | Copiar todo.
class GConfirmScreen extends StatelessWidget {
  final String title;
  final String text;
  final Counts counts;

  const GConfirmScreen({
    super.key,
    required this.title,
    required this.text,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const _Cabecera(),
          if (counts.total > 0) ...[
            _Recuento(
              n: counts.accepted,
              label: _plural(counts.accepted, 'Propuesta aceptada',
                  'Propuestas aceptadas'),
              note: 'Se aplicará exactamente el texto propuesto.',
            ),
            _Recuento(
              n: counts.originals,
              label: _plural(counts.originals, 'Original conservado',
                  'Originales conservados'),
              note: 'Esos fragmentos permanecerán como estaban.',
            ),
            _Recuento(
              n: counts.custom,
              label: _plural(counts.custom, 'Respuesta personalizada',
                  'Respuestas personalizadas'),
              note: 'Se usará tu propia versión.',
            ),
            _Recuento(
              n: counts.omitted,
              label: _plural(counts.omitted, 'Fragmento eliminado',
                  'Fragmentos eliminados'),
              note: 'No aparecerá en el capítulo.',
              rojo: true,
            ),
          ],
          _Recuento(
            n: counts.manual,
            label: _plural(counts.manual, 'Bloque editado a mano',
                'Bloques editados a mano'),
            note: 'Cambios fuera de las tarjetas.',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(GSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GMono('Capítulo definitivo'),
                  const SizedBox(height: GSpacing.gap),
                  GProseFlow(text),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: GFoot.partida(
        leftLabel: 'Guardar .md',
        rightLabel: 'Copiar todo',
        onLeft: () => ExportMd.share(title, 'definitivo', text),
        onRight: () async {
          await ExportMd.copy(text);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copiado al portapapeles'.toUpperCase(),
                    style: GText.mono.copyWith(color: GColors.onInk)),
              ),
            );
          }
        },
      ),
    );
  }

  static String _plural(int n, String singular, String plural) =>
      n == 1 ? singular : plural;
}

/// Fila de recuento: número a 40px, etiqueta y explicación en cursiva.
class _Recuento extends StatelessWidget {
  final int n;
  final String label;
  final String note;
  final bool rojo;

  const _Recuento({
    required this.n,
    required this.label,
    required this.note,
    this.rojo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GColors.sheet,
        border: Border(
            bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(
                  left: GSpacing.page, top: GSpacing.card),
              child: Text(
                '$n',
                style: GText.bigNumber
                    .copyWith(color: rojo ? GColors.accentText : GColors.ink),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  0, GSpacing.card, GSpacing.page, GSpacing.card),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GText.statLabel),
                  const SizedBox(height: 2),
                  Text(note, style: GText.statNote),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Atrás y, debajo, «Tu capítulo quedará *así*» a tamaño de tarjeta. Va en
/// el cuerpo y no como `appBar`, para medir lo que necesite el titular; por
/// eso se reserva ella misma el hueco de la barra de estado.
class _Cabecera extends StatelessWidget {
  const _Cabecera();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GColors.paper,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(GSpacing.page, GSpacing.barBottom,
              GSpacing.page, GSpacing.barBottom),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GSpacing.card,
            children: [
              GIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Atrás',
                outlined: true,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Text.rich(TextSpan(
                style: GText.cardTitle,
                children: [
                  const TextSpan(text: 'Tu capítulo quedará '),
                  TextSpan(
                    text: 'así',
                    style: GText.cardTitle.copyWith(
                        color: GColors.accentText, fontStyle: FontStyle.italic),
                  ),
                ],
              )),
            ],
          ),
        ),
      ),
    );
  }
}
