import 'package:Dogonomics/backend/authentication.dart';
import 'package:Dogonomics/backend/stockHandler.dart';
import 'package:Dogonomics/pages/marketIndicPage.dart';
import 'package:Dogonomics/pages/newsFeedPage.dart';
import 'package:Dogonomics/pages/portfolioAnalysisPage.dart';
import 'package:Dogonomics/pages/socialSentimentPage.dart';
import 'package:Dogonomics/pages/dogonomicsAdvicePage.dart';
import 'package:Dogonomics/pages/transactionHistoryPage.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:Dogonomics/utils/stockDialog.dart';
import 'package:Dogonomics/utils/tickerData.dart';
import 'package:Dogonomics/widgets/infoTooltip.dart';

import 'package:flutter/material.dart';


class StockViewTab extends StatefulWidget {
  final List<Stock> stocks;
  final String userId;
  
  const StockViewTab({
    super.key, 
    required this.stocks,
    required this.userId,
  });

  @override
  State<StockViewTab> createState() => _StockViewTabState();
}

class _StockViewTabState extends State<StockViewTab> {
  late List<Stock> _stocks;
  bool _isLoading = false;
  double _totalPortfolioValue = 0.0;
  double _totalDayChange = 0.0;


  @override
  void initState() {
    super.initState();
    _stocks = List.from(widget.stocks);
    _listenToPortfolioChanges();
    _calculatePortfolioMetrics();
  }

  void _calculatePortfolioMetrics() {
    _totalPortfolioValue = _stocks.fold(0.0, (sum, stock) => sum + (stock.price * stock.quantity));

    _totalDayChange = _stocks.fold(0.0, (sum, stock) {
      double dollarChange = stock.change;   
      double previousPrice = stock.price / (1 + (stock.change / 100));
      dollarChange = (stock.price - previousPrice) * stock.quantity;
    return sum + dollarChange;
    });
  }

  void _listenToPortfolioChanges() {
    PortfolioService.listenToPortfolio(widget.userId).listen((stocks) {
      if (mounted) {
        setState(() {
          _stocks = stocks;
          _calculatePortfolioMetrics();
        });
      }
    });
  }
    Future<void> _updateStockQuantity(Stock stock, int newQuantity) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await PortfolioService.updateStockQuantity(
        widget.userId, 
        stock.symbol, 
        newQuantity
      );
      
      if (!success) {
        _showErrorMessage('Failed to update stock quantity');
      }
    } catch (e) {
      _showErrorMessage('Error updating quantity: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildPortfolioSummaryCard() {
    bool isPositiveChange = _totalDayChange >= 0;
    double changePercentage = _totalPortfolioValue > 0 ? (_totalDayChange / _totalPortfolioValue) * 100 : 0;
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PortfolioAnalysisPage(
              portfolio: _stocks,
              totalValue: _totalPortfolioValue,
              totalDayChange: _totalDayChange,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ACCENT_COLOR_BRIGHT, ACCENT_COLOR],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: ACCENT_SHADOW,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Portfolio Value',
                  style: TextStyle(
                    color: MAINGREY,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'View Analysis',
                      style: TextStyle(
                        color: MAINGREY,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: MAINGREY,
                      size: 12,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '\$${_totalPortfolioValue.toStringAsFixed(2)}',
              style: TextStyle(
                color: MAINGREY,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isPositiveChange ? Icons.trending_up : Icons.trending_down,
                  color: isPositiveChange ? const Color.fromARGB(255, 32, 83, 33) : Colors.redAccent,
                  size: 20,
                ),
                SizedBox(width: 4),
                Text(
                  '${isPositiveChange ? '+' : ''}\$${_totalDayChange.toStringAsFixed(2)} (${changePercentage.toStringAsFixed(2)}%)',
                  style: TextStyle(
                    color: isPositiveChange ? const Color.fromARGB(255, 32, 83, 33) : Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsRow() {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: 16.0,
      runSpacing: 16.0,
      children: [
        _buildQuickActionButton(
          icon: Icons.history,
          label: 'History',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TransactionHistoryPage(
                  portfolio: _stocks,
                ),
              ),
            );
          },
        ),
        _buildQuickActionButton(
          icon: Icons.article_outlined,
          label: 'Financial News',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NewsFeedPage(),
              ),
            );
          },
        ),
        _buildQuickActionButton(
          icon: Icons.chat_bubble_outline,
          label: 'Social Sentiment',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SocialSentimentPage(),
              ),
            );
          },
        ),
        _buildQuickActionButton(
          icon: Icons.analytics_outlined,
          label: 'Portfolio Analysis',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PortfolioAnalysisPage(
                  portfolio: _stocks,
                  totalValue: _totalPortfolioValue,
                  totalDayChange: _totalDayChange,
                ),
              ),
            );
          },
        ),
        // Special Sniff Advice CTA button
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showAdviceSymbolPicker(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF4CAF50).withOpacity(0.45),
                ),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.psychology_outlined, size: 22, color: Color(0xFF66BB6A)),
                  SizedBox(height: 4),
                  Text(
                    'AI Advice',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF66BB6A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: MAINGREY,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: ACCENT_COLOR),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketIndicatorsCard() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarketIndicatorsPage(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MAINGREY,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ACCENT_COLOR, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ACCENT_COLOR,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.trending_up,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Market Indicators',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'View S&P 500, Dow Jones, NASDAQ & more',
                    style: TextStyle(
                      color: MAINGREY_LIGHT,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.amber.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDogAssistantBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.smart_toy_outlined, size: 24, color: Color(0xFF66BB6A)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Copilot is active',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF66BB6A),
                  ),
                ),
                Text(
                  _stocks.isEmpty
                      ? 'No tracked symbols yet. Add a stock to begin.'
                      : 'Tracking ${_stocks.length} stock${_stocks.length == 1 ? '' : 's'}. Select one for deeper analysis.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationalTipsSection() {
    return InfoCard(
      title: 'Portfolio Guidance',
      summary: 'Diversification is key. Spread risk so one bad day does not impact the full portfolio.',
      detailedInfo: 'A well-diversified portfolio typically includes:\n\n'
          '• Stocks from various sectors (tech, healthcare, finance, etc.)\n'
          '• Bonds for stability\n'
          '• Commodities as an inflation hedge\n'
          '• International exposure\n\n'
          'This helps reduce risk because different assets often perform differently under the same market conditions.',
      icon: Icons.auto_awesome,
      iconColor: ACCENT_GREEN_LIGHT,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDogAssistantBanner(),
        const SizedBox(height: 12),
        _buildPortfolioSummaryCard(),
        const SizedBox(height: 16),

        _buildQuickActionsRow(),
        const SizedBox(height: 16),

        // Educational Tips Section
        _buildEducationalTipsSection(),
        const SizedBox(height: 16),

        if (_stocks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF313131)),
            ),
            child: Column(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 56, color: TEXT_SECONDARY),
                const SizedBox(height: 16),
                const Text(
                  'No portfolio holdings yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first stock to start tracking performance and analysis.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._stocks.map((stock) => Column(
            children: [
              StockCard(
                stock: stock,
                onRemove: () => _removeStock(stock),
                onQuantityChanged: (newQuantity) => _updateStockQuantity(stock, newQuantity),
              ),
              SizedBox(height: 12),
            ],
          )),

        // Market Indicators Card
        _buildMarketIndicatorsCard(),
        SizedBox(height: 24),

      // ADD STOCK
        Container(child: Align(child: 
          FloatingActionButton.extended(
            backgroundColor: MAINGREY,
            foregroundColor: MAINGREY_LIGHT,
            onPressed: _isLoading ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddStockPage(
                      onStockSelected: (symbol, quantity) async {
                        await addStockToPortfolio(symbol, quantity);
                      },
                    ),
                  ),
                );
              },
            icon: Icon(Icons.add),
            label: Text('ADD ETF'),
          ),),)
      ],
    );
  }

  Future<void> addStockToPortfolio(String symbol, int quantity) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newStock = await fetchSingleStock(
        symbol: symbol,
        quantity: quantity,
      );

      if (newStock != null) {
        final success = await PortfolioService.addStockToPortfolio(
          widget.userId, 
          newStock
        );
        
        if (!success) {
          _showErrorMessage('Failed to add stock to portfolio');
        }
      }
    } catch (e) {
      _showErrorMessage('Error adding stock: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  Future<void> _removeStock(Stock stock) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await PortfolioService.removeStockFromPortfolio(
        widget.userId, 
        stock
      );
      
      if (!success) {
        _showErrorMessage('Failed to remove stock from portfolio');
      }
    } catch (e) {
      _showErrorMessage('Error removing stock: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showAdviceSymbolPicker() {
    if (_stocks.isNotEmpty) {
      // If user has stocks, show picker from their portfolio
      showDialog(
        context: context,
        builder: (context) => SimpleDialog(
          backgroundColor: STOCK_CARD,
          title: const Text(
            'Choose a stock for AI Advice',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          children: [
            ..._stocks.map((stock) => SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DogonomicsAdvicePage(symbol: stock.symbol),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      stock.symbol,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        stock.name,
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
      );
    } else {
      // Fallback: go directly to a default symbol
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DogonomicsAdvicePage(symbol: 'AAPL'),
        ),
      );
    }
  }
}

