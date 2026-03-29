/// SmartDiet AI - Chat Screen
///
/// AI Nutritionist chat with 30-day diet context, streaming responses,
/// Markdown rendering, dynamic suggestion chips, and CFS RAG.
library;

import 'dart:async';
import 'dart:math' as math;

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
  bool _suggestionsExpanded = false;
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

    // --- CFS RAG check (LLM decides if food lookup is needed) ---
    String? cfsContext;
    final foodQuery = await _chatService.detectFoodQuery(text);
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _SuggestionPill(
          label: 'Loading suggestions...',
          icon: Icons.hourglass_top_rounded,
          isLoading: true,
          onTap: null,
        ),
      );
    }

    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Trigger pill
          _SuggestionPill(
            label: 'Suggested Questions',
            icon: _suggestionsExpanded
                ? Icons.close_rounded
                : Icons.auto_awesome_rounded,
            onTap: () {
              setState(() => _suggestionsExpanded = !_suggestionsExpanded);
            },
          ),
          // Expandable question cards
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _suggestionsExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_suggestions.length, (i) {
                        return _SuggestionCard(
                          text: _suggestions[i],
                          index: i,
                          onTap: () {
                            setState(() => _suggestionsExpanded = false);
                            _sendMessage(_suggestions[i]);
                          },
                        );
                      }),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
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

// ── Suggestion pill trigger ──────────────────────────────────

class _SuggestionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback? onTap;

  const _SuggestionPill({
    required this.label,
    required this.icon,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              ClayColors.primary.withValues(alpha: 0.12),
              ClayColors.primary.withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ClayColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ClayColors.primary,
                ),
              )
            else
              Icon(icon, size: 18, color: ClayColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ClayColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Suggestion card with staggered animation ─────────────────

class _SuggestionCard extends StatefulWidget {
  final String text;
  final int index;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.text,
    required this.index,
    required this.onTap,
  });

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
    ));
    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutBack,
    ));

    // Staggered start per index
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rotate hue slightly per card for visual variety
    final hueShift = widget.index * 12.0;
    final baseHsl = HSLColor.fromColor(ClayColors.primary);
    final cardColor = baseHsl
        .withHue((baseHsl.hue + hueShift) % 360)
        .toColor();

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(14),
                splashColor: cardColor.withValues(alpha: 0.15),
                child: Ink(
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cardColor.withValues(alpha: 0.2),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Transform.rotate(
                        angle: (widget.index * math.pi / 6),
                        child: Icon(
                          _questionIcons[
                              widget.index % _questionIcons.length],
                          size: 18,
                          color: cardColor.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                            height: 1.3,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _questionIcons = [
    Icons.restaurant_rounded,
    Icons.analytics_outlined,
    Icons.fitness_center_rounded,
    Icons.local_fire_department_rounded,
  ];
}
