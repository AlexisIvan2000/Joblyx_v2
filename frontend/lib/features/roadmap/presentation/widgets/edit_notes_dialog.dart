import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

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

            // Champ texte
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

            // Bouton sauvegarder
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
