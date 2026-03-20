import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../backend/gemini_service.dart';
import '../backend/providers.dart';

/// Doggo sidebar - right-side help and guidance panel.
/// Provides context-aware tips, concept explanations, and integrated Doggo chat.
class DoggoSidebarWidget extends StatefulWidget {
  final String currentRoute;
  final String? currentSymbol;
  final Map<String, dynamic> contextData;
  final MetricExplanationProvider explanationProvider;
  final bool isVisible;
  final VoidCallback? onClose;

  const DoggoSidebarWidget({
    Key? key,
    required this.currentRoute,
    this.currentSymbol,
    this.contextData = const {},
    required this.explanationProvider,
    this.isVisible = true,
    this.onClose,
  }) : super(key: key);

  @override
  State<DoggoSidebarWidget> createState() => _DoggoSidebarWidgetState();
}

class _DoggoSidebarWidgetState extends State<DoggoSidebarWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  String? _selectedConcept;
  String? _conceptExplanation;
  bool _isLoadingExplanation = false;
  bool _isLoadingChat = false;
  final List<_DoggoMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _loadConceptExplanation(String concept) async {
    setState(() {
      _isLoadingExplanation = true;
      _selectedConcept = concept;
    });

    try {
      final cached = widget.explanationProvider.getExplanation(concept);
      if (cached != null) {
        setState(() {
          _conceptExplanation = cached;
          _isLoadingExplanation = false;
        });
        return;
      }

      final explanation = await GeminiService().explainMetric(concept);

      if (mounted) {
        widget.explanationProvider.setExplanation(concept, explanation);
        setState(() {
          _conceptExplanation = explanation;
          _isLoadingExplanation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _conceptExplanation = 'Failed to load explanation: $e';
          _isLoadingExplanation = false;
        });
      }
    }
  }

  Future<void> _sendDoggoMessage([String? quickPrompt]) async {
    final text = (quickPrompt ?? _chatController.text).trim();
    if (text.isEmpty || _isLoadingChat) return;

    setState(() {
      _messages.add(_DoggoMessage.user(text));
      _isLoadingChat = true;
    });

    _chatController.clear();

    final sentimentContext = widget.contextData['sentiment']?.toString();
    final rawPrice = widget.contextData['price'];
    final currentPrice = rawPrice is num ? rawPrice.toDouble() : null;

    try {
      final response = await GeminiService().generateChatResponse(
        text,
        stockSymbol: widget.currentSymbol,
        currentPrice: currentPrice,
        sentimentData: sentimentContext,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_DoggoMessage.assistant(response));
        _isLoadingChat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _DoggoMessage.assistant(
            'Unable to generate a response right now. Please try again.',
            isError: true,
          ),
        );
        _isLoadingChat = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(
          left: BorderSide(
            color: Color(0xFF313131),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFF313131),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF2E7D32),
                  ),
                  child: const Icon(Icons.smart_toy_outlined, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Doggo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.currentSymbol != null
                            ? 'Context: ${widget.currentSymbol}'
                            : 'Context-aware assistance',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 16, color: Color(0xFF9E9E9E)),
                    tooltip: 'Close Doggo',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                  ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF66BB6A),
            labelColor: const Color(0xFF66BB6A),
            unselectedLabelColor: const Color(0xFF757575),
            tabs: const [
              Tab(text: 'Tips', icon: Icon(Icons.lightbulb_outline, size: 16)),
              Tab(text: 'Learn', icon: Icon(Icons.school_outlined, size: 16)),
              Tab(text: 'Doggo', icon: Icon(Icons.chat_bubble_outline, size: 16)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTipsTab(),
                _buildLearnTab(),
                _buildDoggoTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tips for this page',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ..._getContextualTips().map(_buildTipCard),
        ],
      ),
    );
  }

  Widget _buildTipCard(String tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF424242),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, size: 14, color: Color(0xFF66BB6A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFB0B0B0),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearnTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search concepts...',
              hintStyle: const TextStyle(
                color: Color(0xFF757575),
                fontSize: 12,
              ),
              prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF757575)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF424242)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: const Color(0xFF262626),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            onChanged: (value) => setState(() {}),
          ),
        ),
        Expanded(
          child: _selectedConcept != null ? _buildConceptExplanation() : _buildConceptList(),
        ),
      ],
    );
  }

  Widget _buildConceptList() {
    final concepts = [
      'P/E Ratio',
      'Market Cap',
      'MACD Crossover',
      'RSI',
      'Bollinger Bands',
      'Dividend Yield',
      'EPS',
      'Beta',
      'Book Value',
      'ROE',
      'Debt-to-Equity',
      'Price-to-Book',
      'Free Cash Flow',
    ];

    final filtered = _searchController.text.isEmpty
        ? concepts
        : concepts.where((c) => c.toLowerCase().contains(_searchController.text.toLowerCase())).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final concept = filtered[index];
        return GestureDetector(
          onTap: () => _loadConceptExplanation(concept),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF424242),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  concept,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF757575)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConceptExplanation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedConcept = null),
            child: const Row(
              children: [
                Icon(Icons.arrow_back, size: 16, color: Color(0xFF66BB6A)),
                SizedBox(width: 4),
                Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF66BB6A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedConcept!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingExplanation)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF66BB6A),
              ),
            )
          else if (_conceptExplanation != null)
            Text(
              _conceptExplanation!,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFB0B0B0),
                height: 1.6,
              ),
            )
          else
            const Text(
              'Unable to load explanation',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFF44336),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDoggoTab() {
    return Column(
      children: [
        _buildQuickPrompts(),
        Expanded(
          child: _messages.isEmpty
              ? _buildDoggoEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                ),
        ),
        if (_isLoadingChat)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF66BB6A)),
            ),
          ),
        _buildChatComposer(),
      ],
    );
  }

  Widget _buildQuickPrompts() {
    final prompts = [
      widget.currentSymbol != null
          ? 'What moved ${widget.currentSymbol} today?'
          : 'What are the key market drivers today?',
      'Explain the sentiment trend in plain language',
      'What should I monitor next?',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: prompts
            .map(
              (prompt) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(
                    prompt,
                    style: const TextStyle(fontSize: 10, color: Color(0xFFB0B0B0)),
                  ),
                  backgroundColor: const Color(0xFF262626),
                  side: const BorderSide(color: Color(0xFF424242), width: 0.5),
                  onPressed: () => _sendDoggoMessage(prompt),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDoggoEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Ask Doggo about the current screen',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            widget.currentSymbol != null
                ? 'Current context includes symbol ${widget.currentSymbol}.'
                : 'Context includes the active route and available page metrics.',
            style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF424242), width: 0.5),
            ),
            child: const Text(
              'Try: Why did it spike today?\nDoggo automatically uses active symbol and route context.',
              style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_DoggoMessage message) {
    final isUser = message.role == _DoggoRole.user;
    final bg = isUser ? const Color(0xFF1B5E20) : const Color(0xFF262626);
    final textColor = isUser ? Colors.white : const Color(0xFFE0E0E0);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: message.isError ? const Color(0xFFF44336) : const Color(0xFF424242),
            width: 0.5,
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(fontSize: 11, color: textColor, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildChatComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF313131), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendDoggoMessage(),
              decoration: InputDecoration(
                hintText: 'Ask Doggo...',
                hintStyle: const TextStyle(color: Color(0xFF757575), fontSize: 12),
                filled: true,
                fillColor: const Color(0xFF262626),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF424242)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF424242)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isLoadingChat ? null : _sendDoggoMessage,
            icon: const Icon(Icons.send_rounded),
            color: const Color(0xFF66BB6A),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }

  List<String> _getContextualTips() {
    switch (widget.currentRoute) {
      case '/stock_details':
        return [
          'Use Explain This tooltips to understand complex metrics.',
          'Check the sentiment tab for AI analysis of recent news.',
          'Compare this stock to industry averages.',
          'Ask Doggo for context-aware insights before taking action.',
        ];
      case '/frontpage':
        return [
          'Review the ticker tape at the top for latest sentiment signals.',
          'Use the market sentiment widget for high-level direction.',
          'Use the search bar to find stocks quickly.',
          'Tap on trending stocks to view details.',
        ];
      case '/news_feed':
        return [
          'Read AI-generated summaries before full articles.',
          'The sentiment gauge shows confidence levels.',
          'Open full articles for complete coverage.',
          'Use search to find news for specific companies.',
        ];
      case '/wallet':
        return [
          'Track your portfolio performance over time.',
          'Diversify holdings across sectors and asset classes.',
          'Review transaction history to improve strategy.',
          'Set reminders for periodic rebalancing.',
        ];
      default:
        return [
          'Use Doggo for page-specific market guidance.',
          'Use Explain This icons to clarify financial terms and metrics.',
          'Ask about stocks or market concepts in Doggo chat.',
          'Check the ticker tape for market sentiment.',
        ];
    }
  }
}

enum _DoggoRole { user, assistant }

class _DoggoMessage {
  final _DoggoRole role;
  final String text;
  final bool isError;

  const _DoggoMessage({
    required this.role,
    required this.text,
    this.isError = false,
  });

  factory _DoggoMessage.user(String text) {
    return _DoggoMessage(role: _DoggoRole.user, text: text);
  }

  factory _DoggoMessage.assistant(String text, {bool isError = false}) {
    return _DoggoMessage(role: _DoggoRole.assistant, text: text, isError: isError);
  }
}

/// Sidebar integration helper for screens.
/// Desktop: collapsible right panel.
/// Mobile: right-side drawer overlay.
class SidebarScaffold extends StatefulWidget {
  final Widget body;
  final String currentRoute;
  final String? currentSymbol;
  final RouteProvider routeProvider;
  final MetricExplanationProvider explanationProvider;
  final Map<String, dynamic> contextData;
  final bool showSidebar;

  const SidebarScaffold({
    Key? key,
    required this.body,
    required this.currentRoute,
    this.currentSymbol,
    required this.routeProvider,
    required this.explanationProvider,
    this.contextData = const {},
    this.showSidebar = true,
  }) : super(key: key);

  @override
  State<SidebarScaffold> createState() => _SidebarScaffoldState();
}

class _SidebarScaffoldState extends State<SidebarScaffold> {
  bool _isOpen = false;
  
  // Floating FAB position
  double _fabX = 20;
  double _fabY = 60; // offset from top or bottom
  bool _positionInitialized = false;

  @override
  void initState() {
    super.initState();
    widget.routeProvider.setRoute(
      widget.currentRoute,
      symbol: widget.currentSymbol,
      data: widget.contextData,
    );
  }

  @override
  void didUpdateWidget(covariant SidebarScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRoute != widget.currentRoute ||
        oldWidget.currentSymbol != widget.currentSymbol ||
        oldWidget.contextData != widget.contextData) {
      widget.routeProvider.setRoute(
        widget.currentRoute,
        symbol: widget.currentSymbol,
        data: widget.contextData,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    if (!_positionInitialized) {
      _fabX = screenWidth - 70; // 70px from right
      _fabY = screenHeight - 120; // 120px from bottom
      _positionInitialized = true;
    }

    if (!widget.showSidebar) {
      return widget.body;
    }

    // Determine panel width (max 400px or 90% of screen)
    final panelWidth = math.min(400.0, screenWidth * 0.9);

    return Stack(
      children: [
        widget.body,
        
        // Dark backdrop when open
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _isOpen = false),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),
          
        // The side panel itself
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: _isOpen ? 0 : -panelWidth,
          width: panelWidth,
          child: Material(
            color: const Color(0xFF1A1A1A),
            elevation: 16,
            child: SafeArea(
              child: DoggoSidebarWidget(
                currentRoute: widget.currentRoute,
                currentSymbol: widget.currentSymbol,
                contextData: widget.contextData,
                explanationProvider: widget.explanationProvider,
                isVisible: true,
                onClose: () => setState(() => _isOpen = false),
              ),
            ),
          ),
        ),

        // Floating Draggable Doggo Avatar
        if (!_isOpen)
          Positioned(
            left: _fabX,
            top: _fabY,
            child: GestureDetector(
              onPanUpdate: (feedback) {
                setState(() {
                  _fabX += feedback.delta.dx;
                  _fabY += feedback.delta.dy;
                  // Clamp to screen bounds
                  _fabX = math.max(0, math.min(_fabX, screenWidth - 56));
                  _fabY = math.max(0, math.min(_fabY, screenHeight - 56));
                });
              },
              child: FloatingActionButton(
                heroTag: 'Doggo_toggle_${widget.currentRoute}',
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                elevation: 8,
                onPressed: () => setState(() => _isOpen = true),
                tooltip: 'Ask Doggo',
                child: const Icon(Icons.smart_toy_outlined, size: 28),
              ),
            ),
          ),
      ],
    );
  }
}
