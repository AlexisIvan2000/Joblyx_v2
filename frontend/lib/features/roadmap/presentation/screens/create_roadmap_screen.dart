import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';
import 'package:frontend/features/roadmap/presentation/screens/phase_form_screen.dart';
import 'package:frontend/features/roadmap/presentation/widgets/phase_preview_card.dart';

/// Écran de création d'un roadmap manuel.
class CreateRoadmapScreen extends ConsumerStatefulWidget {
  const CreateRoadmapScreen({super.key});

  @override
  ConsumerState<CreateRoadmapScreen> createState() =>
      _CreateRoadmapScreenState();
}

class _CreateRoadmapScreenState extends ConsumerState<CreateRoadmapScreen> {
  final List<Map<String, dynamic>> _phases = [];
  bool _submitting = false;

  /// Ouvrir le formulaire de phase et ajouter le résultat.
  Future<void> _addPhase() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const PhaseFormScreen()),
    );
    if (result != null && mounted) {
      setState(() => _phases.add(result));
    }
  }

  /// Modifier une phase existante.
  Future<void> _editPhase(int index) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => PhaseFormScreen(initialPhase: _phases[index]),
      ),
    );
    if (result != null && mounted) {
      setState(() => _phases[index] = result);
    }
  }

  /// Soumettre le roadmap.
  Future<void> _submit() async {
    final t = AppLocalizations.of(context);

    if (_phases.isEmpty) {
      AppSnackbar.error(context, t.t('dashboard.at_least_one_phase'));
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(roadmapProvider.notifier).createRoadmap(_phases);
      if (mounted) context.go('/roadmap');
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, t.t('dashboard.create_error'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('dashboard.create_roadmap_title')),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 100.h),
        children: [
          // ── Section phases ──
          Row(
            children: [
              Text(
                t.t('dashboard.phases_label'),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _addPhase,
                icon: const Icon(Icons.add),
                label: Text(t.t('dashboard.add_phase')),
              ),
            ],
          ),
          SizedBox(height: 8.h),

          // Liste des phases ajoutées
          if (_phases.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Center(
                child: Text(
                  t.t('dashboard.at_least_one_phase'),
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...List.generate(_phases.length, (i) {
              final phase = _phases[i];
              return PhasePreviewCard(
                index: i,
                phase: phase,
                cs: cs,
                t: t,
                onEdit: () => _editPhase(i),
                onDelete: () => setState(() => _phases.removeAt(i)),
                onMoveUp: i > 0
                    ? () => setState(() {
                          final item = _phases.removeAt(i);
                          _phases.insert(i - 1, item);
                        })
                    : null,
                onMoveDown: i < _phases.length - 1
                    ? () => setState(() {
                          final item = _phases.removeAt(i);
                          _phases.insert(i + 1, item);
                        })
                    : null,
              );
            }),
        ],
      ),
      // Bouton de création
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.t('dashboard.create_button')),
          ),
        ),
      ),
    );
  }
}
