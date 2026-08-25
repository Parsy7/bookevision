import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/review_session.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/progress_header.dart';
import '../widgets/save_indicator.dart';

/// Lector de una revisión. En esta fase (4A) muestra la cabecera de progreso,
/// el guardado (autosave + botón) y el capítulo de corrido. Las tarjetas de
/// sugerencia intercaladas y la edición manual llegan en la fase 4B.
class ReviewerScreen extends StatelessWidget {
  final String reviewId;
  const ReviewerScreen({super.key, required this.reviewId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReviewSession>(
      create: (ctx) =>
          ReviewSession(api: ctx.read<ApiService>())..load(reviewId),
      child: const _ReviewerView(),
    );
  }
}

class _ReviewerView extends StatelessWidget {
  const _ReviewerView();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ReviewSession>();

    return PopScope(
      canPop: true,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        // Al salir, fuerza un último guardado si quedaba algo pendiente.
        if (session.canSave) session.saveNow();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.review?.title ?? 'Revisión'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SaveIndicator(status: session.saveStatus),
            ),
            TextButton(
              onPressed: session.canSave ? () => session.saveNow() : null,
              child: const Text('Guardar'),
            ),
            const SizedBox(width: AppSpacing.gapSm),
          ],
        ),
        body: _body(context, session),
      ),
    );
  }

  Widget _body(BuildContext context, ReviewSession session) {
    switch (session.loadStatus) {
      case LoadStatus.idle:
      case LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadStatus.error:
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('No se pudo abrir la revisión',
                    style: AppText.titleSection, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.gapSm),
                Text('${session.lastError}',
                    style: AppText.caption, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      case LoadStatus.ready:
        final c = session.counts();
        return Column(
          children: [
            ProgressHeader(done: c.done, total: c.total),
            Expanded(child: _Reader(chapter: session.review!.chapter)),
          ],
        );
    }
  }
}

/// Render del capítulo de corrido, separando en párrafos. En 4B este cuerpo se
/// sustituye por el lector con las tarjetas intercaladas en su posición real.
class _Reader extends StatelessWidget {
  final String chapter;
  const _Reader({required this.chapter});

  @override
  Widget build(BuildContext context) {
    final paragraphs = chapter
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.page),
      itemCount: paragraphs.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppSpacing.gapMd),
      itemBuilder: (_, i) => Text(paragraphs[i], style: AppText.readerText),
    );
  }
}
