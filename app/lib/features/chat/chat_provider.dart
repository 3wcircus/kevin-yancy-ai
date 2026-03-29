import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../auth/auth_provider.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------
enum MessageRole { user, kevin }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.audioUrl,
    required this.timestamp,
    this.isLoading = false,
  });

  final String id;
  final MessageRole role;
  final String text;
  final String? audioUrl;
  final DateTime timestamp;
  final bool isLoading;

  ChatMessage copyWith({
    String? text,
    String? audioUrl,
    bool? isLoading,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      audioUrl: audioUrl ?? this.audioUrl,
      timestamp: timestamp,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ConversationState {
  const ConversationState({
    this.messages = const [],
    this.conversationId = '',
    this.isLoading = false,
    this.errorMessage,
    this.voiceEnabled = false,
  });

  final List<ChatMessage> messages;
  final String conversationId;
  final bool isLoading;
  final String? errorMessage;
  final bool voiceEnabled;

  ConversationState copyWith({
    List<ChatMessage>? messages,
    String? conversationId,
    bool? isLoading,
    String? errorMessage,
    bool? voiceEnabled,
  }) {
    return ConversationState(
      messages: messages ?? this.messages,
      conversationId: conversationId ?? this.conversationId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
    );
  }
}

// ---------------------------------------------------------------------------
// SharedPreferences provider
// ---------------------------------------------------------------------------
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

// ---------------------------------------------------------------------------
// Voice preference provider
// ---------------------------------------------------------------------------
final voiceEnabledProvider = StateProvider<bool>((ref) => false);

// ---------------------------------------------------------------------------
// Conversation Notifier
// ---------------------------------------------------------------------------
class ConversationNotifier extends StateNotifier<ConversationState> {
  ConversationNotifier(this._ref) : super(const ConversationState()) {
    _initConversation();
  }

  final Ref _ref;
  static const _uuid = Uuid();

  void _initConversation() {
    final conversationId = _uuid.v4();
    state = state.copyWith(conversationId: conversationId);
  }

  void startNewConversation() {
    _initConversation();
    state = state.copyWith(
      messages: [],
      isLoading: false,
      errorMessage: null,
      conversationId: _uuid.v4(),
    );
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (state.isLoading) return;

    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    final voiceEnabled = _ref.read(voiceEnabledProvider);

    // Add user message
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      text: text.trim(),
      timestamp: DateTime.now(),
    );

    // Add loading placeholder for Kevin's response
    final loadingMessage = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.kevin,
      text: '',
      timestamp: DateTime.now(),
      isLoading: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage, loadingMessage],
      isLoading: true,
      errorMessage: null,
    );

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        FunctionNames.chat,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'message': text.trim(),
        'conversationId': state.conversationId,
        'wantAudio': voiceEnabled,
      });

      final responseText = result.data['text'] as String? ?? '';
      final audioUrl = result.data['audioUrl'] as String?;

      // Replace loading message with real response
      final updatedMessages = state.messages
          .map((m) => m.isLoading
              ? m.copyWith(
                  text: responseText,
                  audioUrl: audioUrl,
                  isLoading: false,
                )
              : m)
          .toList();

      state = state.copyWith(
        messages: updatedMessages,
        isLoading: false,
      );
    } on FirebaseFunctionsException catch (e) {
      final errorMessages = state.messages
          .where((m) => !m.isLoading)
          .toList();

      state = state.copyWith(
        messages: errorMessages,
        isLoading: false,
        errorMessage: e.message ?? 'Something went wrong. Please try again.',
      );
    } catch (e) {
      final errorMessages = state.messages
          .where((m) => !m.isLoading)
          .toList();

      state = state.copyWith(
        messages: errorMessages,
        isLoading: false,
        errorMessage: 'Connection error. Please check your internet and try again.',
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final conversationProvider =
    StateNotifierProvider<ConversationNotifier, ConversationState>((ref) {
  return ConversationNotifier(ref);
});
