import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:frontend/core/l10n/app_localizations.dart';

class PhasePreviewCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> phase;
  final ColorScheme cs;
  final AppLocalizations t;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const PhasePreviewCard({
    super.key,
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
                icon: Icon(Icons.delete_outline,
                    size: 20.sp, color: cs.error),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
