/// SmartDiet AI - Chat Screen
///
/// AI Nutritionist chat with 30-day diet context, streaming responses,
/// Markdown rendering, dynamic suggestion chips, and CFS RAG.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:smart_diet_ai/core/theme/clay_theme.dart';
import 'package:smart_diet_ai/features/chat/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  final ChatService _chatService = ChatService();

  String _dietContext = '';
  List<String> _suggestions = [];
  bool _isLoadingSuggestions = true;
  bool _isStreaming = false;
  bool _isSearchingRag = false;
  StreamSubscription<String>? _streamSub;

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      content: "Hello! I'm your AI nutritionist. Ask me anything about "
          'your diet, nutrition goals, or specific foods.\n\n'
          'I have access to your dietary records and can give '
          'personalised advice.',
      role: _Role.assistant,
    ));
    _initContext();
  }

  Future<void> _initContext() async {
    // Load diet context and generate suggestions in parallel
    final contextFuture = _chatService.buildDietContext();
    _dietContext = await contextFuture;
    final suggestions =
        await _chatService.generateSuggestions(_dietContext);
    if (mounted) {
      setState(() {
        _suggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Send message ─────────────────────────────────────────

  Future<void> _sendMessage([String? override]) async {
    final text = (override ?? _messageController.text).trim();
    if (text.isEmpty || _isStreaming) return;

    _messageController.clear();
    setState(() {
      _messages.add(_ChatMessage(content: text, role: _Role.user));
      _suggestions = []; // hide chips after first message
      _isStreaming = true;
    });
    _scrollToBottom();

    // --- CFS RAG check ---
    String? cfsContext;
    final foodQuery = _chatService.detectFoodQuery(text);
    if (foodQuery != null) {
      setState(() => _isSearchingRag = true);
      cfsContext = await _chatService.searchCfsFood(foodQuery);
      if (mounted) setState(() => _isSearchingRag = false);
    }

    // --- Build message history for API ---
    final history = _messages
        .map((m) => {'role': m.role.name, 'content': m.content})
        .toList();

    // Add empty assistant message that will be filled by streaming
    final assistantMsg = _ChatMessage(content: '', role: _Role.assistant);
    setState(() => _messages.add(assistantMsg));
    _scrollToBottom();

    try {
      final stream = _chatService.streamChat(
        messages: history,
        dietContext: _dietContext,
        cfsContext: cfsContext,
      );

      _streamSub = stream.listen(
        (token) {
          if (!mounted) return;
          setState(() {
            assistantMsg.content += token;
          });
          _scrollToBottom();
        },
        onError: (Object e) {
          if (!mounted) return;
          setState(() {
            assistantMsg.content = 'Sorry, something went wrong. Please try again.';
            assistantMsg.isError = true;
            _isStreaming = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _isStreaming = false);
        },
      );
    } catch (e) {
      setState(() {
        assistantMsg.content = 'Sorry, something went wrong. Please try again.';
        assistantMsg.isError = true;
        _isStreaming = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  _buildMessageBubble(_messages[index]),
            ),
          ),
          // Search indicator
          if (_isSearchingRag)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ClayColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Searching food database...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          // Streaming indicator
          if (_isStreaming && !_isSearchingRag)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ClayColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Thinking...',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          // Suggestion chips
          _buildSuggestionArea(),
          // Input
          _buildInputField(),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? ClayColors.darkSurfaceCard : ClayColors.surfaceCard,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? ClayColors.darkShadowDark : ClayColors.shadowDark,
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: ClayColors.primary,
            child: const Icon(Icons.smart_toy, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Nutritionist',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Powered by Gemini + CFS RAG',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Message bubble ───────────────────────────────────────

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.role == _Role.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: ClayColors.primary,
              child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? ClayColors.primary
                    : message.isError
                        ? ClayColors.error.withValues(alpha: 0.15)
                        : isDark
                            ? ClayColors.darkSurfaceCard
                            : ClayColors.surfaceCard,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft:
                      isUser ? null : const Radius.circular(6),
                  bottomRight:
                      isUser ? const Radius.circular(6) : null,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? ClayColors.darkShadowDark
                        : ClayColors.shadowDark.withValues(alpha: 0.4),
                    offset: const Offset(3, 3),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: isDark
                        ? ClayColors.darkShadowLight.withValues(alpha: 0.2)
                        : ClayColors.shadowLight.withValues(alpha: 0.7),
                    offset: const Offset(-2, -2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: const TextStyle(color: Colors.white),
                    )
                  : message.isError
                      ? Text(
                          message.content,
                          style: TextStyle(color: ClayColors.error),
                        )
                      : message.content.isEmpty
                          ? const _ThinkingDots()
                          : MarkdownBody(
                          data: message.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: isDark ? Colors.grey[200] : null,
                              fontSize: 14,
                              height: 1.5,
                            ),
                            listBullet: TextStyle(
                              color: isDark ? Colors.grey[200] : null,
                            ),
                            strong: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : null,
                            ),
                            code: TextStyle(
                              backgroundColor: isDark
                                  ? Colors.black26
                                  : Colors.grey[200],
                              fontSize: 13,
                            ),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: ClayColors.primary,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ── Suggestion chips ─────────────────────────────────────

  Widget _buildSuggestionArea() {
    // Only show before user has sent a message
    final userSent = _messages.any((m) => m.role == _Role.user);
    if (userSent) return const SizedBox.shrink();

    if (_isLoadingSuggestions) {
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ClayColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading suggestions...',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _suggestions
            .map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _sendMessage(s),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ── Input field ──────────────────────────────────────────

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Ask about nutrition...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              mini: true,
              onPressed: _isStreaming ? null : () => _sendMessage(),
              child: _isStreaming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Models ──────────────────────────────────────────────────

enum _Role { user, assistant }

class _ChatMessage {
  String content;
  final _Role role;
  bool isError;

  _ChatMessage({
    required this.content,
    required this.role,
    this.isError = false,
  });
}

// ── Thinking dots animation ──────────────────────────────────

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Animation<double>> _dots;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _dots = List.generate(3, (i) {
      final start = i * 0.2;
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.3, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.3)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30,
        ),
        TweenSequenceItem(
          tween: ConstantTween(0.3),
          weight: 40,
        ),
      ]).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, (start + 0.6).clamp(0.0, 1.0)),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Thinking',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(width: 2),
        ...List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _dots[i],
            builder: (context, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Opacity(
                opacity: _dots[i].value,
                child: const Text(
                  '.',
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.0,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
