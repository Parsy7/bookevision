import 'package:flutter/painting.dart';

/// Un tema de color de la piel Galerada. Vive en la base de datos
/// (`GET /temas`): añadir uno nuevo es un INSERT, sin tocar código.
///
/// Los derivados de siempre (onInk, onRed, onBlue, scrim, press) no se
/// guardan: se calculan a partir de [paper]/[white]/[ink].
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
  });

  Color get onInk => paper;
  Color get onRed => white;
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
      };

  static Color _fromHex(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));

  static String _toHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}
