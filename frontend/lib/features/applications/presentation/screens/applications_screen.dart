import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/core/constants/application_status.dart';
import 'package:frontend/features/applications/presentation/providers/applications_provider.dart';
import 'package:frontend/features/applications/presentation/widgets/add_application_dialog.dart';
import 'package:frontend/features/applications/presentation/widgets/application_card.dart';
import 'package:frontend/features/applications/presentation/widgets/dismissible_filter_chip.dart';

class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedStatuses = {};
  String _timeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filtrage local (recherche + statuts + date) ─────────────

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> apps) {
    return apps.where((app) {
      // Recherche texte : entreprise OU poste
      if (_searchQuery.isNotEmpty) {
        final c = (app['company_name'] ?? '').toString().toLowerCase();
        final j = (app['job_title'] ?? '').toString().toLowerCase();
        if (!c.contains(_searchQuery) && !j.contains(_searchQuery)) return false;
      }
      // Filtre statuts (multi-sélection)
      if (_selectedStatuses.isNotEmpty && !_selectedStatuses.contains(app['status'])) return false;
      // Filtre date
      if (_timeFilter != 'all') {
        final d = DateTime.tryParse(app['applied_at'] ?? '');
        if (d == null) return false;
        final diff = DateTime.now().difference(d).inDays;
        if (_timeFilter == 'today' && diff > 0) return false;
        if (_timeFilter == '7d' && diff > 7) return false;
        if (_timeFilter == '30d' && diff > 30) return false;
      }
      return true;
    }).toList();
  }

  bool get _hasFilters => _selectedStatuses.isNotEmpty || _timeFilter != 'all';

  String _timeLabel(AppLocalizations t) => switch (_timeFilter) {
    'today' => t.t('applications_screen.time_today'),
    '7d' => t.t('applications_screen.time_7d'),
    '30d' => t.t('applications_screen.time_30d'),
    _ => '',
  };

  // ── Actions ─────────────────────────────────────────────────

  void _openFilters(AppLocalizations t) {
    final tempStatuses = Set<String>.from(_selectedStatuses);
    var tempTime = _timeFilter;
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20.w,
            16.h,
            20.w,
            MediaQuery.of(ctx).viewInsets.bottom + 28.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              // Section statuts
              Text(
                t.t('applications_screen.filter_status'),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: ApplicationStatuses.all.map((cfg) {
                  final sel = tempStatuses.contains(cfg.key);
                  return GestureDetector(
                    onTap: () => setSheet(
                      () => sel
                          ? tempStatuses.remove(cfg.key)
                          : tempStatuses.add(cfg.key),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 7.h,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? cfg.bgColor
                            : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: sel ? cfg.borderColor : cs.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        t.t('applications_screen.status_${cfg.key}'),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: sel ? cfg.textColor : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 24.h),
              // Section date
              Text(
                t.t('applications_screen.filter_date'),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children:
                    [
                      ('all', t.t('applications_screen.time_all')),
                      ('today', t.t('applications_screen.time_today')),
                      ('7d', t.t('applications_screen.time_7d')),
                      ('30d', t.t('applications_screen.time_30d')),
                    ].map((e) {
                      final sel = tempTime == e.$1;
                      return GestureDetector(
                        onTap: () => setSheet(() => tempTime = e.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? cs.primary
                                : cs.surfaceContainerHighest.withValues(
                                    alpha: 0.4,
                                  ),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: sel ? cs.primary : cs.outlineVariant,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            e.$2,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: sel ? cs.onPrimary : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
              SizedBox(height: 28.h),
              // Bouton appliquer
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      _selectedStatuses
                        ..clear()
                        ..addAll(tempStatuses);
                      _timeFilter = tempTime;
                    });
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: Size(0, 48.h),
                  ),
                  child: Text(
                    t.t('applications_screen.filter_apply'),
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String id, AppLocalizations t) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(t.t('applications_screen.delete_title')),
        content: Text(t.t('applications_screen.delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.t('settings.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t.t('application_detail.delete'),
              style: TextStyle(color: cs.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(applicationsProvider.notifier).delete(id);
    } catch (_) {
      if (mounted)  AppSnackbar.error(context, t.t('applications_screen.delete_error'));
    }
  }

  Future<void> _showAdd(AppLocalizations t) async {
    final result = await showDialog<AddApplicationResult>(
      context: context,
      builder: (_) => const AddApplicationDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await ref
          .read(applicationsProvider.notifier)
          .create(
            result.data,
            cvPath: result.cvPath,
            cvFilename: result.cvFilename,
          );
    } catch (_) {
      if (mounted) AppSnackbar.error(context, t.t('applications_screen.add_error'));
    }
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final appsAsync = ref.watch(applicationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('applications_screen.title')),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: cs.primary,
          onPressed: () => _showAdd(t),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Icon(Icons.add_rounded, size: 28.sp),
        ),
      ),
      body: appsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              Center(child: Text(t.t('applications_screen.add_error'))),
          data: (apps) {
            final filtered = _filter(apps);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Compteur de résultats
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
                  child: Text(
                    '${filtered.length} ${t.t('applications_screen.results_count')}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                // Barre de recherche + filtre
                _buildSearchBar(t, cs),
                // Chips de filtres actifs
                if (_hasFilters) ...[
                  SizedBox(height: 10.h),
                  _buildActiveChips(t, cs),
                ],
                SizedBox(height: 12.h),
                // Liste ou état vide
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmpty(t, cs, apps.isEmpty)
                      : RefreshIndicator(
                          onRefresh: () =>
                              ref.read(applicationsProvider.notifier).refresh(),
                          child: ListView.builder(
                            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 100.h),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: ApplicationCard(
                                app: filtered[i],
                                onTap: () => context.push(
                                  '/applications/${filtered[i]['id']}',
                                ),
                                onDelete: () => _confirmDelete(
                                  filtered[i]['id'].toString(),
                                  t,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
    );
  }

  Widget _buildSearchBar(AppLocalizations t, ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.r),
                border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: t.t('applications_screen.search_hint'),
                  hintStyle: TextStyle(
                    fontSize: 13.sp,
                    color: cs.onSurfaceVariant,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20.sp,
                    color: cs.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          GestureDetector(
            onTap: () => _openFilters(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 46.w,
              height: 46.h,
              decoration: BoxDecoration(
                color: _hasFilters ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(30.r),
                border: Border.all(
                  color: _hasFilters ? cs.primary : const Color(0xFFD1D5DB),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 20.sp,
                color: _hasFilters ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChips(AppLocalizations t, ColorScheme cs) {
    return SizedBox(
      height: 34.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        children: [
          ..._selectedStatuses.map((key) {
            final cfg = ApplicationStatuses.fromKey(key);
            return Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: DismissibleFilterChip(
                label: t.t('applications_screen.status_$key'),
                textColor: cfg.textColor,
                bgColor: cfg.bgColor,
                borderColor: cfg.borderColor,
                onRemove: () => setState(() => _selectedStatuses.remove(key)),
              ),
            );
          }),
          if (_timeFilter != 'all')
            DismissibleFilterChip(
              label: _timeLabel(t),
              textColor: cs.primary,
              bgColor: cs.primary.withValues(alpha: 0.1),
              borderColor: cs.primary.withValues(alpha: 0.4),
              onRemove: () => setState(() => _timeFilter = 'all'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations t, ColorScheme cs, bool globalEmpty) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!globalEmpty)
              Container(
                width: 80.r,
                height: 80.r,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 36.sp,
                  color: cs.primary,
                ),
              ),
            if (!globalEmpty) SizedBox(height: 20.h),
            Text(
              globalEmpty
                  ? t.t('applications_screen.empty_title')
                  : t.t('applications_screen.no_results'),
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (globalEmpty) ...[
              SizedBox(height: 8.h),
              Text(
                t.t('applications_screen.empty_subtitle'),
                style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
