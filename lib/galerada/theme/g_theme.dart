import 'package:flutter/material.dart';
import 'g_colors.dart';
import 'g_text.dart';

/// Tema de «Galerada». **Radio 0 en todo** y **sin sombras**: las superficies
/// se distinguen por borde de 1px de tinta y por fondo, como una prueba de
/// imprenta. Un solo lugar por componente.
///
/// Función, no constante: los colores dependen del tema activo (`GColors`),
/// así que hay que recalcularla cada vez que se usa, no una sola vez al
/// cargar el módulo.
ThemeData buildGaleradaTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: GColors.paper,
  colorScheme: ColorScheme.light(
    surface: GColors.sheet,
    primary: GColors.ink,
    secondary: GColors.red,
    error: GColors.red,
    onError: GColors.onRed,
    onPrimary: GColors.onInk,
    onSurface: GColors.ink,
  ),
  // Sin radio y sin elevación en ninguna superficie.
  dialogTheme: DialogThemeData(
    backgroundColor: GColors.sheet,
    elevation: 0,
    shape: const RoundedRectangleBorder(),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: GColors.sheet,
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: GColors.ink),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: GColors.ink,
    contentTextStyle: GText.mono.copyWith(color: GColors.onInk),
    elevation: 0,
    shape: const RoundedRectangleBorder(),
    behavior: SnackBarBehavior.floating,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: GColors.paper,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: GText.appBar,
    iconTheme: IconThemeData(color: GColors.ink),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: GColors.ink,
    linearTrackColor: GColors.paper,
  ),
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: GColors.blue,
    selectionColor: const Color(0x332449D8),
    selectionHandleColor: GColors.blue,
  ),
  splashFactory: NoSplash.splashFactory,
  highlightColor: GColors.press,
  textTheme: GoogleFontsNewsreaderTextTheme.of(),
);

/// El `textTheme` por defecto: Newsreader, que es la familia de lectura.
class GoogleFontsNewsreaderTextTheme {
  GoogleFontsNewsreaderTextTheme._();

  static TextTheme of() => TextTheme(
        bodyLarge: GText.prose,
        bodyMedium: GText.block,
        bodySmall: GText.reason,
        titleLarge: GText.appBar,
        titleMedium: GText.cardTitle,
        labelLarge: GText.action,
        labelSmall: GText.mono,
      );
}
