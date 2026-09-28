import 'package:flutter/material.dart';
import '../../services/review_session.dart';
import '../../utils/export_md.dart';
import '../theme/g_colors.dart';
import '../theme/g_spacing.dart';
import '../widgets/g_app_bar.dart';
import '../widgets/g_bits.dart';
import '../widgets/g_foot.dart';
import '../widgets/g_prose.dart';

/// Vista previa del capítulo con todas las decisiones aplicadas: tira de
/// recuentos en mono, prosa numerada y la CTA de tinta para exportar.
class GPreviewScreen extends StatelessWidget {
  final String title;
  final String text;
  final Counts counts;

  const GPreviewScreen({
    super.key,
    required this.title,
    required this.text,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GAppBar(title: 'Vista previa'),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: GSpacing.page, vertical: GSpacing.barTop),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: GColors.ink, width: GSpacing.border),
              ),
            ),
            child: GMono(
              '${counts.done}/${counts.total} resueltas · '
              '${counts.pending} pendientes · '
              '${counts.manual} ${counts.manual == 1 ? 'editado' : 'editados'}',
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(GSpacing.page),
              child: GProseFlow(text),
            ),
          ),
        ],
      ),
      bottomNavigationBar: GFoot.unica(
        label: 'Exportar .md',
        icon: Icons.ios_share,
        fill: GFootFill.ink,
        onTap: () => ExportMd.share(title, 'avance', text),
      ),
    );
  }
}
