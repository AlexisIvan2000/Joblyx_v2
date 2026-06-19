import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/assistant/presentation/providers/coach_provider.dart';
import 'package:frontend/features/assistant/presentation/widgets/coach_sections.dart';

/// Écran détail d'une session coach historique (pas de nouvel appel GPT).
class CoachDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const CoachDetailScreen({super.key, required this.sessionId});

  @override
  ConsumerState<CoachDetailScreen> createState() => _CoachDetailScreenState();
}

class _CoachDetailScreenState extends ConsumerState<CoachDetailScreen> {
  Map<String, dynamic>? _session;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = ref.read(coachServiceProvider);
      final session = await svc.getSession(widget.sessionId);
      if (mounted) {
        setState(() {
          _session = session;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _session?['job_title'] as String? ?? t.t('assistant.result_title'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _session == null
            ? Center(child: Text(t.t('assistant.session_not_found')))
            : CoachAnalysisView(
                analysis: _session!['analysis'] as Map<String, dynamic>? ?? {},
                isStreaming: false,
              ),
      ),
    );
  }
}
