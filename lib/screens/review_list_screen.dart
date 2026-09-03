import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/review_summary.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icon.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_pill.dart';
import 'import_screen.dart';
import 'reviewer_screen.dart';

/// Pantalla inicial: lista de revisiones con su progreso. Permite importar
/// una nueva, abrir una para revisarla, o borrarla.
class ReviewListScreen extends StatefulWidget {
  const ReviewListScreen({super.key});

  @override
  State<ReviewListScreen> createState() => _ReviewListScreenState();
}

class _ReviewListScreenState extends State<ReviewListScreen> {
  late Future<List<ReviewSummary>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<ApiService>().getRevisiones();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _openImport() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ImportScreen()),
    );
    if (!mounted) return;
    await _refresh();
    if (id != null) _openReview(id);
  }

  void _openReview(String id) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => ReviewerScreen(reviewId: id)),
        )
        .then((_) => _refresh());
  }

  Future<void> _delete(ReviewSummary r) async {
    final ok = await AppDialog.confirm(
      context,
      title: 'Borrar revisión',
      message: '«${r.title}» y todas tus decisiones se borrarán. '
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Borrar',
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteRevision(r.id);
      await _refresh();
    } catch (e) {
      if (mounted) _snack('No se pudo borrar: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BookeVision'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Importar revisión',
            onPressed: _openImport,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ReviewSummary>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorState(error: snap.error!, onRetry: _refresh);
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return _EmptyState(onImport: _openImport);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.gapMd),
              itemBuilder: (_, i) => _ReviewTile(
                review: items[i],
                onTap: () => _openReview(items[i].id),
                onDelete: () => _delete(items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ReviewSummary review;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ReviewTile({
    required this.review,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(review.title, style: AppText.titleSection)),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: AppIcon.sm, color: AppColors.textMuted),
                tooltip: 'Borrar',
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gapSm),
          Wrap(
            spacing: AppSpacing.gapSm,
            runSpacing: AppSpacing.gapSm,
            children: [
              AppPill(
                label: review.isDocument
                    ? 'Capítulo suelto'
                    : review.isComplete
                        ? 'Completada'
                        : '${review.resolved}/${review.total} resueltas',
                color: review.isComplete
                    ? AppColors.success
                    : AppColors.pillBg,
                textColor:
                    review.isComplete ? AppColors.textInverse : null,
              ),
              if (review.manual > 0)
                AppPill(label: '${review.manual} editados a mano'),
            ],
          ),
          if (review.updatedAt != null) ...[
            const SizedBox(height: AppSpacing.gapSm),
            Text(
              'Actualizada ${DateFormat('d MMM y · HH:mm', 'es').format(review.updatedAt!)}',
              style: AppText.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onImport;
  const _EmptyState({required this.onImport});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.menu_book_outlined,
            size: AppIcon.xl, color: AppColors.textMuted),
        const SizedBox(height: AppSpacing.gapMd),
        Text('Aún no hay revisiones',
            style: AppText.titleSection, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.titleSubtitle),
        Text(
          'Importa el JSON de una revisión para empezar a trabajar el capítulo.',
          style: AppText.subtitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.subtitleBody),
        AppButton(
          label: 'Importar revisión',
          icon: Icons.add,
          onPressed: onImport,
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.cloud_off_outlined,
            size: AppIcon.xl, color: AppColors.textMuted),
        const SizedBox(height: AppSpacing.gapMd),
        Text('No se pudo cargar',
            style: AppText.titleSection, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.titleSubtitle),
        Text('$error', style: AppText.caption, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.subtitleBody),
        AppButton(
          label: 'Reintentar',
          variant: AppButtonVariant.secondary,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
