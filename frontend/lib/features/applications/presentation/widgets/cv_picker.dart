import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

/// Widget pour sélectionner un CV (PDF) dans le formulaire de candidature.
/// Affiche le fichier sélectionné ou un bouton pour en choisir un.
class CvPicker extends StatelessWidget {
  final PlatformFile? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const CvPicker({
    super.key,
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    // Affiche le fichier sélectionné
    if (file != null) {
      final sizeMb = (file!.size / 1024 / 1024).toStringAsFixed(1);
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, size: 24.sp, color: cs.primary),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file!.name,
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
                      overflow: TextOverflow.ellipsis),
                  Text('$sizeMb MB',
                      style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.close_rounded, size: 18.sp, color: cs.onSurfaceVariant),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    // Bouton pour choisir un fichier
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file_rounded, size: 20.sp, color: cs.onSurfaceVariant),
            SizedBox(width: 8.w),
            Text(t.t('applications_screen.cv_pick'),
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
