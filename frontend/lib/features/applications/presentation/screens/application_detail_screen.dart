import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/applications/presentation/providers/applications_provider.dart';
import 'package:frontend/features/roadmap/presentation/screens/dashboard_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final svc = ref.read(applicationServiceProvider);
      final data = await svc.getById(widget.applicationId);
      if (mounted) setState(() => _app = data);
    } catch (_) {
      // will show error state
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_app?['job_title'] as String? ?? ''),
        actions: [
          IconButton(
            onPressed: () => _confirmDelete(context, t),
            icon: Icon(Icons.delete_outline_rounded, size: 22.sp),
            tooltip: t.t('application_detail.delete'),
          ),
        ],
      ),
      body: _app == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDetail,
              child: ListView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
                children: [
                  // Company + status
                  _buildHeader(cs, t),
                  SizedBox(height: 20.h),

                  // Status selector
                  _buildStatusSection(cs, t),
                  SizedBox(height: 20.h),

                  // Info cards
                  if (_app!['applied_at'] != null)
                    _buildInfoTile(
                      Icons.calendar_today_rounded,
                      t.t('application_detail.applied_on'),
                      _formatDate(_app!['applied_at'] as String),
                      cs,
                    ),
                  if (_app!['job_url'] != null &&
                      (_app!['job_url'] as String).isNotEmpty)
                    _buildLinkTile(
                      Icons.link_rounded,
                      t.t('application_detail.job_url'),
                      _app!['job_url'] as String,
                      cs,
                    ),
                  if (_app!['cv_url'] != null)
                    _buildLinkTile(
                      Icons.picture_as_pdf_rounded,
                      t.t('application_detail.cv'),
                      _app!['cv_url'] as String,
                      cs,
                    ),

                  // Job description
                  if (_app!['job_description'] != null &&
                      (_app!['job_description'] as String).isNotEmpty) ...[
                    SizedBox(height: 20.h),
                    _buildSection(
                      t.t('application_detail.description'),
                      _app!['job_description'] as String,
                      cs,
                    ),
                  ],

                  // Notes
                  if (_app!['notes'] != null &&
                      (_app!['notes'] as String).isNotEmpty) ...[
                    SizedBox(height: 20.h),
                    _buildSection(
                      t.t('application_detail.notes'),
                      _app!['notes'] as String,
                      cs,
                    ),
                  ],

                  // Updated at
                  if (_app!['updated_at'] != null) ...[
                    SizedBox(height: 24.h),
                    Center(
                      child: Text(
                        '${t.t('application_detail.updated')} ${_formatDate(_app!['updated_at'] as String)}',
                        style: TextStyle(
                            fontSize: 11.sp, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(ColorScheme cs, AppLocalizations t) {
    final company = _app!['company_name'] as String? ?? '';
    final status = _app!['status'] as String? ?? 'applied';

    return Row(
      children: [
        Container(
          width: 52.w,
          height: 52.w,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Center(
            child: Text(
              company.isNotEmpty ? company[0].toUpperCase() : '?',
              style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: cs.primary),
            ),
          ),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(company,
                  style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface)),
              SizedBox(height: 4.h),
              StatusBadge(status: status, t: t),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(ColorScheme cs, AppLocalizations t) {
    final currentStatus = _app!['status'] as String? ?? 'applied';
    final statuses = [
      ('applied', t.t('applications_screen.status_applied')),
      ('phone_screen', t.t('applications_screen.status_phone_screen')),
      ('technical', t.t('applications_screen.status_technical')),
      ('final_interview', t.t('applications_screen.status_final_interview')),
      ('offer', t.t('applications_screen.status_offer')),
      ('accepted', t.t('applications_screen.status_accepted')),
      ('rejected', t.t('applications_screen.status_rejected')),
      ('withdrawn', t.t('applications_screen.status_withdrawn')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.t('application_detail.update_status'),
            style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: cs.onSurface)),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 6.w,
          runSpacing: 6.h,
          children: statuses.map((s) {
            final isSelected = s.$1 == currentStatus;
            return Material(
              color: isSelected ? cs.primary : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20.r),
              child: InkWell(
                onTap: () => _updateStatus(s.$1, t),
                borderRadius: BorderRadius.circular(20.r),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                  child: Text(s.$2,
                      style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? cs.onPrimary
                              : cs.onSurfaceVariant)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInfoTile(
      IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: cs.onSurfaceVariant),
          SizedBox(width: 10.w),
          Text(label,
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
        ],
      ),
    );
  }

  Widget _buildLinkTile(
      IconData icon, String label, String url, ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: Colors.transparent,
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
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                          decoration: TextDecoration.underline)),
                ),
                Icon(Icons.open_in_new_rounded,
                    size: 16.sp, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: cs.onSurface)),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(content,
              style: TextStyle(
                  fontSize: 13.sp,
                  color: cs.onSurfaceVariant,
                  height: 1.5)),
        ),
      ],
    );
  }

  Future<void> _updateStatus(String newStatus, AppLocalizations t) async {
    if (newStatus == _app!['status']) return;
    // Optimistic update — instant UI feedback
    final previousApp = Map<String, dynamic>.from(_app!);
    setState(() => _app!['status'] = newStatus);
    try {
      final svc = ref.read(applicationServiceProvider);
      final updated =
          await svc.update(widget.applicationId, {'status': newStatus});
      // Preserve cv_url — the PUT response doesn't include the signed URL
      if (mounted) {
        updated['cv_url'] ??= previousApp['cv_url'];
        setState(() => _app = updated);
      }
      ref.read(applicationsProvider.notifier).refresh();
    } catch (_) {
      // Rollback on failure
      if (mounted) {
        setState(() => _app = previousApp);
        AppSnackbar.error(
            context, t.t('application_detail.update_error'));
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, AppLocalizations t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(t.t('application_detail.delete_title')),
        content: Text(t.t('application_detail.delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.t('settings.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(t.t('application_detail.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(applicationsProvider.notifier).delete(widget.applicationId);
      if (!mounted) return;
      Navigator.pop(this.context);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(
          this.context, t.t('applications_screen.delete_error'));
    }
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
