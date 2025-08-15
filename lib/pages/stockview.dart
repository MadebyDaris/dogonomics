import 'dart:io';

import 'package:dogonomics_frontend/backend/authentication.dart';
import 'package:dogonomics_frontend/backend/stockHandler.dart';
import 'package:dogonomics_frontend/pages/marketIndicPage.dart';
import 'package:dogonomics_frontend/utils/constant.dart';
import 'package:dogonomics_frontend/utils/logoManager.dart';
import 'package:dogonomics_frontend/utils/stockDialog.dart';
import 'package:dogonomics_frontend/utils/tickerData.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class StockViewTab extends StatefulWidget {
  final List<UserStock> stocks;
  final String userId; // Add userId parameter

  const StockViewTab({
    super.key, 
    required this.stocks,
    required this.userId,
  });

  @override
  State<StockViewTab> createState() => _StockViewTabState();
}

class _StockViewTabState extends State<StockViewTab> {
  late List<UserStock> _stocks;
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
    _totalPortfolioValue = _stocks.fold(0.0, (sum, stock) => sum + (stock.stockData.currentPrice * stock.quantity));
    _totalDayChange = _stocks.fold(0.0, (sum, stock) => sum + (stock.stockData.changePercentage * stock.quantity));
  }

  void _listenToPortfolioChanges() {
    // Listen to real-time portfolio changes
    PortfolioService.listenToPortfolio(widget.userId).listen((stocks) {
      if (mounted) {
        setState(() {
          _stocks = stocks;
        });
      }
    });
  }

  Widget _buildPortfolioSummaryCard() {
  bool isPositiveChange = _totalDayChange >= 0;
  double changePercentage = _totalPortfolioValue > 0 ? (_totalDayChange / _totalPortfolioValue) * 100 : 0;
  
  return Container(
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.blue.shade700, Colors.blue.shade900],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.blue.withOpacity(0.3),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Portfolio Value',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '\$${_totalPortfolioValue.toStringAsFixed(2)}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Icon(
              isPositiveChange ? Icons.trending_up : Icons.trending_down,
              color: isPositiveChange ? Colors.greenAccent : Colors.redAccent,
              size: 20,
            ),
            SizedBox(width: 4),
            Text(
              '${isPositiveChange ? '+' : ''}\$${_totalDayChange.toStringAsFixed(2)} (${changePercentage.toStringAsFixed(2)}%)',
              style: TextStyle(
                color: isPositiveChange ? Colors.greenAccent : Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildQuickActionsRow() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _buildQuickActionButton(
        icon: Icons.analytics,
        label: 'Analytics',
        onPressed: () {
          // Navigate to analytics page
          print('Navigate to Analytics');
        },
      ),
      _buildQuickActionButton(
        icon: Icons.notifications,
        label: 'Alerts',
        onPressed: () {
          // Navigate to alerts page
          print('Navigate to Alerts');
        },
      ),
      _buildQuickActionButton(
        icon: Icons.account_balance_wallet,
        label: 'Wallet',
        onPressed: () {
          // Navigate to wallet page
          print('Navigate to Wallet');
        },
      ),
      _buildQuickActionButton(
        icon: Icons.history,
        label: 'History',
        onPressed: () {
          // Navigate to transaction history
          print('Navigate to History');
        },
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
            Icon(icon, size: 24, color: Colors.blue),
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
          border: Border.all(color: Colors.amber.shade700, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Portfolio Summary Card
        _buildPortfolioSummaryCard(),
        SizedBox(height: 16),
        
        // Quick Actions Row
        _buildQuickActionsRow(),
        SizedBox(height: 16),

        // Stock Cards
        ..._stocks.map((stock) => Column(
          children: [
            buildStockCard(stock, onRemove: () => _removeStock(stock)),
            SizedBox(height: 12),
          ],
        )),

        // Market Indicators Card
        _buildMarketIndicatorsCard(),
        SizedBox(height: 12),

        SizedBox(height: 12),
        Container(child: Align(child: 
          FloatingActionButton.extended(
            backgroundColor: MAINGREY,
            foregroundColor: MAINGREY_LIGHT,
            onPressed: _isLoading ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddStockPage(
                      onStockSelected: (symbol) async {
                        await addStockToPortfolio(symbol);
                      },
                    ),
                  ),
                );
              },
            icon: Icon(Icons.add),
            label: Text('ETF STOCKS'),
          ),),)
      ],
    );
  }

  Future<void> addStockToPortfolio(String symbol) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newStock = await fetchSingleStock(
        symbol: symbol,
        name: 'New Stock',
        code: 'ETF',
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
  Future<void> _removeStock(UserStock stock) async {
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
      SnackBar(content: Text(message)),
    );
  }
}

