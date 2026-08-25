import 'package:flutter/material.dart';
import '../services/review_session.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../utils/export_md.dart';
import '../widgets/app_button.dart';

/// Vista previa del capítulo con todas las decisiones aplicadas (instantánea).
class PreviewScreen extends StatelessWidget {
  final String title;
  final String text;
  final Counts counts;

  const PreviewScreen({
    super.key,
    required this.title,
    required this.text,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vista previa actual')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.page, AppSpacing.gapSm, AppSpacing.page, 0),
            child: Text(
              '${counts.done}/${counts.total} resueltas · '
              '${counts.pending} pendientes · '
              '${counts.manual} bloques editados',
              style: AppText.caption,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: SelectableText(text, style: AppText.readerText),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: AppButton(
                label: 'Exportar capítulo actual (.md)',
                icon: Icons.ios_share,
                onPressed: () => ExportMd.share(title, 'avance', text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
