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
  bool _active = true;
  bool _intentionalDisconnect = false;
  int _reconnectAttempts = 0;
  String? _lastToken;
  String? _lastUserMessage;
  Timer? _responseTimer;

  @override
  InterviewChatState build() {
    _active = true;
    _intentionalDisconnect = false;
    _reconnectAttempts = 0;
    return const InterviewChatState();
  }

  bool get _canUpdate => _active;

  // ─── Init ─────────────────────────────────────────────────────

  void initWithFirstQuestion({
    required String sessionId,
    required String jobTitle,
    required String firstMessage,
    required int questionNumber,
  }) {
    state = InterviewChatState(
      status: 'idle',
      sessionId: sessionId,
      jobTitle: jobTitle,
      messages: [ChatMessage(role: 'assistant', content: firstMessage)],
      questionNumber: questionNumber,
    );
  }

  void loadExistingMessages({
    required String sessionId,
    required String jobTitle,
    required List<Map<String, dynamic>> messages,
    bool isCompleted = false,
  }) {
    final chatMessages = messages.map((m) => ChatMessage(
          role: m['role'] as String,
          content: m['content'] as String,
          feedback: m['feedback'] as Map<String, dynamic>?,
        )).toList();

    int lastQ = 0;
    for (final m in messages) {
      final f = m['feedback'] as Map<String, dynamic>?;
      if (f != null && f.containsKey('question_number')) {
        lastQ = f['question_number'] as int? ?? lastQ;
      }
    }

    state = InterviewChatState(
      status: isCompleted ? 'completed' : 'idle',
      sessionId: sessionId,
      jobTitle: jobTitle,
      messages: chatMessages,
      questionNumber: lastQ,
    );
  }

  // ─── WebSocket ────────────────────────────────────────────────

  void connectWebSocket(String token) {
    // Fermer toute connexion existante
    _closeChannel();

    _active = true;
    _intentionalDisconnect = false;
    _lastToken = token;
    _reconnectAttempts = 0;

    debugPrint('[WS] Connecting to session ${state.sessionId}');

    final svc = ref.read(interviewServiceProvider);
    _channel = svc.connectWebSocket(state.sessionId, token);

    _subscription = _channel!.stream.listen(
      (data) {
        _reconnectAttempts = 0; // Réinitialiser le compteur de reconnexion
        _handleWebSocketMessage(data as String);
      },
      onDone: () {
        debugPrint('[WS] Connection closed (intentional=$_intentionalDisconnect)');
        if (!_canUpdate || _intentionalDisconnect) return;

        // UNE seule tentative de reconnexion
        if (_reconnectAttempts < 1 && _lastToken != null) {
          _reconnectAttempts++;
          state = state.copyWith(status: 'reconnecting');
          Future.delayed(const Duration(seconds: 2), () {
            if (_canUpdate && state.status == 'reconnecting' && _lastToken != null) {
              debugPrint('[WS] Reconnection attempt $_reconnectAttempts');
              connectWebSocket(_lastToken!);
            }
          });
        } else {
          state = state.copyWith(
            status: 'error',
            errorMessage: 'Connection lost',
            isAiTyping: false,
          );
        }
      },
      onError: (e) {
        debugPrint('[WS] Error: $e');
        if (!_canUpdate) return;
        state = state.copyWith(
          status: 'error',
          errorMessage: e.toString(),
          isAiTyping: false,
        );
      },
    );

    state = state.copyWith(status: 'connected');
  }

  /// Reconnexion manuelle (depuis le bouton "Reconnecter").
  void reconnect() {
    if (_lastToken != null) {
      _reconnectAttempts = 0;
      connectWebSocket(_lastToken!);
    }
  }

  // ─── Envoi de message ─────────────────────────────────────────

  void sendMessage(String text) {
    if (text.trim().isEmpty || state.isAiTyping) return;

    // Vérifier que le WebSocket est connecté
    if (_channel == null || state.status != 'connected') {
      debugPrint('[WS] Cannot send: not connected (status=${state.status})');
      // Tenter de reconnecter puis renvoyer
      if (_lastToken != null) {
        _lastUserMessage = text.trim();
        reconnect();
      }
      return;
    }

    _lastUserMessage = text.trim();

    // Ajouter le message utilisateur (optimistic UI)
    final updatedMessages = [
      ...state.messages,
      ChatMessage(role: 'user', content: text.trim()),
    ];
    state = state.copyWith(messages: updatedMessages, isAiTyping: true);

    // Envoyer via WebSocket
    debugPrint('[WS] Sending message: ${text.trim().substring(0, text.trim().length.clamp(0, 50))}...');
    _channel!.sink.add(jsonEncode({'message': text.trim()}));

    // Timer de timeout — 30s sans réponse
    _responseTimer?.cancel();
    _responseTimer = Timer(const Duration(seconds: 30), () {
      if (_canUpdate && state.isAiTyping) {
        debugPrint('[WS] Response timeout after 30s');
        state = state.copyWith(
          isAiTyping: false,
          errorMessage: 'timeout',
        );
      }
    });
  }

  /// Renvoie le dernier message (après un timeout).
  void resendLastMessage() {
    if (_lastUserMessage != null) {
      // Retirer le dernier message user de la liste (il sera re-ajouté par sendMessage)
      final messages = List<ChatMessage>.from(state.messages);
      if (messages.isNotEmpty && messages.last.role == 'user') {
        messages.removeLast();
      }
      state = state.copyWith(messages: messages, isAiTyping: false, errorMessage: null);
      sendMessage(_lastUserMessage!);
    }
  }

  // ─── Handlers WebSocket ───────────────────────────────────────

  void _handleWebSocketMessage(String raw) {
    if (!_canUpdate) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';
      debugPrint('[WS] Received: $type');

      switch (type) {
        case 'stream':
          _cancelResponseTimer();
          _handleStreamChunk(data['text'] as String? ?? '');
        case 'stream_end':
          _handleStreamEnd();
        case 'feedback':
          _handleFeedback(data['data'] as Map<String, dynamic>);
        case 'summary':
          _handleSummary(data['data'] as Map<String, dynamic>);
        case 'error':
          _cancelResponseTimer();
          state = state.copyWith(
            isAiTyping: false,
            errorMessage: data['message'] as String?,
          );
      }
    } catch (e) {
      debugPrint('[WS] Parse error: $e\nRaw: $raw');
    }
  }

  void _handleStreamChunk(String text) {
    if (!_canUpdate) return;
    final messages = List<ChatMessage>.from(state.messages);

    if (messages.isEmpty || messages.last.role != 'assistant' || !messages.last.isStreaming) {
      messages.add(ChatMessage(role: 'assistant', content: text, isStreaming: true));
    } else {
      final last = messages.removeLast();
      messages.add(last.copyWith(content: last.content + text));
    }

    state = state.copyWith(messages: messages, isAiTyping: true);
  }

  void _handleStreamEnd() {
    if (!_canUpdate) return;
    final messages = List<ChatMessage>.from(state.messages);
    if (messages.isNotEmpty && messages.last.isStreaming) {
      final last = messages.removeLast();
      messages.add(last.copyWith(isStreaming: false));
    }
    state = state.copyWith(messages: messages);
  }

  void _handleFeedback(Map<String, dynamic> feedbackData) {
    if (!_canUpdate) return;
    _cancelResponseTimer();

    final messages = List<ChatMessage>.from(state.messages);
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
      errorMessage: null,
    );
  }

  void _handleSummary(Map<String, dynamic> summaryData) {
    if (!_canUpdate) return;
    _cancelResponseTimer();
    state = state.copyWith(
      summary: summaryData,
      status: 'completed',
      isAiTyping: false,
    );
    ref.invalidate(interviewHistoryProvider);
    ref.invalidate(interviewUsageProvider);
  }

  // ─── Cleanup ──────────────────────────────────────────────────

  void _cancelResponseTimer() {
    _responseTimer?.cancel();
    _responseTimer = null;
  }

  void _closeChannel() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _cancelResponseTimer();
  }

  void disconnect() {
    debugPrint('[WS] Disconnect (intentional)');
    _active = false;
    _intentionalDisconnect = true;
    _closeChannel();
  }

  void reset() {
    disconnect();
    _active = true;
    _intentionalDisconnect = false;
    _reconnectAttempts = 0;
    _lastToken = null;
    _lastUserMessage = null;
    state = const InterviewChatState();
  }
}
