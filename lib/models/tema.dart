import 'package:flutter/painting.dart';

/// Un tema de color de la piel Galerada. Vive en la base de datos
/// (`GET /temas`): añadir uno nuevo es un INSERT, sin tocar código.
///
/// Los derivados de siempre (onInk, onBlue, scrim, press) no se guardan: se
/// calculan a partir de [paper]/[white]/[ink]. Los tres tokens que llegaron
/// con «Marino y dorado» ([acentoTexto], [peligro], [sobreAcento]) son
/// opcionales en la tabla: sin valor, cada uno cae en lo que era antes.
class Tema {
  final int id;
  final String nombre;
  final Color paper;
  final Color sheet;
  final Color white;
  final Color ink;
  final Color acento;
  final Color blue;
  final Color grey1;
  final Color grey2;
  final Color grey3;
  final Color strike;

  final Color? _acentoTexto;
  final Color? _peligro;
  final Color? _sobreAcento;

  const Tema({
    required this.id,
    required this.nombre,
    required this.paper,
    required this.sheet,
    required this.white,
    required this.ink,
    required this.acento,
    required this.blue,
    required this.grey1,
    required this.grey2,
    required this.grey3,
    required this.strike,
    Color? acentoTexto,
    Color? peligro,
    Color? sobreAcento,
  })  : _acentoTexto = acentoTexto,
        _peligro = peligro,
        _sobreAcento = sobreAcento;

  /// Rojo del corrector: el peligro de los temas que no traen uno propio.
  static const Color peligroClasico = Color(0xFFE4401C);

  /// El acento cuando va como **texto** sobre papel (la palabra destacada de
  /// un titular). Un acento claro, como el dorado, rellena bien pero no se
  /// lee como letra: entonces el tema trae uno más hondo.
  Color get acentoTexto => _acentoTexto ?? acento;

  /// Lo irreversible: borrar un capítulo, una revisión, las decisiones.
  Color get peligro => _peligro ?? peligroClasico;

  /// Texto e iconos sobre un relleno de [acento]. Si el tema no trae uno, se
  /// elige por la luz del acento: blanco sobre uno oscuro (el rojo de
  /// Clásico) y tinta sobre uno claro (el dorado), que en blanco no se lee.
  Color get sobreAcento =>
      _sobreAcento ?? (acento.computeLuminance() > _acentoClaro ? ink : white);

  /// Por encima de esta luminancia relativa el acento cuenta como claro. El
  /// rojo de Clásico ronda 0,23 y el dorado de Marino 0,39.
  static const double _acentoClaro = 0.3;

  /// Texto e iconos sobre un relleno de [peligro]: siempre oscuro, así que
  /// siempre blanco.
  Color get sobrePeligro => white;

  Color get onInk => paper;
  Color get onBlue => white;
  Color get scrim => ink.withAlpha(0x8C);
  Color get press => ink.withAlpha(0x0F);

  /// Tema por defecto, hardcodeado: lo que pinta la app si nunca ha podido
  /// hablar con el servidor (primer arranque sin red, por ejemplo).
  static const Tema clasico = Tema(
    id: 1,
    nombre: 'Clásico',
    paper: Color(0xFFF3F0E8),
    sheet: Color(0xFFFBFAF6),
    white: Color(0xFFFFFFFF),
    ink: Color(0xFF141414),
    acento: Color(0xFFE4401C),
    blue: Color(0xFF2449D8),
    grey1: Color(0xFF5E594F),
    grey2: Color(0xFF6B665E),
    grey3: Color(0xFF8A847A),
    strike: Color(0xFF6D675D),
  );

  factory Tema.fromJson(Map<String, dynamic> j) => Tema(
        id: (j['id'] as num).toInt(),
        nombre: j['nombre'] as String,
        paper: _fromHex(j['paper'] as String),
        sheet: _fromHex(j['sheet'] as String),
        white: _fromHex(j['white'] as String),
        ink: _fromHex(j['ink'] as String),
        acento: _fromHex(j['acento'] as String),
        blue: _fromHex(j['blue'] as String),
        grey1: _fromHex(j['grey1'] as String),
        grey2: _fromHex(j['grey2'] as String),
        grey3: _fromHex(j['grey3'] as String),
        strike: _fromHex(j['strike'] as String),
        acentoTexto: _fromHexOpt(j['acento_texto']),
        peligro: _fromHexOpt(j['peligro']),
        sobreAcento: _fromHexOpt(j['sobre_acento']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'paper': _toHex(paper),
        'sheet': _toHex(sheet),
        'white': _toHex(white),
        'ink': _toHex(ink),
        'acento': _toHex(acento),
        'blue': _toHex(blue),
        'grey1': _toHex(grey1),
        'grey2': _toHex(grey2),
        'grey3': _toHex(grey3),
        'strike': _toHex(strike),
        if (_acentoTexto != null) 'acento_texto': _toHex(_acentoTexto),
        if (_peligro != null) 'peligro': _toHex(_peligro),
        if (_sobreAcento != null) 'sobre_acento': _toHex(_sobreAcento),
      };

  static Color _fromHex(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  static Color? _fromHexOpt(Object? hex) =>
      hex is String && hex.isNotEmpty ? _fromHex(hex) : null;

  static String _toHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}
