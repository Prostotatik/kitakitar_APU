import 'package:flutter/material.dart';
import 'package:kitakitar_mobile/models/ai_scan_model.dart';
import 'package:kitakitar_mobile/services/chat_service.dart';

class RecyclingChatSheet extends StatefulWidget {
  final List<DetectedMaterial> materials;
  final String? preparationTip;

  const RecyclingChatSheet({
    super.key,
    required this.materials,
    this.preparationTip,
  });

  @override
  State<RecyclingChatSheet> createState() => _RecyclingChatSheetState();
}

class _RecyclingChatSheetState extends State<RecyclingChatSheet> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatService.startSession(widget.materials, widget.preparationTip);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _controller.clear();
    setState(() => _isSending = true);
    _scrollToBottom();

    await _chatService.sendMessage(text);

    if (mounted) {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.eco, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Recycling Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _chatService.messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: _chatService.messages.length +
                          (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _chatService.messages.length && _isSending) {
                          return _buildTypingIndicator();
                        }
                        return _buildBubble(_chatService.messages[index]);
                      },
                    ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Ask about recycling...',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: const Color(0xFF4CAF50),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _isSending ? null : _send,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final suggestions = [
      'What should I do next?',
      'How do I prepare this for recycling?',
      'Tell me about KitaKitar',
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Ask me anything about recycling!',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () {
                    _controller.text = s;
                    _send();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4CAF50),
                    side: BorderSide(color: Colors.green.shade200),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  child: Text(s, style: const TextStyle(fontSize: 13)),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: msg.isUser ? const Color(0xFF4CAF50) : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.isUser ? Colors.white : Colors.black87,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: SizedBox(
          width: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (i) {
              return _DotAnimation(delay: i * 200);
            }),
          ),
        ),
      ),
    );
  }
}

class _DotAnimation extends StatefulWidget {
  final int delay;
  const _DotAnimation({required this.delay});

  @override
  State<_DotAnimation> createState() => _DotAnimationState();
}

class _DotAnimationState extends State<_DotAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey.shade400.withOpacity(0.4 + _animation.value * 0.6),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
