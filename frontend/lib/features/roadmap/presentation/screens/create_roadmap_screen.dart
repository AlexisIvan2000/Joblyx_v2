import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/roadmap/presentation/providers/roadmap_provider.dart';
import 'package:frontend/features/roadmap/presentation/screens/phase_form_screen.dart';

/// Écran de création d'un roadmap manuel.
class CreateRoadmapScreen extends ConsumerStatefulWidget {
  const CreateRoadmapScreen({super.key});

  @override
  ConsumerState<CreateRoadmapScreen> createState() =>
      _CreateRoadmapScreenState();
}

class _CreateRoadmapScreenState extends ConsumerState<CreateRoadmapScreen> {
  final _jobCtrl = TextEditingController();
  final List<String> _targetJobs = [];
  final List<Map<String, dynamic>> _phases = [];
  bool _submitting = false;

  @override
  void dispose() {
    _jobCtrl.dispose();
    super.dispose();
  }

  /// Ajouter un poste visé.
  void _addJob() {
    final job = _jobCtrl.text.trim();
    if (job.isEmpty) return;
    setState(() => _targetJobs.add(job));
    _jobCtrl.clear();
  }

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

    if (_targetJobs.isEmpty) {
      AppSnackbar.error(context, t.t('dashboard.at_least_one_job'));
      return;
    }
    if (_phases.isEmpty) {
      AppSnackbar.error(context, t.t('dashboard.at_least_one_phase'));
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(roadmapProvider.notifier)
          .createRoadmap(_targetJobs, _phases);
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
          // ── Section postes visés ──
          Text(
            t.t('dashboard.target_jobs_label'),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          SizedBox(height: 8.h),
          // Champ + bouton ajouter
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _jobCtrl,
                  decoration: InputDecoration(
                    hintText: t.t('dashboard.target_jobs_hint'),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                  onSubmitted: (_) => _addJob(),
                ),
              ),
              SizedBox(width: 8.w),
              FilledButton(
                onPressed: _addJob,
                child: Text(t.t('dashboard.add_job')),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // Chips des postes ajoutés
          if (_targetJobs.isNotEmpty)
            Wrap(
              spacing: 6.w,
              runSpacing: 4.h,
              children: _targetJobs.asMap().entries.map((e) {
                return Chip(
                  label: Text(e.value, style: TextStyle(fontSize: 12.sp)),
                  deleteIcon: Icon(Icons.close, size: 16.sp),
                  onDeleted: () =>
                      setState(() => _targetJobs.removeAt(e.key)),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          SizedBox(height: 24.h),

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
              return _PhasePreviewCard(
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

/// Carte d'aperçu d'une phase dans la liste de création.
class _PhasePreviewCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> phase;
  final ColorScheme cs;
  final AppLocalizations t;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _PhasePreviewCard({
    required this.index,
    required this.phase,
    required this.cs,
    required this.t,
    required this.onEdit,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final title = phase['title'] as String? ?? '';
    final weeks = phase['duration_weeks'] as int? ?? 0;
    final objective = phase['objective'] as String? ?? '';
    final skills = (phase['skills'] as List?)?.length ?? 0;
    final actions = (phase['actions'] as List?)?.length ?? 0;

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              // Numéro de phase
              Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '$weeks ${t.t('dashboard.weeks')}'
                      '${skills > 0 ? ' · $skills ${t.t('dashboard.skills_to_learn').toLowerCase()}' : ''}'
                      '${actions > 0 ? ' · $actions ${t.t('dashboard.actions').toLowerCase()}' : ''}',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (objective.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 2.h),
                        child: Text(
                          objective,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: cs.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // Actions (réordonner, supprimer)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onMoveUp != null)
                    InkWell(
                      onTap: onMoveUp,
                      child: Icon(Icons.keyboard_arrow_up,
                          size: 20.sp, color: cs.onSurfaceVariant),
                    ),
                  if (onMoveDown != null)
                    InkWell(
                      onTap: onMoveDown,
                      child: Icon(Icons.keyboard_arrow_down,
                          size: 20.sp, color: cs.onSurfaceVariant),
                    ),
                ],
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 20.sp, color: cs.error),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
