import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/core/constants/application_status.dart';
import 'package:frontend/core/widgets/shimmer_loading.dart';
import 'package:frontend/core/utils/haptic.dart';
import 'package:frontend/features/applications/presentation/providers/applications_provider.dart';
import 'package:frontend/features/assistant/presentation/providers/interview_provider.dart';
import 'package:frontend/features/assistant/presentation/screens/interview_form_dialog.dart';
import 'package:frontend/features/settings/presentation/providers/preferences_provider.dart';

class ApplicationDetailScreen extends ConsumerStatefulWidget {
  final String applicationId;
  const ApplicationDetailScreen({super.key, required this.applicationId});

  @override
  ConsumerState<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState
    extends ConsumerState<ApplicationDetailScreen> {
  Map<String, dynamic>? _app;
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref
          .read(applicationServiceProvider)
          .getById(widget.applicationId);
      if (mounted) setState(() => _app = data);
    } catch (_) {}
  }

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _delete(AppLocalizations t) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(t.t('application_detail.delete_title')),
        content: Text(t.t('application_detail.delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.t('settings.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: Text(t.t('application_detail.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(applicationsProvider.notifier)
          .delete(widget.applicationId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        AppSnackbar.error(context, t.t('applications_screen.delete_error'));
    }
  }

  Future<void> _startInterview(AppLocalizations t) async {
    final app = _app!;

    // Vérifier la limite
    final usage = await ref.read(interviewUsageProvider.future);
    if ((usage['remaining'] as int? ?? 0) <= 0) {
      if (mounted) AppSnackbar.error(context, t.t('interview.limit_reached'));
      return;
    }

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => InterviewFormDialog(
        initialJobTitle: app['job_title'] as String?,
        initialCompanyName: app['company_name'] as String?,
        initialJobDescription: app['job_description'] as String?,
        initialLanguage: ref.read(preferencesProvider).resolveAiLanguage('fr'),
        onLanguageChanged: (v) =>
            ref.read(preferencesProvider.notifier).setAiLanguage(v),
      ),
    );
    if (result == null || !mounted) return;

    try {
      final svc = ref.read(interviewServiceProvider);
      final response = await svc.startSession(
        jobTitle: result['job_title'] as String,
        companyName: result['company_name'] as String?,
        jobDescription: result['job_description'] as String?,
        cvPath: result['cv_path'] as String?,
        language: result['language'] as String? ?? 'fr',
      );

      if (!mounted) return;

      final sessionId = response['session_id'] as String;
      final firstQ = response['first_question'] as Map<String, dynamic>;
      ref
          .read(interviewChatProvider.notifier)
          .initWithFirstQuestion(
            sessionId: sessionId,
            jobTitle: result['job_title'] as String,
            firstMessage: firstQ['message'] as String,
            questionNumber: firstQ['question_number'] as int? ?? 1,
          );

      ref.invalidate(interviewHistoryProvider);
      ref.invalidate(interviewUsageProvider);

      context.push('/assistant/interview/chat/$sessionId');
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('429')) {
        AppSnackbar.error(context, t.t('interview.limit_reached'));
      } else {
        AppSnackbar.error(context, t.t('interview.start_error'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    if (_app == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const ApplicationDetailSkeleton(),
      );
    }

    final app = _app!;
    final status = (app['status'] ?? 'saved').toString();
    final cfg = ApplicationStatuses.fromKey(status);
    final company = (app['company_name'] ?? '').toString();
    final jobTitle = (app['job_title'] ?? '').toString();
    final initial = company.isNotEmpty ? company[0].toUpperCase() : '?';
    final jobUrl = app['job_url'] as String?;
    final cvUrl = app['cv_url'] as String?;
    final description = app['job_description'] as String?;
    final notes = app['notes'] as String?;
    final appliedAt = app['applied_at'] as String?;
    final updatedAt = app['updated_at'] as String?;

    final isInterview = [
      'phone_screen',
      'technical',
      'final_interview',
    ].contains(status);

    return Scaffold(
      appBar: AppBar(
        title: Text(jobTitle),
        actions: [
          IconButton(
            onPressed: () async {
              final changed = await context.push<bool>(
                '/applications/${widget.applicationId}/edit',
              );
              if (changed == true) _load();
            },
            icon: Icon(Icons.edit_rounded, size: 20.sp),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            20.w,
            12.h,
            20.w,
            32.h + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            // Header: avatar + company + badge
            Row(
              children: [
                Hero(
                  tag: 'app_avatar_${widget.applicationId}',
                  child: Container(
                    width: 52.r,
                    height: 52.r,
                    decoration: BoxDecoration(
                      color: cfg.bgColor,
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                          color: cfg.textColor,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: cfg.bgColor,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: cfg.borderColor),
                        ),
                        child: Text(
                          t.t('applications_screen.status_$status'),
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: cfg.textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Info tiles
            if (appliedAt != null)
              _tile(
                Icons.calendar_today_rounded,
                t.t('application_detail.applied_on'),
                _fmt(appliedAt),
                cs,
              ),
            if (jobUrl != null && jobUrl.isNotEmpty)
              _linkTile(
                Icons.link_rounded,
                t.t('application_detail.job_url'),
                jobUrl,
                cs,
              ),
            if (cvUrl != null)
              _linkTile(
                Icons.picture_as_pdf_rounded,
                t.t('application_detail.cv'),
                cvUrl,
                cs,
              ),

            // Description (pliable)
            if (description != null && description.isNotEmpty) ...[
              SizedBox(height: 20.h),
              _expandableSection(
                t.t('application_detail.description'),
                description,
                cs,
                t,
              ),
            ],

            // Notes
            if (notes != null && notes.isNotEmpty) ...[
              SizedBox(height: 20.h),
              _section(t.t('application_detail.notes'), notes, cs),
            ],

            // Prepare interview button
            if (isInterview) ...[
              SizedBox(height: 24.h),
              FilledButton(
                onPressed: () {
                  Haptic.medium();
                  _startInterview(t);
                },
                style: FilledButton.styleFrom(
                  minimumSize: Size(double.infinity, 48.h),
                ),
                child: Text(t.t('application_detail.prepare_interview')),
              ),
            ],

            // Updated at
            if (updatedAt != null) ...[
              SizedBox(height: 24.h),
              Center(
                child: Text(
                  '${t.t('application_detail.updated')} ${_fmt(updatedAt)}',
                  style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
                ),
              ),
            ],

            // Delete button
            SizedBox(height: 24.h),
            OutlinedButton.icon(
              onPressed: () {
                Haptic.heavy();
                _delete(t);
              },
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18.sp,
                color: cs.error,
              ),
              label: Text(
                t.t('application_detail.delete'),
                style: TextStyle(color: cs.error),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 44.h),
                side: BorderSide(color: cs.error.withValues(alpha: 0.3)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: cs.onSurfaceVariant),
          SizedBox(width: 10.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkTile(IconData icon, String label, String url, ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: InkWell(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            children: [
              Icon(icon, size: 18.sp, color: cs.primary),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 16.sp, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _expandableSection(
    String title,
    String content,
    ColorScheme cs,
    AppLocalizations t,
  ) {
    const maxLines = 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedCrossFade(
                firstChild: Text(
                  content,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                secondChild: Text(
                  content,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                crossFadeState: _descriptionExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
              // Afficher le bouton seulement si le texte dépasse maxLines
              LayoutBuilder(
                builder: (context, constraints) {
                  final tp = TextPainter(
                    text: TextSpan(
                      text: content,
                      style: TextStyle(fontSize: 13.sp, height: 1.5),
                    ),
                    maxLines: maxLines,
                    textDirection: TextDirection.ltr,
                  )..layout(maxWidth: constraints.maxWidth);

                  if (!tp.didExceedMaxLines) return const SizedBox.shrink();

                  return GestureDetector(
                    onTap: () => setState(
                      () => _descriptionExpanded = !_descriptionExpanded,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _descriptionExpanded
                                ? t.t('application_detail.show_less')
                                : t.t('application_detail.show_more'),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            _descriptionExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16.sp,
                            color: cs.primary,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String title, String content, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 13.sp,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
