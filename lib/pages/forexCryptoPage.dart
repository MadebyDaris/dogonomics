import 'package:Dogonomics/backend/dogonomicsApi.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:Dogonomics/utils/walletData.dart';
import 'package:Dogonomics/widgets/addAssetDialog.dart';
import 'package:Dogonomics/pages/socialSentimentPage.dart';
import 'package:Dogonomics/widgets/doggo_inline_insight.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class ForexCryptoPage extends StatefulWidget {
  final ValueChanged<String>? onSymbolContextChanged;

  const ForexCryptoPage({Key? key, this.onSymbolContextChanged}) : super(key: key);

  @override
  _ForexCryptoPageState createState() => _ForexCryptoPageState();
}

class _ForexCryptoPageState extends State<ForexCryptoPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Forex state
  ForexRatesResponse? _forexRates;
  List<NewsItem> _forexNews = [];
  bool _isLoadingForex = false;
  String? _forexError;

  // Crypto state
  CryptoQuotesResponse? _cryptoQuotes;
  List<NewsItem> _cryptoNews = [];
  bool _isLoadingCrypto = false;
  String? _cryptoError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0 && _forexRates == null) {
          _loadForexData();
        } else if (_tabController.index == 1 && _cryptoQuotes == null) {
          _loadCryptoData();
        }
      }
    });
    _loadForexData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadForexData() async {
    setState(() {
      _isLoadingForex = true;
      _forexError = null;
    });

    // Load rates and news independently so one failure doesn't block the other
    ForexRatesResponse? rates;
    List<NewsItem> news = [];
    String? ratesError;

    try {
      rates = await DogonomicsAPI.fetchForexRates();
    } catch (e) {
      ratesError = e.toString();
    }

    try {
      news = await DogonomicsAPI.fetchForexNews(limit: 15);
    } catch (_) {
      // News failure is non-fatal
    }

    if (mounted) {
      setState(() {
        _forexRates = rates;
        _forexNews = news;
        _isLoadingForex = false;
        // Only show error if rates failed (the primary data)
        _forexError = rates == null ? ratesError : null;
      });
    }
  }

  Future<void> _loadCryptoData() async {
    setState(() {
      _isLoadingCrypto = true;
      _cryptoError = null;
    });

    // Load quotes and news independently
    CryptoQuotesResponse? quotes;
    List<NewsItem> news = [];
    String? quotesError;

    try {
      quotes = await DogonomicsAPI.fetchCryptoQuotes();
    } catch (e) {
      quotesError = e.toString();
    }

    try {
      news = await DogonomicsAPI.fetchCryptoNews(limit: 15);
    } catch (_) {
      // News failure is non-fatal
    }

    if (mounted) {
      setState(() {
        _cryptoQuotes = quotes;
        _cryptoNews = news;
        _isLoadingCrypto = false;
        _cryptoError = quotes == null ? quotesError : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: CARD_BACKGROUND,
          child: TabBar(
            controller: _tabController,
            indicatorColor: ACCENT_GREEN_BRIGHT,
            labelColor: TEXT_PRIMARY,
            unselectedLabelColor: TEXT_SECONDARY,
            tabs: const [
              Tab(text: 'Forex', icon: Icon(Icons.currency_exchange, size: 18)),
              Tab(text: 'Crypto', icon: Icon(Icons.currency_bitcoin, size: 18)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildForexTab(),
              _buildCryptoTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FOREX TAB
  // ═══════════════════════════════════════════════════════════

  Widget _buildForexTab() {
    if (_isLoadingForex) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.currency_exchange, size: 40, color: ACCENT_GREEN_BRIGHT),
            SizedBox(height: 12),
            CircularProgressIndicator(color: ACCENT_GREEN_BRIGHT),
            SizedBox(height: 12),
            Text('Loading forex rates...', style: TextStyle(color: TEXT_SECONDARY, fontSize: 13)),
          ],
        ),
      );
    }
    if (_forexError != null) {
      return _buildErrorWidget(_forexError!, _loadForexData);
    }

    return RefreshIndicator(
      onRefresh: _loadForexData,
      color: ACCENT_GREEN_BRIGHT,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DoggoInlineInsightWidget(
            context: 'Forex',
            prompt: 'Give a 2-sentence breakdown of major forex movements today.',
          ),
          _buildSectionHeader('Exchange Rates (USD)', Icons.currency_exchange),
          const SizedBox(height: 8),
          if (_forexRates != null) _buildForexRatesGrid(),
          const SizedBox(height: 24),
          _buildSectionHeader('Forex News', Icons.newspaper),
          const SizedBox(height: 8),
          ..._forexNews.map((n) => _buildNewsCard(n)),
          if (_forexNews.isEmpty)
            _buildEmptyState('No forex news available'),
        ],
      ),
    );
  }

  Widget _buildForexRatesGrid() {
    final rates = _forexRates!.rates;
    if (rates.isEmpty) return _buildEmptyState('No rate data available');

    // Sort by symbol
    final sorted = List<ForexPair>.from(rates)
      ..sort((a, b) => a.symbol.compareTo(b.symbol));

    return Container(
      decoration: cardDecoration(),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CARD_BACKGROUND_ELEVATED,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text('Pair', style: TextStyle(color: TEXT_SECONDARY, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Currency', style: TextStyle(color: TEXT_SECONDARY, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Rate', style: TextStyle(color: TEXT_SECONDARY, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          const Divider(color: DIVIDER_COLOR, height: 1),
          ...sorted.map((pair) => _buildForexRateRow(pair)),
        ],
      ),
    );
  }

  Widget _buildForexRateRow(ForexPair pair) {
    final flag = _getCurrencyFlag(pair.symbol);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DIVIDER_COLOR, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  pair.pair,
                  style: const TextStyle(color: TEXT_PRIMARY, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _getCurrencyName(pair.symbol),
              style: const TextStyle(color: TEXT_SECONDARY, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              pair.rate < 10
                  ? pair.rate.toStringAsFixed(4)
                  : pair.rate.toStringAsFixed(2),
              style: const TextStyle(color: TEXT_PRIMARY, fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CRYPTO TAB
  // ═══════════════════════════════════════════════════════════

  Widget _buildCryptoTab() {
    if (_isLoadingCrypto) {
      return const Center(
        child: CircularProgressIndicator(color: ACCENT_GREEN_BRIGHT),
      );
    }
    if (_cryptoError != null) {
      return _buildErrorWidget(_cryptoError!, _loadCryptoData);
    }

    return RefreshIndicator(
      onRefresh: _loadCryptoData,
      color: ACCENT_GREEN_BRIGHT,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const DoggoInlineInsightWidget(
            context: 'Crypto',
            prompt: 'Give a 2-sentence breakdown of major cryptocurrency movements today.',
          ),
          _buildSectionHeader('Popular Cryptocurrencies', Icons.currency_bitcoin),
          const SizedBox(height: 8),
          if (_cryptoQuotes != null) ..._buildCryptoQuoteCards(),
          const SizedBox(height: 24),
          _buildSectionHeader('Crypto News', Icons.newspaper),
          const SizedBox(height: 8),
          ..._cryptoNews.map((n) => _buildNewsCard(n)),
          if (_cryptoNews.isEmpty)
            _buildEmptyState('No crypto news available'),
        ],
      ),
    );
  }

  List<Widget> _buildCryptoQuoteCards() {
    final quotes = _cryptoQuotes!.quotes;
    if (quotes.isEmpty) return [_buildEmptyState('No crypto data available')];

    return quotes.map((q) => _buildCryptoCard(q)).toList();
  }

  Widget _buildCryptoCard(CryptoQuote quote) {
    final isPositive = quote.change >= 0;
    final changeColor = isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE;
    final changeIcon = isPositive ? Icons.trending_up : Icons.trending_down;
    final symbol = quote.displaySymbol.split('/').first;

    return GestureDetector(
      onTap: () => widget.onSymbolContextChanged?.call(symbol),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Column(
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _getCryptoColor(quote.name).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _getCryptoIcon(quote.name),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name & pair
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.name,
                        style: const TextStyle(color: TEXT_PRIMARY, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        quote.displaySymbol,
                        style: const TextStyle(color: TEXT_SECONDARY, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Price & change
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCryptoPrice(quote.price),
                      style: const TextStyle(color: TEXT_PRIMARY, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(changeIcon, color: changeColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${isPositive ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%',
                          style: TextStyle(color: changeColor, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Action buttons row
            Row(
              children: [
                Expanded(
                  child: _buildCryptoActionButton(
                    icon: Icons.shopping_cart_outlined,
                    label: 'Buy',
                    color: COLOR_POSITIVE,
                    onTap: () => _buyCrypto(quote),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCryptoActionButton(
                    icon: Icons.psychology_outlined,
                    label: 'Sentiment',
                    color: ACCENT_GREEN_LIGHT,
                    onTap: () => _viewCryptoSentiment(quote),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  void _buyCrypto(CryptoQuote quote) {
    // Extract simple symbol from display (e.g., "BTC/USDT" -> "BTC")
    final symbol = quote.displaySymbol.split('/').first;
    showAddAssetDialog(
      context: context,
      assetType: AssetType.crypto,
      symbol: symbol,
      name: quote.name,
      currentPrice: quote.price,
    );
  }

  void _viewCryptoSentiment(CryptoQuote quote) {
    final symbol = quote.displaySymbol.split('/').first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SocialSentimentPage(initialSymbol: symbol),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // NEWS CARD (shared)
  // ═══════════════════════════════════════════════════════════

  Widget _buildNewsCard(NewsItem news) {
    return GestureDetector(
      onTap: () => _openUrl(news.url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  news.imageUrl!,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 72,
                    height: 72,
                    color: CARD_BACKGROUND_ELEVATED,
                    child: const Icon(Icons.image_not_supported, color: TEXT_DISABLED, size: 24),
                  ),
                ),
              ),
            if (news.imageUrl != null && news.imageUrl!.isNotEmpty)
              const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.title,
                    style: const TextStyle(color: TEXT_PRIMARY, fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (news.description.isNotEmpty)
                    Text(
                      news.description,
                      style: const TextStyle(color: TEXT_SECONDARY, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        news.source,
                        style: const TextStyle(color: ACCENT_GREEN_LIGHT, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        _formatTimeAgo(news.publishedAt),
                        style: const TextStyle(color: TEXT_DISABLED, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ═══════════════════════════════════════════════════════════

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: ACCENT_GREEN_LIGHT, size: 20),
        const SizedBox(width: 8),
        Text(title, style: HEADING_SMALL),
      ],
    );
  }

  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: COLOR_NEGATIVE, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load data',
              style: HEADING_SMALL,
            ),
            const SizedBox(height: 8),
            Text(error, style: CAPTION_TEXT, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ACCENT_GREEN,
                foregroundColor: TEXT_PRIMARY,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 34, color: TEXT_SECONDARY),
            const SizedBox(height: 8),
            Text(message, style: BODY_SECONDARY),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatTimeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  String _formatCryptoPrice(double price) {
    if (price >= 1000) {
      return '\$${NumberFormat('#,##0.00').format(price)}';
    } else if (price >= 1) {
      return '\$${price.toStringAsFixed(2)}';
    } else {
      return '\$${price.toStringAsFixed(6)}';
    }
  }

  String _getCurrencyFlag(String code) {
    return code;
  }

  String _getCurrencyName(String code) {
    const names = {
      'EUR': 'Euro', 'GBP': 'British Pound', 'JPY': 'Japanese Yen',
      'AUD': 'Australian Dollar', 'CAD': 'Canadian Dollar',
      'CHF': 'Swiss Franc', 'CNY': 'Chinese Yuan', 'NZD': 'New Zealand Dollar',
      'SEK': 'Swedish Krona', 'NOK': 'Norwegian Krone', 'MXN': 'Mexican Peso',
      'SGD': 'Singapore Dollar', 'HKD': 'Hong Kong Dollar',
      'KRW': 'South Korean Won', 'INR': 'Indian Rupee',
      'BRL': 'Brazilian Real', 'ZAR': 'South African Rand',
      'TRY': 'Turkish Lira', 'RUB': 'Russian Ruble', 'PLN': 'Polish Zloty',
    };
    return names[code] ?? code;
  }

  String _getCryptoIcon(String name) {
    const icons = {
      'Bitcoin': 'BTC',
      'Ethereum': 'ETH',
      'BNB': 'BNB',
      'Solana': 'SOL',
      'XRP': 'XRP',
      'Dogecoin': 'DOGE',
      'Cardano': 'ADA',
      'Polkadot': 'DOT',
      'Avalanche': 'AVAX',
      'Polygon': 'MATIC',
    };
    return icons[name] ?? 'CRYPTO';
  }

  Color _getCryptoColor(String name) {
    const colors = {
      'Bitcoin': Color(0xFFF7931A),
      'Ethereum': Color(0xFF627EEA),
      'BNB': Color(0xFFF3BA2F),
      'Solana': Color(0xFF9945FF),
      'XRP': Color(0xFF00AAE4),
      'Dogecoin': Color(0xFFC2A633),
      'Cardano': Color(0xFF0033AD),
      'Polkadot': Color(0xFFE6007A),
      'Avalanche': Color(0xFFE84142),
      'Polygon': Color(0xFF8247E5),
    };
    return colors[name] ?? CHART_PRIMARY;
  }
}
