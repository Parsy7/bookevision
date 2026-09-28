import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';
import 'g_bits.dart';

/// Tarjeta de «Galerada»: borde de tinta, fondo de hoja, radio 0 y sin sombra.
/// Por dentro es una pila de bloques separados por líneas de tinta.
class GCard extends StatelessWidget {
  final List<Widget> children;

  const GCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: GColors.sheet,
          border: Border.all(color: GColors.ink, width: GSpacing.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

/// Cabecera de la tarjeta: tipo y párrafo a la izquierda, estado a la derecha.
class GCardTop extends StatelessWidget {
  final String left;
  final String right;
  final bool pending;

  const GCardTop({
    super.key,
    required this.left,
    required this.right,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: GSpacing.card, vertical: GSpacing.barTop),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: GColors.ink, width: GSpacing.border)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: GMono(left)),
            const SizedBox(width: GSpacing.gapSm),
            GMono('● $right', color: pending ? GColors.red : GColors.ink),
          ],
        ),
      );
}

/// Título de la tarjeta: «3. Adjetivación», con la palabra clave en cursiva
/// roja. [keyword] es el trozo de [title] que va marcado.
class GCardTitle extends StatelessWidget {
  final int number;
  final String title;
  final String? keyword;

  const GCardTitle({
    super.key,
    required this.number,
    required this.title,
    this.keyword,
  });

  @override
  Widget build(BuildContext context) {
    final trozos = <TextSpan>[];
    final marca = keyword;
    if (marca != null && marca.isNotEmpty && title.contains(marca)) {
      final i = title.indexOf(marca);
      if (i > 0) trozos.add(TextSpan(text: title.substring(0, i)));
      trozos.add(TextSpan(text: marca, style: GText.cardTitleEm));
      if (i + marca.length < title.length) {
        trozos.add(TextSpan(text: title.substring(i + marca.length)));
      }
    } else {
      trozos.add(TextSpan(text: title));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          GSpacing.card, GSpacing.blockV, GSpacing.card, GSpacing.gapXs),
      child: Text.rich(
        TextSpan(
          style: GText.cardTitle,
          children: [TextSpan(text: '$number. '), ...trozos],
        ),
      ),
    );
  }
}

/// Bloque de texto dentro de una tarjeta. [GBlockKind] decide el papel: el
/// original tachado, la propuesta sobre blanco, el contexto de una inserción.
enum GBlockKind { strike, proposal, context, plain }

class GBlock extends StatelessWidget {
  final String text;
  final GBlockKind kind;

  /// Etiqueta roja montada sobre la línea superior (la marca «Propuesta»).
  final String? mark;

  const GBlock(this.text, {super.key, this.kind = GBlockKind.plain, this.mark});

  @override
  Widget build(BuildContext context) {
    final estilo = switch (kind) {
      GBlockKind.strike => GText.block.copyWith(
          color: GColors.strike,
          decoration: TextDecoration.lineThrough,
          decorationColor: GColors.red,
          decorationThickness: 1.5,
        ),
      GBlockKind.context => GText.context,
      _ => GText.block,
    };

    final cuerpo = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: GSpacing.card,
        vertical: kind == GBlockKind.context ? GSpacing.barTop : GSpacing.blockV,
      ),
      decoration: BoxDecoration(
        color: kind == GBlockKind.proposal ? GColors.white : null,
        border: const Border(
          top: BorderSide(color: GColors.ink, width: GSpacing.border),
        ),
      ),
      child: Text(text, style: estilo),
    );

    if (mark == null) return cuerpo;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        cuerpo,
        Positioned(
          right: 12,
          top: -9,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            color: GColors.red,
            child: GMono(mark!, color: GColors.onRed),
          ),
        ),
      ],
    );
  }
}

/// Hueco de inserción: recuadro discontinuo rojo «＋ Añadir contenido aquí».
class GSlot extends StatelessWidget {
  final String label;
  const GSlot({super.key, this.label = '＋ Añadir contenido aquí'});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: GSpacing.card),
        child: CustomPaint(
          painter: _Discontinuo(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: GSpacing.gapSm),
            alignment: Alignment.center,
            child: GMono(label, color: GColors.red),
          ),
        ),
      );
}

/// Borde discontinuo: Flutter no trae ninguno, y es el único sitio del diseño
/// que lo pide.
class _Discontinuo extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = GColors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = GSpacing.border;

    const trazo = 5.0;
    const hueco = 4.0;
    void linea(Offset a, Offset b) {
      final total = (b - a).distance;
      final paso = (b - a) / total;
      var recorrido = 0.0;
      while (recorrido < total) {
        final fin = (recorrido + trazo).clamp(0.0, total).toDouble();
        canvas.drawLine(a + paso * recorrido, a + paso * fin, pincel);
        recorrido = fin + hueco;
      }
    }

    linea(Offset.zero, Offset(size.width, 0));
    linea(Offset(size.width, 0), Offset(size.width, size.height));
    linea(Offset(size.width, size.height), Offset(0, size.height));
    linea(Offset(0, size.height), Offset.zero);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Selector segmentado de la posición de una inserción: Antes | Entre |
/// Después. El activo va relleno de tinta.
class GSegmented extends StatelessWidget {
  final List<String> labels;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;

  const GSegmented({
    super.key,
    required this.labels,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: GColors.ink, width: GSpacing.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(values[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: GSpacing.barTop),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: values[i] == selected ? GColors.ink : null,
                    border: i < values.length - 1
                        ? const Border(
                            right: BorderSide(
                                color: GColors.ink, width: GSpacing.border))
                        : null,
                  ),
                  child: GMono(
                    labels[i],
                    color: values[i] == selected ? GColors.onInk : GColors.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Franja de aviso al pie de una tarjeta (eliminar el original).
class GWarn extends StatelessWidget {
  final String text;
  const GWarn(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: GSpacing.card, vertical: GSpacing.blockV),
        decoration: const BoxDecoration(
          color: GColors.red,
          border: Border(top: BorderSide(color: GColors.ink, width: GSpacing.border)),
        ),
        child: Text(text, style: GText.block.copyWith(color: GColors.onRed)),
      );
}
