import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'galerada/g_app.dart';
import 'galerada/theme/g_colors.dart';
import 'screens/review_list_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  if (AppConfig.piel == Piel.galerada) await GColors.cargarCache();
  runApp(switch (AppConfig.piel) {
    Piel.pergamino => const BookeVisionApp(),
    Piel.galerada => const GaleradaApp(),
  });
}

class BookeVisionApp extends StatelessWidget {
  const BookeVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: MaterialApp(
        title: 'BookeVision',
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es'), Locale('en')],
        home: const ReviewListScreen(),
      ),
    );
  }
}
