import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'screens/g_auth_gate.dart';
import 'screens/g_splash.dart';
import 'theme/g_theme.dart';
import 'widgets/g_ancho_app.dart';

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
        title: 'bookevision',
        debugShowCheckedModeBanner: false,
        theme: buildGaleradaTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es'), Locale('en')],
        // La pantalla de carga va por fuera del ancho máximo: en escritorio
        // ocupa la ventana entera, y la app aparece debajo ya en su columna.
        builder: (context, child) => GSplash(child: GAnchoApp(child: child!)),
        home: const GAuthGate(),
      ),
    );
  }
}
