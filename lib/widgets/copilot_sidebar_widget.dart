import 'package:flutter/material.dart';
import '../backend/gemini_service.dart';
import '../backend/providers.dart';
import '../utils/constant.dart';

/// Copilot sidebar - right-side help and guidance panel
/// Provides context-aware tips, concept explanations, and stock insights
/// Hidden on small screens, visible on tablet and larger
class CopilotSidebarWidget extends StatefulWidget {
  final String currentRoute;
  final String? currentSymbol;
  final MetricExplanationProvider explanationProvider;
  final bool isVisible;

  const CopilotSidebarWidget({
    Key? key,
    required this.currentRoute,
    this.currentSymbol,
    required this.explanationProvider,
    this.isVisible = true,
  }) : super(key: key);

  @override
  State<CopilotSidebarWidget> createState() => _CopilotSidebarWidgetState();
}

class _CopilotSidebarWidgetState extends State<CopilotSidebarWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedConcept;
  String? _conceptExplanation;
  bool _isLoadingExplanation = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConceptExplanation(String concept) async {
    setState(() {
      _isLoadingExplanation = true;
      _selectedConcept = concept;
    });

    try {
      // Check cache first
      final cached = widget.explanationProvider.getExplanation(concept);
      if (cached != null) {
        setState(() {
          _conceptExplanation = cached;
          _isLoadingExplanation = false;
        });
        return;
      }

      // Fetch from Gemini
      final gemini = GeminiService();
      final explanation = await gemini.explainMetric(concept);
      
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

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return SizedBox.shrink();

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          left: BorderSide(
            color: const Color(0xFF313131),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF313131),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2E7D32),
                  ),
                  child: Center(
                    child: Text('🐕', style: TextStyle(fontSize: 14)),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Copilot',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Guided Help',
                        style: TextStyle(
                          fontSize: 10,
                          color: const Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab bar
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF66BB6A),
            labelColor: const Color(0xFF66BB6A),
            unselectedLabelColor: const Color(0xFF757575),
            tabs: [
              Tab(text: 'Tips', icon: Icon(Icons.lightbulb_outline, size: 16)),
              Tab(text: 'Learn', icon: Icon(Icons.school_outlined, size: 16)),
              Tab(text: 'Stocks', icon: Icon(Icons.trending_up, size: 16)),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTipsTab(),
                _buildLearnTab(),
                _buildStocksTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tips for this page',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          ..._getContextualTips().map((tip) => _buildTipCard(tip)),
        ],
      ),
    );
  }

  Widget _buildTipCard(String tip) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(10),
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
          Text(
            '💡',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFFB0B0B0),
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
        // Search field
        Padding(
          padding: EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search concepts...',
              hintStyle: TextStyle(
                color: const Color(0xFF757575),
                fontSize: 12,
              ),
              prefixIcon: Icon(Icons.search, size: 16, color: const Color(0xFF757575)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: const Color(0xFF424242)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: const Color(0xFF262626),
            ),
            style: TextStyle(color: Colors.white, fontSize: 12),
            onChanged: (value) => setState(() {}),
          ),
        ),

        // Concept list or selected concept explanation
        Expanded(
          child: _selectedConcept != null
              ? _buildConceptExplanation()
              : _buildConceptList(),
        ),
      ],
    );
  }

  Widget _buildConceptList() {
    final concepts = [
      'P/E Ratio',
      'Market Cap',
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
        : concepts
            .where((c) => c.toLowerCase().contains(_searchController.text.toLowerCase()))
            .toList();

    return ListView.builder(
      padding: EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final concept = filtered[index];
        return GestureDetector(
          onTap: () => _loadConceptExplanation(concept),
          child: Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Icon(Icons.arrow_forward, size: 14, color: const Color(0xFF757575)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConceptExplanation() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => setState(() => _selectedConcept = null),
            child: Row(
              children: [
                Icon(Icons.arrow_back, size: 16, color: const Color(0xFF66BB6A)),
                SizedBox(width: 4),
                Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF66BB6A),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          
          // Concept title
          Text(
            _selectedConcept!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          
          // Explanation
          if (_isLoadingExplanation)
            Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF66BB6A),
              ),
            )
          else if (_conceptExplanation != null)
            Text(
              _conceptExplanation!,
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFFB0B0B0),
                height: 1.6,
              ),
            )
          else
            Text(
              'Unable to load explanation',
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFFF44336),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStocksTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.currentSymbol != null) ...[
            Text(
              'Tips for ${widget.currentSymbol}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            _buildTipCard('Check the P/E ratio to see if the stock is fairly valued.'),
            _buildTipCard('Look at the dividend yield if you\'re seeking income.'),
            _buildTipCard('Review recent news sentiment to understand market mood.'),
            _buildTipCard('Compare against industry peers using relative metrics.'),
          ] else ...[
            Text(
              'Stock Analysis Tips',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12),
            _buildTipCard('Start by reviewing company fundamentals (revenue, earnings).'),
            _buildTipCard('Check the sentiment analysis to gauge investor mood.'),
            _buildTipCard('Compare the stock to similar companies in the sector.'),
            _buildTipCard('Review recent news and announcements.'),
            _buildTipCard('Look at price charts and technical trends.'),
          ],
        ],
      ),
    );
  }

  List<String> _getContextualTips() {
    switch (widget.currentRoute) {
      case '/stock_details':
        return [
          'Click "Explain This" (ℹ️) icons to learn about metrics.',
          'Check the sentiment tab for AI analysis of recent news.',
          'Compare this stock to industry averages.',
          'Ask Doggy Bot about this stock for deeper insights.',
        ];
      case '/frontpage':
        return [
          'Check the ticker tape at the top for latest sentiment.',
          'Scroll through the Doggo Sentiment widget for market overview.',
          'Use the search bar to find stocks quickly.',
          'Tap on trending stocks to view details.',
        ];
      case '/news_feed':
        return [
          'Read the AI-generated summaries before full articles.',
          'The sentiment gauge shows AI confidence levels.',
          'Tap "Read Full Article" for complete coverage.',
          'Use search to find news about specific companies.',
        ];
      case '/wallet':
        return [
          'Track your portfolio performance over time.',
          'Diversify your holdings across sectors.',
          'Review transaction history to learn from trades.',
          'Set reminders for portfolio rebalancing.',
        ];
      default:
        return [
          'Use Copilot (me!) to get help on any page.',
          'Click metric info icons (ℹ️) to learn financial terms.',
          'Ask about stocks or market concepts in Doggy Bot chat.',
          'Check the ticker tape for real-time market sentiment.',
        ];
    }
  }
}

/// Sidebar integration helper for screens
class SidebarScaffold extends StatelessWidget {
  final Widget body;
  final String currentRoute;
  final String? currentSymbol;
  final RouteProvider routeProvider;
  final MetricExplanationProvider explanationProvider;
  final bool showSidebar;

  const SidebarScaffold({
    Key? key,
    required this.body,
    required this.currentRoute,
    this.currentSymbol,
    required this.routeProvider,
    required this.explanationProvider,
    this.showSidebar = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Row(
      children: [
        Expanded(child: body),
        if (isTablet && showSidebar)
          CopilotSidebarWidget(
            currentRoute: currentRoute,
            currentSymbol: currentSymbol,
            explanationProvider: explanationProvider,
            isVisible: true,
          ),
      ],
    );
  }
}
