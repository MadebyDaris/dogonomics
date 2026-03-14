import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../backend/gemini_service.dart';
import '../backend/models.dart';
import '../backend/providers.dart';
import '../widgets/chat_widgets.dart';

/// Global chat page for market questions
/// Accessible from main navigation, allows users to ask Dogonomics (LLM) questions
/// Maintains chat history in memory (ChatProvider)
class ChatPage extends StatefulWidget {
  final ChatProvider chatProvider;
  final String? contextSymbol; // Optional stock symbol for context
  final double? contextPrice; // Optional current price
  final String? contextSentiment; // Optional sentiment data

  const ChatPage({
    Key? key,
    required this.chatProvider,
    this.contextSymbol,
    this.contextPrice,
    this.contextSentiment,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late ScrollController _scrollController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initializeGemini();
  }

  Future<void> _initializeGemini() async {
    final gemini = GeminiService();
    // Ensure Gemini is initialized (check for API key in .env)
    try {
      // Gemini initialization would happen in main.dart
      // This is just a safety check
      _isInitialized = true;
      if (mounted) setState(() {});
    } catch (e) {
      widget.chatProvider.setError('Failed to initialize LLM service: $e');
    }
  }

  Future<void> _handleSendMessage(String userMessage) async {
    if (!_isInitialized) {
      widget.chatProvider.setError('LLM service not ready');
      return;
    }

    // Add user message to chat history
    widget.chatProvider.addUserMessage(
      userMessage,
      context: widget.contextSymbol,
    );

    // Scroll to bottom
    _scrollToBottom();

    // Set loading state and generate response
    widget.chatProvider.setLoading(true);
    widget.chatProvider.setError(null);

    try {
      final gemini = GeminiService();
      final response = await gemini.generateChatResponse(
        userMessage,
        stockSymbol: widget.contextSymbol,
        currentPrice: widget.contextPrice,
        sentimentData: widget.contextSentiment,
      );

      if (mounted) {
        widget.chatProvider.addAssistantMessage(response);
        widget.chatProvider.setLoading(false);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        widget.chatProvider.setError('Error: ${e.toString()}');
        widget.chatProvider.setLoading(false);
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E7D32),
              ),
              child: Center(
                child: Text('🐕', style: TextStyle(fontSize: 18)),
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dogonomics Chat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (widget.contextSymbol != null)
                  Text(
                    'About ${widget.contextSymbol}',
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: const Color(0xFF66BB6A)),
            onPressed: () => widget.chatProvider.clearHistory(),
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages list
          Expanded(
            child: _buildChatList(),
          ),

          // Error message (if any)
          if (widget.chatProvider.error != null)
            Container(
              padding: EdgeInsets.all(12),
              color: const Color(0xFFF44336).withOpacity(0.15),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: const Color(0xFFF44336),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.chatProvider.error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFFF44336),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Input field
          ChatInputFieldWidget(
            onSend: _handleSendMessage,
            isLoading: widget.chatProvider.isLoading,
            isEnabled: _isInitialized,
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    final messages = widget.chatProvider.messages;

    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: 12),
      itemCount: messages.length + (widget.chatProvider.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < messages.length) {
          return ChatMessageBubble(message: messages[index]);
        } else {
          // Show typing indicator while loading
          return TypingIndicatorWidget();
        }
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E7D32).withOpacity(0.2),
              ),
              child: Center(
                child: Text('🐕', style: TextStyle(fontSize: 32)),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Welcome to Dogonomics Chat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Ask questions about the market,\nstocks, or financial concepts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFFB0B0B0),
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            _buildSuggestedPrompt(
              'What is the P/E ratio and why does it matter?',
            ),
            SizedBox(height: 8),
            _buildSuggestedPrompt(
              'Explain the difference between stocks and bonds.',
            ),
            SizedBox(height: 8),
            _buildSuggestedPrompt(
              'How do I analyze a company before investing?',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedPrompt(String prompt) {
    return GestureDetector(
      onTap: () => _handleSendMessage(prompt),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF424242),
            width: 0.5,
          ),
        ),
        child: Text(
          prompt,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xFFB0B0B0),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
