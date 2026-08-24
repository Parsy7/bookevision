import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_text.dart';

/// Tema claro "Pergamino". Sin sombras (las superficies se distinguen por
/// borde 1px y fondo). Un solo lugar por componente.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: const ColorScheme.light(
    surface: AppColors.bgCard,
    primary: AppColors.primary,
    error: AppColors.error,
    onError: AppColors.onError,
    onPrimary: AppColors.textInverse,
    onSurface: AppColors.text,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: AppColors.bgCard,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
    titleTextStyle: AppText.titleSection,
    contentTextStyle: AppText.bodyText,
  ),
  // TextButton global: usa el acento, que contrasta bien sobre el pergamino.
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: AppText.label,
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.bg,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.cormorantGaramond(
      fontSize: AppText.lg,
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    ),
    iconTheme: const IconThemeData(color: AppColors.text),
  ),
  textTheme: GoogleFonts.loraTextTheme(ThemeData.light().textTheme).apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  ),
  fontFamily: GoogleFonts.lora().fontFamily,
);
