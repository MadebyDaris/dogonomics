import 'package:flutter/material.dart';
import 'dart:async';
import '../backend/models.dart';
import '../utils/constant.dart';

/// Chat message bubble widget
/// Displays either user message (right-aligned, blue) or assistant message (left-aligned, gray)
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;

  const ChatMessageBubble({
    Key? key,
    required this.message,
    this.showAvatar = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == 'user';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Assistant avatar
          if (!isUser && showAvatar) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E7D32),
              ),
              child: Center(
                child: Text(
                  '🐕',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            SizedBox(width: 8),
          ],

          // Message bubble
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF2E7D32).withOpacity(0.8)
                    : const Color(0xFF303030),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUser
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF424242),
                  width: 0.5,
                ),
              ),
              child: SelectableText(
                message.text,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),
          ),

          // User avatar
          if (isUser && showAvatar) ...[
            SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2196F3),
              ),
              child: Center(
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chat input field widget
/// Text input with send button and loading indicator
class ChatInputFieldWidget extends StatefulWidget {
  final Function(String)? onSend;
  final bool isLoading;
  final bool isEnabled;

  const ChatInputFieldWidget({
    Key? key,
    this.onSend,
    this.isLoading = false,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  State<ChatInputFieldWidget> createState() => _ChatInputFieldWidgetState();
}

class _ChatInputFieldWidgetState extends State<ChatInputFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.isLoading && widget.isEnabled) {
      widget.onSend?.call(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF313131),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.isEnabled && !widget.isLoading,
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'Ask about the market...',
                hintStyle: TextStyle(
                  color: const Color(0xFF757575),
                  fontSize: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: const Color(0xFF424242),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: const Color(0xFF2E7D32),
                    width: 1,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: const Color(0xFF262626),
              ),
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          SizedBox(width: 8),
          // Send button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isLoading || !widget.isEnabled
                  ? const Color(0xFF757575).withOpacity(0.3)
                  : const Color(0xFF2E7D32),
            ),
            child: IconButton(
              onPressed: _handleSend,
              icon: widget.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.send, color: Colors.white, size: 18),
              constraints: BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

/// Typing indicator animation
class TypingIndicatorWidget extends StatefulWidget {
  const TypingIndicatorWidget({Key? key}) : super(key: key);

  @override
  State<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<TypingIndicatorWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      )..repeat(reverse: true),
    );

    // Stagger animations
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _controllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => ScaleTransition(
            scale: Tween<double>(begin: 1, end: 1.3).animate(
              CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut),
            ),
            child: Container(
              width: 8,
              height: 8,
              margin: EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF66BB6A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
