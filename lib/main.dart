import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Símbolos de fecha en español para los DateFormat(..., 'es').
  await initializeDateFormatting('es', null);
  runApp(const BookeVisionApp());
}

class BookeVisionApp extends StatelessWidget {
  const BookeVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookeVision',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      home: const HomeScreen(),
    );
  }
}
