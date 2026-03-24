import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

/// Écran formulaire complet pour créer/modifier une phase.
/// Retourne un `Map<String, dynamic>` via Navigator.pop.
class PhaseFormScreen extends StatefulWidget {
  /// Phase existante à modifier (null = création).
  final Map<String, dynamic>? initialPhase;

  const PhaseFormScreen({super.key, this.initialPhase});

  @override
  State<PhaseFormScreen> createState() => _PhaseFormScreenState();
}

class _PhaseFormScreenState extends State<PhaseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Champs principaux
  late final TextEditingController _titleCtrl;
  late final TextEditingController _weeksCtrl;
  late final TextEditingController _objectiveCtrl;

  // Listes dynamiques
  final List<Map<String, dynamic>> _skills = [];
  final List<Map<String, dynamic>> _actions = [];
  final List<Map<String, dynamic>> _resources = [];
  final List<Map<String, dynamic>> _certifications = [];
  final List<Map<String, dynamic>> _projects = [];

  @override
  void initState() {
    super.initState();
    final p = widget.initialPhase;
    _titleCtrl = TextEditingController(text: p?['title'] as String? ?? '');
    _weeksCtrl = TextEditingController(
        text: '${p?['duration_weeks'] as int? ?? 2}');
    _objectiveCtrl =
        TextEditingController(text: p?['objective'] as String? ?? '');

    // Charger les listes existantes
    _loadList(p, 'skills', _skills);
    _loadList(p, 'actions', _actions);
    _loadList(p, 'resources', _resources);
    _loadList(p, 'certifications', _certifications);
    _loadList(p, 'projects', _projects);
  }

  void _loadList(
      Map<String, dynamic>? phase, String key, List<Map<String, dynamic>> target) {
    if (phase == null) return;
    final raw = phase[key];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          target.add(Map<String, dynamic>.from(item));
        }
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _weeksCtrl.dispose();
    _objectiveCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(<String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'duration_weeks': int.tryParse(_weeksCtrl.text.trim()) ?? 2,
      'objective': _objectiveCtrl.text.trim(),
      'skills': _skills,
      'actions': _actions,
      'resources': _resources,
      'certifications': _certifications,
      'projects': _projects,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final isEditing = widget.initialPhase != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t(isEditing
            ? 'dashboard.phase_edit_title'
            : 'dashboard.phase_form_title')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 100.h),
          children: [
            // ── Titre de la phase ──
            TextFormField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: t.t('dashboard.phase_title_label'),
                hintText: t.t('dashboard.phase_title_hint'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? t.t('applications_screen.field_required')
                  : null,
            ),
            SizedBox(height: 12.h),

            // ── Durée ──
            TextFormField(
              controller: _weeksCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: t.t('dashboard.phase_duration_label'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n < 1) {
                  return t.t('applications_screen.field_required');
                }
                return null;
              },
            ),
            SizedBox(height: 12.h),

            // ── Objectif (le pourquoi) ──
            TextFormField(
              controller: _objectiveCtrl,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: t.t('dashboard.phase_objective_label'),
                hintText: t.t('dashboard.phase_objective_hint'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r)),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 20.h),

            // ── Skills ──
            _SectionHeader(
              icon: Icons.code_rounded,
              label: t.t('dashboard.section_skills'),
              onAdd: () => setState(() => _skills.add({
                    'name': '',
                    'priority': 'medium',
                    'completed': false,
                  })),
            ),
            ..._skills.asMap().entries.map((e) => _SkillItem(
                  key: ValueKey('skill_${e.key}'),
                  skill: e.value,
                  t: t,
                  cs: cs,
                  onRemove: () => setState(() => _skills.removeAt(e.key)),
                )),
            SizedBox(height: 16.h),

            // ── Actions ──
            _SectionHeader(
              icon: Icons.checklist_rounded,
              label: t.t('dashboard.section_actions'),
              onAdd: () => setState(() => _actions.add({
                    'task': '',
                    'detail': '',
                    'estimated_hours': null,
                    'completed': false,
                  })),
            ),
            ..._actions.asMap().entries.map((e) => _ActionItem(
                  key: ValueKey('action_${e.key}'),
                  action: e.value,
                  t: t,
                  onRemove: () => setState(() => _actions.removeAt(e.key)),
                )),
            SizedBox(height: 16.h),

            // ── Ressources ──
            _SectionHeader(
              icon: Icons.menu_book_rounded,
              label: t.t('dashboard.section_resources'),
              onAdd: () => setState(() => _resources.add({
                    'title': '',
                    'platform': '',
                    'url': '',
                    'type': 'course',
                    'free': true,
                  })),
            ),
            ..._resources.asMap().entries.map((e) => _ResourceItem(
                  key: ValueKey('resource_${e.key}'),
                  resource: e.value,
                  t: t,
                  onRemove: () => setState(() => _resources.removeAt(e.key)),
                )),
            SizedBox(height: 16.h),

            // ── Certifications ──
            _SectionHeader(
              icon: Icons.verified_rounded,
              label: t.t('dashboard.section_certifications'),
              onAdd: () => setState(() => _certifications.add({
                    'name': '',
                    'provider': '',
                    'cost': '',
                  })),
            ),
            ..._certifications.asMap().entries.map((e) => _CertItem(
                  key: ValueKey('cert_${e.key}'),
                  cert: e.value,
                  t: t,
                  onRemove: () =>
                      setState(() => _certifications.removeAt(e.key)),
                )),
            SizedBox(height: 16.h),

            // ── Projets ──
            _SectionHeader(
              icon: Icons.build_circle_outlined,
              label: t.t('dashboard.section_projects'),
              onAdd: () => setState(() => _projects.add({
                    'name': '',
                    'description': '',
                    'technologies': <String>[],
                  })),
            ),
            ..._projects.asMap().entries.map((e) => _ProjectItem(
                  key: ValueKey('project_${e.key}'),
                  project: e.value,
                  t: t,
                  onRemove: () => setState(() => _projects.removeAt(e.key)),
                )),
          ],
        ),
      ),
      // Bouton de sauvegarde
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
          child: FilledButton(
            onPressed: _submit,
            child: Text(t.t('dashboard.save_phase')),
          ),
        ),
      ),
    );
  }
}

// ─── En-tête de section avec bouton "+" ──────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onAdd;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: cs.primary),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onAdd,
            icon: Icon(Icons.add_circle_outline, size: 22.sp),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─── Widget item pour un skill ──────────────────────────────────

class _SkillItem extends StatelessWidget {
  final Map<String, dynamic> skill;
  final AppLocalizations t;
  final ColorScheme cs;
  final VoidCallback onRemove;

  const _SkillItem({
    super.key,
    required this.skill,
    required this.t,
    required this.cs,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Padding(
        padding: EdgeInsets.all(10.w),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: skill['name'] as String? ?? '',
                decoration: InputDecoration(
                  hintText: t.t('dashboard.skill_name_hint'),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r)),
                ),
                onChanged: (v) => skill['name'] = v.trim(),
              ),
            ),
            SizedBox(width: 8.w),
            // Sélecteur de priorité
            DropdownButton<String>(
              value: skill['priority'] as String? ?? 'medium',
              isDense: true,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                    value: 'critical',
                    child: Text(t.t('dashboard.priority_critical'),
                        style: TextStyle(fontSize: 12.sp, color: cs.error))),
                DropdownMenuItem(
                    value: 'high',
                    child: Text(t.t('dashboard.priority_high'),
                        style: TextStyle(fontSize: 12.sp, color: cs.primary))),
                DropdownMenuItem(
                    value: 'medium',
                    child: Text(t.t('dashboard.priority_medium'),
                        style: TextStyle(fontSize: 12.sp, color: cs.tertiary))),
                DropdownMenuItem(
                    value: 'low',
                    child: Text(t.t('dashboard.priority_low'),
                        style: TextStyle(fontSize: 12.sp))),
              ],
              onChanged: (v) {
                if (v != null) {
                  skill['priority'] = v;
                  // Force rebuild via parent setState
                  (context as Element).markNeedsBuild();
                }
              },
            ),
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.close, size: 18.sp),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widget item pour une action ────────────────────────────────

class _ActionItem extends StatelessWidget {
  final Map<String, dynamic> action;
  final AppLocalizations t;
  final VoidCallback onRemove;

  const _ActionItem({
    super.key,
    required this.action,
    required this.t,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Padding(
        padding: EdgeInsets.all(10.w),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: action['task'] as String? ?? '',
                    decoration: InputDecoration(
                      hintText: t.t('dashboard.action_task_hint'),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onChanged: (v) => action['task'] = v.trim(),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.close, size: 18.sp),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    initialValue: action['detail'] as String? ?? '',
                    decoration: InputDecoration(
                      hintText: t.t('dashboard.action_detail_hint'),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onChanged: (v) => action['detail'] = v.trim(),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: TextFormField(
                    initialValue: action['estimated_hours'] != null
                        ? '${action['estimated_hours']}'
                        : '',
                    decoration: InputDecoration(
                      hintText: t.t('dashboard.action_hours_hint'),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r)),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) =>
                        action['estimated_hours'] = int.tryParse(v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widget item pour une ressource ─────────────────────────────

class _ResourceItem extends StatelessWidget {
  final Map<String, dynamic> resource;
  final AppLocalizations t;
  final VoidCallback onRemove;

  const _ResourceItem({
    super.key,
    required this.resource,
    required this.t,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Padding(
        padding: EdgeInsets.all(10.w),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: resource['title'] as String? ?? '',
                    decoration: InputDecoration(
                      hintText: t.t('dashboard.resource_title_hint'),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onChanged: (v) => resource['title'] = v.trim(),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.close, size: 18.sp),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: resource['platform'] as String? ?? '',
                    decoration: InputDecoration(
                      hintText: t.t('dashboard.resource_platform_hint'),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onChanged: (v) => resource['platform'] = v.trim(),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: TextFormField(
                    initialValue: resource['type'] as String? ?? '',
                    decoration: InputDecoration(
                      hintText: t.t('dashboard.resource_type_hint'),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onChanged: (v) => resource['type'] = v.trim(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            TextFormField(
              initialValue: resource['url'] as String? ?? '',
              decoration: InputDecoration(
                hintText: t.t('dashboard.resource_url_hint'),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r)),
              ),
              onChanged: (v) => resource['url'] = v.trim(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widget item pour une certification ─────────────────────────

class _CertItem extends StatelessWidget {
  final Map<String, dynamic> cert;
  final AppLocalizations t;
  final VoidCallback onRemove;

  const _CertItem({
    super.key,
    required this.cert,
    required this.t,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Padding(
        padding: EdgeInsets.all(10.w),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: cert['name'] as String? ?? '',
                decoration: InputDecoration(
                  hintText: t.t('dashboard.cert_name_hint'),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r)),
                ),
                onChanged: (v) => cert['name'] = v.trim(),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: TextFormField(
                initialValue: cert['provider'] as String? ?? '',
                decoration: InputDecoration(
                  hintText: t.t('dashboard.cert_provider_hint'),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r)),
                ),
                onChanged: (v) => cert['provider'] = v.trim(),
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.close, size: 18.sp),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widget item pour un projet ─────────────────────────────────

class _ProjectItem extends StatelessWidget {
  final Map<String, dynamic> project;
  final AppLocalizations t;
  final VoidCallback onRemove;

  const _ProjectItem({
    super.key,
    required this.project,
    required this.t,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: Padding(
        padding: EdgeInsets.all(10.w),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: project['name'] as String? ?? '',
                    decoration: InputDecoration(
                      hintText: t.t('dashboard.project_name_hint'),
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r)),
                    ),
                    onChanged: (v) => project['name'] = v.trim(),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(Icons.close, size: 18.sp),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            SizedBox(height: 6.h),
            TextFormField(
              initialValue: project['description'] as String? ?? '',
              decoration: InputDecoration(
                hintText: t.t('dashboard.project_desc_hint'),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r)),
              ),
              maxLines: 2,
              onChanged: (v) => project['description'] = v.trim(),
            ),
            SizedBox(height: 6.h),
            TextFormField(
              initialValue:
                  (project['technologies'] as List?)?.join(', ') ?? '',
              decoration: InputDecoration(
                hintText: t.t('dashboard.project_techs_hint'),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r)),
              ),
              onChanged: (v) => project['technologies'] = v
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
