import 'package:flutter/material.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../theme/g_text.dart';

/// Pinta el Markdown que devuelve la IA con la tipografía de la casa. Solo
/// el subconjunto que se le pide en el prompt (ver `AiController`):
/// títulos `###`, citas `>` (el texto que propone), listas, separadores
/// `---`, **negrita** y *cursiva*. Lo demás sale como texto normal.
class GAiMarkdown extends StatelessWidget {
  final String texto;
  final Color? color;

  const GAiMarkdown(this.texto, {super.key, this.color});

  /// El mismo texto sin marcas, para copiarlo al portapapeles.
  static String textoPlano(String md) {
    final lineas = <String>[];
    for (final b in _bloques(md)) {
      lineas.add(switch (b) {
        _Titulo(:final texto) || _Parrafo(:final texto) || _Cita(:final texto) =>
          _sinMarcas(texto),
        _Item(:final marca, :final texto) => '$marca ${_sinMarcas(texto)}',
        _Separador() => '',
      });
    }
    return lineas.join('\n\n').trim();
  }

  @override
  Widget build(BuildContext context) {
    final base = color == null ? GText.chat : GText.chat.copyWith(color: color);
    final bloques = _bloques(texto);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < bloques.length; i++) ...[
          if (i > 0) const SizedBox(height: GSpacing.gapSm),
          _pintar(bloques[i], base),
        ],
      ],
    );
  }

  Widget _pintar(_Bloque b, TextStyle base) => switch (b) {
        _Titulo(:final texto) => Text.rich(_enLinea(texto, GText.chatTitle)),
        _Parrafo(:final texto) => Text.rich(_enLinea(texto, base)),
        _Cita(:final texto) => Container(
            padding: const EdgeInsets.only(left: GSpacing.gapSm),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: GColors.blue, width: GSpacing.stripe),
              ),
            ),
            child: Text.rich(_enLinea(texto, base)),
          ),
        _Item(:final marca, :final texto) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(marca, style: base),
              const SizedBox(width: GSpacing.gapXs),
              Expanded(child: Text.rich(_enLinea(texto, base))),
            ],
          ),
        _Separador() => Container(height: GSpacing.border, color: GColors.grey3),
      };
}

sealed class _Bloque {}

class _Titulo extends _Bloque {
  final String texto;
  _Titulo(this.texto);
}

class _Parrafo extends _Bloque {
  final String texto;
  _Parrafo(this.texto);
}

class _Cita extends _Bloque {
  final String texto;
  _Cita(this.texto);
}

class _Item extends _Bloque {
  final String marca;
  final String texto;
  _Item(this.marca, this.texto);
}

class _Separador extends _Bloque {}

final _reTitulo = RegExp(r'^#{1,6}\s+(.*)$');
final _reSeparador = RegExp(r'^(-{3,}|\*{3,}|_{3,})$');
final _reVineta = RegExp(r'^[-*+]\s+(.*)$');
final _reNumero = RegExp(r'^(\d+)[.)]\s+(.*)$');
final _reCita = RegExp(r'^>\s?(.*)$');

List<_Bloque> _bloques(String md) {
  final bloques = <_Bloque>[];
  final parrafo = <String>[];
  final cita = <String>[];

  void cerrarParrafo() {
    if (parrafo.isEmpty) return;
    bloques.add(_Parrafo(parrafo.join('\n')));
    parrafo.clear();
  }

  void cerrarCita() {
    // Un `>` vacío dentro de una cita separa párrafos de la misma cita.
    final texto = cita.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (texto.isNotEmpty) bloques.add(_Cita(texto));
    cita.clear();
  }

  for (final crudo in md.replaceAll('\r\n', '\n').split('\n')) {
    final linea = crudo.trim();
    final esCita = _reCita.firstMatch(linea);
    if (esCita != null) {
      cerrarParrafo();
      cita.add(esCita.group(1)!);
      continue;
    }
    cerrarCita();
    if (linea.isEmpty) {
      cerrarParrafo();
    } else if (_reSeparador.hasMatch(linea)) {
      cerrarParrafo();
      bloques.add(_Separador());
    } else if (_reTitulo.firstMatch(linea) case final m?) {
      cerrarParrafo();
      bloques.add(_Titulo(m.group(1)!));
    } else if (_reVineta.firstMatch(linea) case final m?) {
      cerrarParrafo();
      bloques.add(_Item('•', m.group(1)!));
    } else if (_reNumero.firstMatch(linea) case final m?) {
      cerrarParrafo();
      bloques.add(_Item('${m.group(1)}.', m.group(2)!));
    } else {
      parrafo.add(linea);
    }
  }
  cerrarCita();
  cerrarParrafo();
  return bloques;
}

/// `**negrita**`, `*cursiva*` y `` `código` `` (este último sin estilo
/// propio: solo se le quitan las comillas).
final _reEnLinea = RegExp(r'\*\*(.+?)\*\*|\*(?!\s)(.+?)\*|`([^`]+)`');

TextSpan _enLinea(String texto, TextStyle base) {
  final trozos = <TextSpan>[];
  var desde = 0;
  for (final m in _reEnLinea.allMatches(texto)) {
    if (m.start > desde) trozos.add(TextSpan(text: texto.substring(desde, m.start)));
    if (m.group(1) != null) {
      trozos.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
    } else if (m.group(2) != null) {
      trozos.add(TextSpan(
        text: m.group(2),
        style: const TextStyle(fontStyle: FontStyle.italic),
      ));
    } else {
      trozos.add(TextSpan(text: m.group(3)));
    }
    desde = m.end;
  }
  if (desde < texto.length) trozos.add(TextSpan(text: texto.substring(desde)));
  return TextSpan(style: base, children: trozos);
}

String _sinMarcas(String texto) => _enLinea(texto, const TextStyle()).toPlainText();
