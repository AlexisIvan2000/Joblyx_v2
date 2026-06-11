import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';


// AddPhaseDialog


/// Dialog pour ajouter une phase custom au roadmap.
class AddPhaseDialog extends StatefulWidget {
  const AddPhaseDialog({super.key});

  @override
  State<AddPhaseDialog> createState() => _AddPhaseDialogState();
}

class _AddPhaseDialogState extends State<AddPhaseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _weeksCtrl = TextEditingController(text: '2');
  final _objectiveCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _weeksCtrl.dispose();
    _objectiveCtrl.dispose();
    super.dispose();
  }

  /// Valide le formulaire et retourne les données au parent via pop.
  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(<String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'duration_weeks': int.tryParse(_weeksCtrl.text.trim()) ?? 2,
      'objective': _objectiveCtrl.text.trim(),
      'custom': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Titre du dialog
              Text(
                t.t('dashboard.add_phase_title'),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              SizedBox(height: 16.h),

              // Champ titre de la phase
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: t.t('dashboard.phase_title_label'),
                  hintText: t.t('dashboard.phase_title_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? t.t('applications_screen.field_required') : null,
              ),
              SizedBox(height: 12.h),

              // Champ durée en semaines
              TextFormField(
                controller: _weeksCtrl,
                decoration: InputDecoration(
                  labelText: t.t('dashboard.phase_duration_label'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return t.t('applications_screen.field_required');
                  return null;
                },
              ),
              SizedBox(height: 12.h),

              // Champ objectif (optionnel)
              TextFormField(
                controller: _objectiveCtrl,
                decoration: InputDecoration(
                  labelText: t.t('dashboard.phase_objective_label'),
                  hintText: t.t('dashboard.phase_objective_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 20.h),

              // Bouton d'ajout
              FilledButton(
                onPressed: _submit,
                child: Text(t.t('dashboard.add_phase')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// EditNotesDialog


/// Dialog pour modifier les notes d'une phase.
class EditNotesDialog extends StatefulWidget {
  final String initialNotes;

  const EditNotesDialog({super.key, this.initialNotes = ''});

  @override
  State<EditNotesDialog> createState() => _EditNotesDialogState();
}

class _EditNotesDialogState extends State<EditNotesDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    // Pré-remplit le champ avec les notes existantes
    _ctrl = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Titre
            Text(
              t.t('dashboard.edit_notes'),
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            SizedBox(height: 16.h),

            // Champ texte multilignes pour les notes
            TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: t.t('dashboard.notes_hint'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              maxLines: 5,
              autofocus: true,
            ),
            SizedBox(height: 20.h),

            // Bouton sauvegarder retourne le texte saisi au parent
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
              child: Text(t.t('settings.save')),
            ),
          ],
        ),
      ),
    );
  }
}
