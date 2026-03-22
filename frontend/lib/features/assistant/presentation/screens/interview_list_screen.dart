import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/assistant/presentation/providers/interview_provider.dart';
import 'package:frontend/features/assistant/presentation/screens/interview_form_dialog.dart';

/// Liste des sessions d'entretien (style WhatsApp).
class InterviewListScreen extends ConsumerWidget {
  const InterviewListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final historyAsync = ref.watch(interviewHistoryProvider);
    final usageAsync = ref.watch(interviewUsageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('interview.title')),
        actions: [
          historyAsync.when(
            data: (s) => s.isNotEmpty
                ? IconButton(
                    onPressed: () => _confirmDeleteAll(context, ref, t, cs),
                    icon: Icon(Icons.delete_sweep_rounded, size: 22.sp),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(t.t('interview.load_error'))),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_outlined, size: 48.sp, color: cs.onSurfaceVariant),
                  SizedBox(height: 12.h),
                  Text(t.t('interview.no_sessions'),
                      style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }

          // Séparer in_progress et completed
          final inProgress = sessions.where((s) => s['status'] == 'in_progress').toList();
          final completed = sessions.where((s) => s['status'] == 'completed').toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(interviewHistoryProvider.notifier).refresh(),
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                if (inProgress.isNotEmpty) ...[
                  _sectionTitle(t.t('interview.in_progress'), cs),
                  SizedBox(height: 8.h),
                  ...inProgress.map((s) => _SessionCard(
                        session: s, cs: cs,
                        onTap: () => context.push('/assistant/interview/chat/${s['id']}'),
                        onDelete: () => _confirmDelete(context, ref, t, cs, s['id'] as String),
                      )),
                  SizedBox(height: 16.h),
                ],
                if (completed.isNotEmpty) ...[
                  _sectionTitle(t.t('interview.completed'), cs),
                  SizedBox(height: 8.h),
                  ...completed.map((s) => _SessionCard(
                        session: s, cs: cs,
                        onTap: () => context.push('/assistant/interview/summary/${s['id']}'),
                        onDelete: () => _confirmDelete(context, ref, t, cs, s['id'] as String),
                      )),
                ],
              ],
            ),
          );
        },
      ),
      // Bouton nouvelle simulation
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewInterviewDialog(context, ref, t, usageAsync),
        icon: Icon(Icons.add_rounded, size: 20.sp),
        label: Text(t.t('interview.new_session')),
      ),
    );
  }

  Widget _sectionTitle(String title, ColorScheme cs) {
    return Text(title,
        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant));
  }

  Future<void> _showNewInterviewDialog(
    BuildContext context, WidgetRef ref, AppLocalizations t,
    AsyncValue<Map<String, dynamic>> usageAsync,
  ) async {
    // Vérifier la limite
    final usage = usageAsync.value;
    if (usage != null && (usage['remaining'] as int? ?? 0) <= 0) {
      AppSnackbar.error(context, t.t('interview.limit_reached'));
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const InterviewFormDialog(),
    );
    if (result == null || !context.mounted) return;

    try {
      final svc = ref.read(interviewServiceProvider);
      final response = await svc.startSession(
        jobTitle: result['job_title'] as String,
        companyName: result['company_name'] as String?,
        jobDescription: result['job_description'] as String?,
        language: result['language'] as String? ?? 'fr',
      );

      if (!context.mounted) return;

      // Initialiser le chat avec la première question
      final sessionId = response['session_id'] as String;
      final firstQ = response['first_question'] as Map<String, dynamic>;
      ref.read(interviewChatProvider.notifier).initWithFirstQuestion(
        sessionId: sessionId,
        jobTitle: result['job_title'] as String,
        firstMessage: firstQ['message'] as String,
        questionNumber: firstQ['question_number'] as int? ?? 1,
      );

      // Rafraîchir l'historique et l'usage
      ref.invalidate(interviewHistoryProvider);
      ref.invalidate(interviewUsageProvider);

      context.push('/assistant/interview/chat/$sessionId');
    } catch (e) {
      if (!context.mounted) return;
      if (e.toString().contains('429')) {
        AppSnackbar.error(context, t.t('interview.limit_reached'));
      } else {
        AppSnackbar.error(context, t.t('interview.start_error'));
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, AppLocalizations t, ColorScheme cs, String id,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(t.t('interview.delete_session')),
        content: Text(t.t('interview.delete_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('settings.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.t('application_detail.delete'), style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(interviewHistoryProvider.notifier).deleteSession(id);
      if (context.mounted) AppSnackbar.success(context, t.t('interview.session_deleted'));
    } catch (_) {
      if (context.mounted) AppSnackbar.error(context, t.t('interview.delete_error'));
    }
  }

  Future<void> _confirmDeleteAll(
    BuildContext context, WidgetRef ref, AppLocalizations t, ColorScheme cs,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(t.t('interview.delete_all')),
        content: Text(t.t('interview.delete_all_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('settings.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.t('application_detail.delete'), style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final count = await ref.read(interviewHistoryProvider.notifier).deleteAll();
      if (context.mounted) {
        AppSnackbar.success(context, t.t('interview.all_deleted').replaceAll('{count}', '$count'));
      }
    } catch (_) {
      if (context.mounted) AppSnackbar.error(context, t.t('interview.delete_error'));
    }
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final ColorScheme cs;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.cs,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isInProgress = session['status'] == 'in_progress';
    final score = session['overall_score'] as int?;
    final jobTitle = session['job_title'] as String? ?? '';
    final company = session['company_name'] as String? ?? '';
    final lastMsg = session['last_message'] as String? ?? '';
    final createdAt = session['created_at'] as String? ?? '';

    String dateStr = '';
    if (createdAt.isNotEmpty) {
      final date = DateTime.tryParse(createdAt);
      if (date != null) {
        dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
      }
    }

    final scoreColor = isInProgress
        ? cs.primary
        : (score ?? 0) >= 70
            ? const Color(0xFF5DCAA5)
            : (score ?? 0) >= 40
                ? const Color(0xFFFFB347)
                : const Color(0xFFE57373);

    final t = AppLocalizations.of(context);

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 4.w, 12.h),
          child: Row(
            children: [
              // Score ou badge "En cours"
              Container(
                width: 44.w, height: 44.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isInProgress ? cs.primary.withValues(alpha: 0.1) : null,
                  border: isInProgress ? null : Border.all(color: scoreColor, width: 2.5),
                ),
                child: Center(
                  child: isInProgress
                      ? Icon(Icons.chat_rounded, size: 20.sp, color: cs.primary)
                      : Text('${score ?? 0}',
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: scoreColor)),
                ),
              ),
              SizedBox(width: 12.w),
              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(jobTitle,
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (isInProgress)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(t.t('interview.in_progress_badge'),
                                style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700, color: cs.primary)),
                          ),
                        if (dateStr.isNotEmpty && !isInProgress)
                          Text(dateStr, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                      ],
                    ),
                    if (company.isNotEmpty)
                      Text(company,
                          style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (lastMsg.isNotEmpty)
                      Text(lastMsg,
                          style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Bouton supprimer
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, size: 18.sp, color: cs.outlineVariant),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.h),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
