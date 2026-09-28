import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'screens/g_auth_gate.dart';
import 'theme/g_theme.dart';

/// Raíz de la piel «Galerada». Comparte `models/`, `services/` y `utils/` con
/// la piel original: aquí solo cambia la vista.
class GaleradaApp extends StatelessWidget {
  const GaleradaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: MaterialApp(
        title: 'BookeVision',
        debugShowCheckedModeBanner: false,
        theme: buildGaleradaTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es'), Locale('en')],
        home: const GAuthGate(),
      ),
    );
  }
}
