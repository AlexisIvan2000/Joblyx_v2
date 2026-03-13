import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/core/widgets/shimmer_loading.dart';
import 'package:frontend/features/applications/presentation/providers/applications_provider.dart';
import 'package:frontend/features/applications/presentation/widgets/add_application_dialog.dart';
import 'package:frontend/features/applications/presentation/widgets/application_card.dart';
import 'package:frontend/features/applications/presentation/widgets/application_filter_chips.dart';
import 'package:frontend/features/applications/presentation/widgets/application_search_bar.dart';

class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen> {
  // Filtres actifs
  String _statusFilter = 'all';
  String _timeFilter = 'all_time';

  // Contrôleur pour la barre de recherche
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Applique les 3 filtres (recherche, statut, période) sur la liste.
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> apps) {
    var result = apps;

    // Filtre par recherche textuelle
    if (_searchQuery.isNotEmpty) {
      result = result.where((a) {
        final company = (a['company_name'] as String? ?? '').toLowerCase();
        final title = (a['job_title'] as String? ?? '').toLowerCase();
        return company.contains(_searchQuery) || title.contains(_searchQuery);
      }).toList();
    }

    // Filtre par statut
    if (_statusFilter == 'active') {
      result = result.where((a) =>
          ['applied', 'phone_screen', 'technical', 'final_interview']
              .contains(a['status'])).toList();
    } else if (_statusFilter == 'interviews') {
      result = result.where((a) =>
          ['phone_screen', 'technical', 'final_interview']
              .contains(a['status'])).toList();
    } else if (_statusFilter == 'closed') {
      result = result.where((a) =>
          ['rejected', 'withdrawn', 'accepted']
              .contains(a['status'])).toList();
    }

    // Filtre par période
    if (_timeFilter != 'all_time') {
      final now = DateTime.now();
      final cutoff = switch (_timeFilter) {
        'today' => DateTime(now.year, now.month, now.day),
        '7d' => now.subtract(const Duration(days: 7)),
        '30d' => now.subtract(const Duration(days: 30)),
        _ => DateTime(2000),
      };
      result = result.where((a) {
        final dateStr = a['applied_at'] as String?;
        if (dateStr == null) return false;
        final date = DateTime.tryParse(dateStr);
        return date != null && date.isAfter(cutoff);
      }).toList();
    }

    return result;
  }

  /// Ouvre le dialog d'ajout de candidature.
  Future<void> _openAddDialog() async {
    final t = AppLocalizations.of(context);
    final result = await showDialog<AddApplicationResult>(
      context: context,
      builder: (_) => const AddApplicationDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(applicationsProvider.notifier).create(
        result.data,
        cvPath: result.cvFile?.path,
        cvFilename: result.cvFile?.name,
      );
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(context, t.t('applications_screen.add_error'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final appsAsync = ref.watch(applicationsProvider);

    return Scaffold(
      body: SafeArea(
        child: appsAsync.when(
          loading: () => const ApplicationsSkeleton(),
          error: (_, _) => _buildError(cs, t),
          data: (applications) {
            final filtered = _applyFilters(applications);
            return RefreshIndicator(
              onRefresh: () => ref.read(applicationsProvider.notifier).refresh(),
              child: ListView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
                children: [
                  // En-tête : titre + bouton ajouter
                  _buildHeader(cs, t),
                  SizedBox(height: 14.h),

                  // Barre de recherche
                  ApplicationSearchBar(
                    controller: _searchController,
                    onClear: () => _searchController.clear(),
                  ),
                  SizedBox(height: 12.h),

                  // Filtres par statut
                  StatusFilterChips(
                    current: _statusFilter,
                    onChanged: (v) => setState(() => _statusFilter = v),
                  ),
                  SizedBox(height: 8.h),

                  // Filtres par période
                  TimeFilterChips(
                    current: _timeFilter,
                    onChanged: (v) => setState(() => _timeFilter = v),
                  ),
                  SizedBox(height: 14.h),

                  // Compteur de résultats
                  Text(
                    '${filtered.length} ${t.t('applications_screen.results_count')}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 10.h),

                  // Liste des candidatures ou état vide
                  if (filtered.isEmpty)
                    _buildEmpty(cs, t)
                  else
                    ...filtered.map((app) => Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: ApplicationCard(
                        app: app,
                        onTap: () {
                          final id = app['id'] as String?;
                          if (id != null) context.push('/applications/$id');
                        },
                      ),
                    )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// En-tête avec titre et bouton d'ajout.
  Widget _buildHeader(ColorScheme cs, AppLocalizations t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          t.t('applications_screen.title'),
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: IconButton(
            icon: Icon(Icons.add, color: Colors.white, size: 20.sp),
            padding: EdgeInsets.zero,
            onPressed: _openAddDialog,
          ),
        ),
      ],
    );
  }

  /// État vide (aucun résultat).
  Widget _buildEmpty(ColorScheme cs, AppLocalizations t) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 60.h),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 40.sp, color: cs.onSurfaceVariant),
            SizedBox(height: 10.h),
            Text(
              t.t('applications_screen.no_results'),
              style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// État d'erreur de chargement.
  Widget _buildError(ColorScheme cs, AppLocalizations t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48.sp, color: cs.error),
          SizedBox(height: 12.h),
          Text(t.t('applications_screen.empty')),
          SizedBox(height: 12.h),
          FilledButton(
            onPressed: () => ref.read(applicationsProvider.notifier).refresh(),
            child: Text(t.t('settings.retry')),
          ),
        ],
      ),
    );
  }
}
