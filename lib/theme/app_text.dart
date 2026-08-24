import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Tipografía del revisor. Serif literario para encajar con el tacto de libro:
/// titulares en Cormorant Garamond (como Anotto) y cuerpo en Lora, una serif
/// de lectura cálida. Prohibido escribir tamaños sueltos: usar los tokens.
class AppText {
  AppText._();

  static const double xxs = 10;
  static const double xs = 12;
  static const double sm = 14;
  static const double base = 16;
  static const double md = 18;
  static const double lg = 20;
  static const double xl = 24;

  /// Título de pantalla. Sentence case siempre.
  static TextStyle get titlePage => GoogleFonts.cormorantGaramond(
        fontSize: xl,
        fontWeight: FontWeight.w700,
        height: 32 / 24,
        color: AppColors.text,
      );

  static TextStyle get titleSection => GoogleFonts.cormorantGaramond(
        fontSize: lg,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.text,
      );

  static TextStyle get pretitle => GoogleFonts.cormorantGaramond(
        fontSize: lg,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: AppColors.text,
        letterSpacing: 0.4,
      );

  static TextStyle get subtitle => GoogleFonts.lora(
        fontSize: base,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.textMuted,
      );

  static TextStyle get bodyText => GoogleFonts.lora(
        fontSize: base,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.text,
      );

  static TextStyle get label => GoogleFonts.lora(
        fontSize: sm,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 20 / 14,
        color: AppColors.text,
      );

  static TextStyle get caption => GoogleFonts.lora(
        fontSize: xs,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        height: 16 / 12,
        color: AppColors.textMuted,
      );

  /// Texto corrido del capítulo en el lector. Interlineado amplio (1.75) para
  /// lectura larga, replicando el cuerpo del lector HTML del libro.
  static TextStyle get readerText => GoogleFonts.lora(
        fontSize: md,
        fontWeight: FontWeight.w400,
        height: 1.75,
        color: AppColors.text,
      );
}
