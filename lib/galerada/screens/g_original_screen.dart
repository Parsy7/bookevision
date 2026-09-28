import 'package:flutter/material.dart';
import '../theme/g_spacing.dart';
import '../widgets/g_app_bar.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_prose.dart';

/// Capítulo original, solo lectura. El sello lo deja claro en la barra.
class GOriginalScreen extends StatelessWidget {
  final String chapter;
  const GOriginalScreen({super.key, required this.chapter});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GAppBar(
        title: 'Original',
        trailing: [GStamp('Solo lectura')],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(GSpacing.page),
        child: GProseFlow(chapter),
      ),
    );
  }
}
