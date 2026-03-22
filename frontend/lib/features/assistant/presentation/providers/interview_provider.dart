import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:frontend/features/assistant/data/interview_service.dart';

final interviewServiceProvider = Provider((_) => InterviewService());

// ─── Usage ──────────────────────────────────────────────────────

final interviewUsageProvider =
    AsyncNotifierProvider<InterviewUsageNotifier, Map<String, dynamic>>(
        InterviewUsageNotifier.new);

class InterviewUsageNotifier extends AsyncNotifier<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> build() async {
    return await ref.read(interviewServiceProvider).getUsage();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(interviewServiceProvider).getUsage());
  }
}

// ─── Historique ─────────────────────────────────────────────────

final interviewHistoryProvider =
    AsyncNotifierProvider<InterviewHistoryNotifier, List<Map<String, dynamic>>>(
        InterviewHistoryNotifier.new);

class InterviewHistoryNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return await ref.read(interviewServiceProvider).getHistory();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(interviewServiceProvider).getHistory());
  }

  Future<void> deleteSession(String id) async {
    await ref.read(interviewServiceProvider).deleteSession(id);
    await refresh();
    ref.invalidate(interviewUsageProvider);
  }

  Future<int> deleteAll() async {
    final count = await ref.read(interviewServiceProvider).deleteAll();
    await refresh();
    ref.invalidate(interviewUsageProvider);
    return count;
  }
}

// ─── Chat (state pour le WebSocket) ─────────────────────────────

class ChatMessage {
  final String role; // 'assistant' | 'user'
  final String content;
  final Map<String, dynamic>? feedback;
  final bool isStreaming; // true pendant le streaming du message assistant

  const ChatMessage({
    required this.role,
    required this.content,
    this.feedback,
    this.isStreaming = false,
  });

  ChatMessage copyWith({
    String? content,
    Map<String, dynamic>? feedback,
    bool? isStreaming,
  }) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      feedback: feedback ?? this.feedback,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class InterviewChatState {
  final String status; // idle | connecting | connected | reconnecting | completed | error
  final String sessionId;
  final String jobTitle;
  final List<ChatMessage> messages;
  final int questionNumber;
  final bool isAiTyping;
  final Map<String, dynamic>? summary;
  final String? errorMessage;

  const InterviewChatState({
    this.status = 'idle',
    this.sessionId = '',
    this.jobTitle = '',
    this.messages = const [],
    this.questionNumber = 0,
    this.isAiTyping = false,
    this.summary,
    this.errorMessage,
  });

  InterviewChatState copyWith({
    String? status,
    String? sessionId,
    String? jobTitle,
    List<ChatMessage>? messages,
    int? questionNumber,
    bool? isAiTyping,
    Map<String, dynamic>? summary,
    String? errorMessage,
    bool clearSummary = false,
  }) {
    return InterviewChatState(
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      jobTitle: jobTitle ?? this.jobTitle,
      messages: messages ?? this.messages,
      questionNumber: questionNumber ?? this.questionNumber,
      isAiTyping: isAiTyping ?? this.isAiTyping,
      summary: clearSummary ? null : (summary ?? this.summary),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final interviewChatProvider =
    NotifierProvider<InterviewChatNotifier, InterviewChatState>(
        InterviewChatNotifier.new);

class InterviewChatNotifier extends Notifier<InterviewChatState> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  @override
  InterviewChatState build() => const InterviewChatState();

  /// Initialise le chat avec la première question (déjà reçue via REST).
  void initWithFirstQuestion({
    required String sessionId,
    required String jobTitle,
    required String firstMessage,
    required int questionNumber,
  }) {
    state = InterviewChatState(
      status: 'connected',
      sessionId: sessionId,
      jobTitle: jobTitle,
      messages: [
        ChatMessage(role: 'assistant', content: firstMessage),
      ],
      questionNumber: questionNumber,
    );
  }

  /// Charge une session existante (reprise).
  void loadExistingMessages({
    required String sessionId,
    required String jobTitle,
    required List<Map<String, dynamic>> messages,
  }) {
    final chatMessages = messages.map((m) => ChatMessage(
          role: m['role'] as String,
          content: m['content'] as String,
          feedback: m['feedback'] as Map<String, dynamic>?,
        )).toList();

    // Trouver le dernier question_number
    int lastQ = 0;
    for (final m in messages) {
      final f = m['feedback'] as Map<String, dynamic>?;
      if (f != null && f.containsKey('question_number')) {
        lastQ = f['question_number'] as int? ?? lastQ;
      }
    }

    state = InterviewChatState(
      status: 'connected',
      sessionId: sessionId,
      jobTitle: jobTitle,
      messages: chatMessages,
      questionNumber: lastQ,
    );
  }

  /// Connecte le WebSocket.
  void connectWebSocket(String token) {
    final svc = ref.read(interviewServiceProvider);
    _channel = svc.connectWebSocket(state.sessionId, token);
    state = state.copyWith(status: 'connected');

    _subscription = _channel!.stream.listen(
      (data) => _handleWebSocketMessage(data as String),
      onDone: () {
        if (state.status == 'connected') {
          state = state.copyWith(status: 'reconnecting');
          // Tentative de reconnexion après 2s
          Future.delayed(const Duration(seconds: 2), () {
            if (state.status == 'reconnecting') {
              connectWebSocket(token);
            }
          });
        }
      },
      onError: (e) {
        debugPrint('WebSocket error: $e');
        state = state.copyWith(status: 'error', errorMessage: e.toString());
      },
    );
  }

  /// Envoie un message utilisateur.
  void sendMessage(String text) {
    if (text.trim().isEmpty || state.isAiTyping) return;

    // Ajouter le message utilisateur (optimistic UI)
    final updatedMessages = [
      ...state.messages,
      ChatMessage(role: 'user', content: text.trim()),
    ];
    state = state.copyWith(messages: updatedMessages, isAiTyping: true);

    // Envoyer via WebSocket
    _channel?.sink.add(jsonEncode({'message': text.trim()}));
  }

  void _handleWebSocketMessage(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';

      switch (type) {
        case 'stream':
          _handleStreamChunk(data['text'] as String? ?? '');
        case 'stream_end':
          _handleStreamEnd();
        case 'feedback':
          _handleFeedback(data['data'] as Map<String, dynamic>);
        case 'summary':
          _handleSummary(data['data'] as Map<String, dynamic>);
        case 'error':
          state = state.copyWith(
            isAiTyping: false,
            errorMessage: data['message'] as String?,
          );
      }
    } catch (e) {
      debugPrint('WebSocket parse error: $e');
    }
  }

  void _handleStreamChunk(String text) {
    final messages = List<ChatMessage>.from(state.messages);

    if (messages.isEmpty || messages.last.role != 'assistant' || !messages.last.isStreaming) {
      // Créer une nouvelle bulle assistant en mode streaming
      messages.add(ChatMessage(role: 'assistant', content: text, isStreaming: true));
    } else {
      // Ajouter au message assistant en cours
      final last = messages.removeLast();
      messages.add(last.copyWith(content: last.content + text));
    }

    state = state.copyWith(messages: messages, isAiTyping: true);
  }

  void _handleStreamEnd() {
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty && messages.last.isStreaming) {
      final last = messages.removeLast();
      messages.add(last.copyWith(isStreaming: false));
    }
    state = state.copyWith(messages: messages);
  }

  void _handleFeedback(Map<String, dynamic> feedbackData) {
    final messages = List<ChatMessage>.from(state.messages);

    // Attacher le feedback au dernier message assistant
    if (messages.isNotEmpty && messages.last.role == 'assistant') {
      final last = messages.removeLast();
      messages.add(last.copyWith(feedback: feedbackData));
    }

    final questionNumber = feedbackData['question_number'] as int? ?? state.questionNumber;
    final isLast = feedbackData['is_last'] as bool? ?? false;

    state = state.copyWith(
      messages: messages,
      questionNumber: questionNumber,
      isAiTyping: false,
      status: isLast ? 'completed' : state.status,
    );
  }

  void _handleSummary(Map<String, dynamic> summaryData) {
    state = state.copyWith(
      summary: summaryData,
      status: 'completed',
      isAiTyping: false,
    );
    // Rafraîchir l'historique et l'usage
    ref.invalidate(interviewHistoryProvider);
    ref.invalidate(interviewUsageProvider);
  }

  /// Ferme la connexion WebSocket.
  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscription = null;
  }

  /// Reset complet.
  void reset() {
    disconnect();
    state = const InterviewChatState();
  }
}
