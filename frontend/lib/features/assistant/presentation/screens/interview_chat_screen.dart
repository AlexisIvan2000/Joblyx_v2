import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/features/authentication/data/auth_storage.dart';
import 'package:frontend/core/widgets/app_snackbar.dart';
import 'package:frontend/features/assistant/presentation/providers/interview_provider.dart';

/// Écran chat d'entretien avec WebSocket streaming.
class InterviewChatScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const InterviewChatScreen({super.key, required this.sessionId});

  @override
  ConsumerState<InterviewChatScreen> createState() => _InterviewChatScreenState();
}

class _InterviewChatScreenState extends ConsumerState<InterviewChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _tipDismissed = false;

  @override
  void initState() {
    super.initState();
    _connectIfNeeded();
  }

  void _connectIfNeeded() {
    final chatState = ref.read(interviewChatProvider);

    // Si le chat n'est pas initialisé (reprise), charger les messages
    if (chatState.sessionId != widget.sessionId || chatState.messages.isEmpty) {
      _loadExistingSession();
    } else {
      _connectWs();
    }
  }

  Future<void> _connectWs() async {
    final token = await AuthStorage().getAccessToken();
    if (token != null && mounted) {
      ref.read(interviewChatProvider.notifier).connectWebSocket(token);
    }
  }

  Future<void> _loadExistingSession() async {
    try {
      final svc = ref.read(interviewServiceProvider);
      final session = await svc.getSession(widget.sessionId);
      if (!mounted) return;

      ref.read(interviewChatProvider.notifier).loadExistingMessages(
        sessionId: widget.sessionId,
        jobTitle: session['job_title'] as String? ?? '',
        messages: (session['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      );

      if (session['status'] == 'in_progress') {
        await _connectWs();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    ref.read(interviewChatProvider.notifier).disconnect();
    super.dispose();
  }

  void _send() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    ref.read(interviewChatProvider.notifier).sendMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _endEarly() async {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text(t.t('interview.end_early_title')),
        content: Text(t.t('interview.end_early_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('settings.cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.t('interview.end_button')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(interviewServiceProvider).endSessionEarly(widget.sessionId);
    } catch (_) {
      if (mounted) AppSnackbar.error(context, t.t('interview.end_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final chatState = ref.watch(interviewChatProvider);

    // Naviguer vers le bilan quand le summary arrive
    if (chatState.summary != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/assistant/interview/summary/${widget.sessionId}');
      });
    }

    // Auto-scroll quand un nouveau message arrive
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final isCompleted = chatState.status == 'completed';
    final canSend = !chatState.isAiTyping && !isCompleted;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chatState.jobTitle, style: TextStyle(fontSize: 14.sp)),
            if (chatState.questionNumber > 0)
              Text('Question ${chatState.questionNumber}/15',
                  style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
          ],
        ),
        actions: [
          if (!isCompleted)
            TextButton(
              onPressed: _endEarly,
              child: Text(t.t('interview.end_button'),
                  style: TextStyle(fontSize: 12.sp, color: cs.error)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Barre de progression
          if (chatState.questionNumber > 0)
            LinearProgressIndicator(
              value: chatState.questionNumber / 15,
              minHeight: 3.h,
              backgroundColor: cs.surfaceContainerHighest,
            ),

          // Encart conseil
          if (!_tipDismissed && chatState.messages.length <= 2)
            Container(
              margin: EdgeInsets.all(12.w),
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates_outlined, size: 16.sp, color: cs.primary),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(t.t('interview.star_tip'),
                        style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _tipDismissed = true),
                    child: Icon(Icons.close_rounded, size: 16.sp, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

          // Reconnexion
          if (chatState.status == 'reconnecting')
            Container(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              color: cs.error.withValues(alpha: 0.1),
              child: Center(
                child: Text(t.t('interview.reconnecting'),
                    style: TextStyle(fontSize: 11.sp, color: cs.error)),
              ),
            ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              itemCount: chatState.messages.length + (chatState.isAiTyping ? 1 : 0),
              itemBuilder: (context, index) {
                // Typing indicator
                if (index == chatState.messages.length && chatState.isAiTyping) {
                  final lastMsg = chatState.messages.isNotEmpty ? chatState.messages.last : null;
                  if (lastMsg != null && lastMsg.isStreaming) return const SizedBox.shrink();
                  return _TypingIndicator(cs: cs);
                }

                final msg = chatState.messages[index];
                return _ChatBubble(message: msg, cs: cs, t: t);
              },
            ),
          ),

          // Champ de saisie
          Container(
            padding: EdgeInsets.fromLTRB(12.w, 8.h, 8.w, MediaQuery.of(context).padding.bottom + 8.h),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: canSend,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: isCompleted
                          ? t.t('interview.chat_ended')
                          : t.t('interview.type_answer'),
                      hintStyle: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.r),
                        borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    ),
                    style: TextStyle(fontSize: 14.sp),
                  ),
                ),
                SizedBox(width: 6.w),
                IconButton(
                  onPressed: canSend ? _send : null,
                  icon: Icon(Icons.send_rounded, size: 22.sp),
                  color: cs.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bulle de chat ─────────────────────────────────────────────

class _ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final ColorScheme cs;
  final AppLocalizations t;

  const _ChatBubble({required this.message, required this.cs, required this.t});

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  bool _feedbackExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == 'user';
    final cs = widget.cs;
    final feedback = widget.message.feedback;
    final hasFeedback = feedback != null && feedback['feedback'] != null;
    final feedbackInner = hasFeedback ? feedback['feedback'] as Map<String, dynamic>? : null;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Bulle
          Container(
            constraints: BoxConstraints(maxWidth: 280.w),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: isUser ? cs.primary : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
                bottomLeft: isUser ? Radius.circular(16.r) : Radius.circular(4.r),
                bottomRight: isUser ? Radius.circular(4.r) : Radius.circular(16.r),
              ),
            ),
            child: Text(
              widget.message.content,
              style: TextStyle(
                fontSize: 13.sp,
                color: isUser ? cs.onPrimary : cs.onSurface,
                height: 1.4,
              ),
            ),
          ),

          // Feedback pliable sous la bulle assistant
          if (hasFeedback && feedbackInner != null)
            GestureDetector(
              onTap: () => setState(() => _feedbackExpanded = !_feedbackExpanded),
              child: Container(
                margin: EdgeInsets.only(top: 4.h),
                constraints: BoxConstraints(maxWidth: 280.w),
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${feedbackInner['score'] ?? '-'}/10',
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: cs.primary)),
                        SizedBox(width: 6.w),
                        Text(widget.t.t('interview.feedback_label'),
                            style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                        const Spacer(),
                        Icon(
                          _feedbackExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          size: 16.sp, color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                    if (_feedbackExpanded) ...[
                      SizedBox(height: 6.h),
                      if (feedbackInner['good'] != null)
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.check_circle_rounded, size: 13.sp, color: const Color(0xFF5DCAA5)),
                          SizedBox(width: 4.w),
                          Expanded(child: Text(feedbackInner['good'] as String,
                              style: TextStyle(fontSize: 11.sp, color: const Color(0xFF5DCAA5), height: 1.3))),
                        ]),
                      if (feedbackInner['improve'] != null) ...[
                        SizedBox(height: 4.h),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.info_outline_rounded, size: 13.sp, color: const Color(0xFFFFB347)),
                          SizedBox(width: 4.w),
                          Expanded(child: Text(feedbackInner['improve'] as String,
                              style: TextStyle(fontSize: 11.sp, color: const Color(0xFFFFB347), height: 1.3))),
                        ]),
                      ],
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Typing indicator ──────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  final ColorScheme cs;
  const _TypingIndicator({required this.cs});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: widget.cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final delay = i * 0.2;
                final t = (_controller.value - delay).clamp(0.0, 1.0);
                final opacity = (t < 0.5) ? t * 2 : (1.0 - t) * 2;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.w),
                  child: Opacity(
                    opacity: opacity.clamp(0.3, 1.0),
                    child: Container(
                      width: 7.w, height: 7.w,
                      decoration: BoxDecoration(
                        color: widget.cs.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
