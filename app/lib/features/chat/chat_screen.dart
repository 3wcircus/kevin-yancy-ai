import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../auth/auth_provider.dart';
import 'chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _audioPlayer = AudioPlayer();
  String? _playingMessageId;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _focusNode.requestFocus();
    await ref.read(conversationProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _playAudio(String url, String messageId) async {
    try {
      if (_playingMessageId == messageId) {
        await _audioPlayer.stop();
        setState(() => _playingMessageId = null);
        return;
      }
      setState(() => _playingMessageId = messageId);
      await _audioPlayer.play(UrlSource(url));
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playingMessageId = null);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play audio.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final convState = ref.watch(conversationProvider);
    final voiceEnabled = ref.watch(voiceEnabledProvider);
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
    final isAdminOrDelegate =
        ref.watch(isAdminOrDelegateProvider).valueOrNull ?? false;
    final user = ref.watch(currentUserProvider);

    // Show error snack
    ref.listen(conversationProvider, (prev, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
        ref.read(conversationProvider.notifier).clearError();
      }
      if ((next.messages.length) > (prev?.messages.length ?? 0)) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.amber,
              ),
              child: const Center(
                child: Text(
                  'K',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(AppStrings.appName),
          ],
        ),
        actions: [
          // Voice toggle
          Tooltip(
            message: voiceEnabled
                ? 'Voice responses on'
                : 'Voice responses off',
            child: IconButton(
              icon: Icon(
                voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: voiceEnabled ? AppTheme.amberLight : Colors.white54,
              ),
              onPressed: () {
                ref.read(voiceEnabledProvider.notifier).state = !voiceEnabled;
              },
            ),
          ),
          // New conversation
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New conversation',
            onPressed: () {
              ref.read(conversationProvider.notifier).startNewConversation();
            },
          ),
          // Admin shortcut
          if (isAdminOrDelegate)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Admin',
              onPressed: () => context.push('/admin'),
            ),
          // Profile / Sign out
          PopupMenuButton<String>(
            icon: const Icon(Icons.person_outline),
            onSelected: (value) async {
              if (value == 'profile') {
                context.push('/profile');
              } else if (value == 'signout') {
                await ref.read(loginProvider.notifier).signOut();
                if (mounted) context.go('/login');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, size: 18),
                    const SizedBox(width: 10),
                    Text(user?.email ?? 'Profile'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Sign out', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: convState.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: convState.messages.length,
                    itemBuilder: (context, index) {
                      final message = convState.messages[index];
                      return _MessageBubble(
                        key: ValueKey(message.id),
                        message: message,
                        isPlaying: _playingMessageId == message.id,
                        onPlayAudio: message.audioUrl != null
                            ? () => _playAudio(message.audioUrl!, message.id)
                            : null,
                      ).animate().fadeIn(duration: 300.ms).slideY(
                            begin: 0.15,
                            end: 0,
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          );
                    },
                  ),
          ),

          // Input area
          _ChatInputBar(
            controller: _textController,
            focusNode: _focusNode,
            isLoading: convState.isLoading,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.navyDeep.withOpacity(0.08),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: AppTheme.navyDeep.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Start a conversation with Kevin',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.navyDeep.withOpacity(0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Ask him about a memory, a story, his advice,\nor just say hello.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: const [
                _StarterChip(text: 'Tell me a story'),
                _StarterChip(text: 'What\'s your best advice?'),
                _StarterChip(text: 'What do you miss most?'),
                _StarterChip(text: 'Tell me about your childhood'),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}

// ---------------------------------------------------------------------------
// Starter chip
// ---------------------------------------------------------------------------
class _StarterChip extends ConsumerWidget {
  const _StarterChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        ref.read(conversationProvider.notifier).sendMessage(text);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.navyDeep.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.navyDeep,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message Bubble
// ---------------------------------------------------------------------------
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isPlaying,
    this.onPlayAudio,
  });

  final ChatMessage message;
  final bool isPlaying;
  final VoidCallback? onPlayAudio;

  bool get isKevin => message.role == MessageRole.kevin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isKevin ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isKevin) ...[
            // Kevin avatar
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.amber,
              ),
              child: const Center(
                child: Text(
                  'K',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isKevin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                // Bubble
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isKevin ? AppTheme.bubbleKevin : AppTheme.bubbleUser,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                          Radius.circular(isKevin ? 4 : 18),
                      bottomRight:
                          Radius.circular(isKevin ? 18 : 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: message.isLoading
                      ? _LoadingDots()
                      : MarkdownBody(
                          data: message.text,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: isKevin
                                  ? AppTheme.bubbleKevinText
                                  : AppTheme.bubbleUserText,
                              fontSize: 15,
                              height: 1.55,
                            ),
                            strong: TextStyle(
                              color: isKevin
                                  ? AppTheme.amberPale
                                  : Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            em: TextStyle(
                              color: isKevin
                                  ? AppTheme.bubbleKevinText
                                  : AppTheme.bubbleUserText,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 4),

                // Timestamp + audio play button row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat.jm().format(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textLight,
                      ),
                    ),
                    if (onPlayAudio != null && isKevin) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onPlayAudio,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.navyDeep.withOpacity(0.08),
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            size: 18,
                            color: AppTheme.navyDeep,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated loading dots
// ---------------------------------------------------------------------------
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = ((_controller.value - i * 0.15) % 1.0).clamp(0.0, 1.0);
            final opacity = (offset < 0.5
                ? offset / 0.5
                : 1.0 - (offset - 0.5) / 0.5);
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.amberLight.withOpacity(0.3 + opacity * 0.7),
              ),
            );
          }),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Chat Input Bar
// ---------------------------------------------------------------------------
class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontSize: 15, height: 1.4),
              decoration: InputDecoration(
                hintText: AppStrings.chatHint,
                filled: true,
                fillColor: AppTheme.cream,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: AppTheme.navyDeep,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLoading ? AppTheme.navyDeep.withOpacity(0.4) : AppTheme.amber,
              boxShadow: isLoading
                  ? []
                  : [
                      BoxShadow(
                        color: AppTheme.amber.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: isLoading ? null : onSend,
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
