import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:Dogonomics/utils/tickerData.dart';
import 'package:intl/intl.dart';

class TransactionHistoryPage extends StatefulWidget {
  final List<Stock> portfolio;

  const TransactionHistoryPage({
    Key? key,
    required this.portfolio,
  }) : super(key: key);

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  String _filterType = 'All'; // All, Buy, Sell
  List<TransactionData> _transactions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final txns = snap.docs.map((doc) {
        final d = doc.data();
        return TransactionData(
          symbol: d['symbol'] ?? '',
          name: d['name'] ?? d['symbol'] ?? '',
          type: d['type'] ?? 'Buy',
          assetType: d['assetType'] ?? 'stock',
          quantity: (d['quantity'] ?? 0).toDouble(),
          price: (d['pricePerUnit'] ?? 0).toDouble(),
          total: (d['total'] ?? 0).toDouble(),
          date: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _transactions = txns;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<TransactionData> get _filteredTransactions {
    if (_filterType == 'All') return _transactions;
    return _transactions.where((t) => t.type == _filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: APP_BACKGROUND,
      appBar: AppBar(
        backgroundColor: CARD_BACKGROUND,
        title: Text('Transaction History', style: HEADING_MEDIUM),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterOptions(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCards(),
          _buildFilterChips(),
          Expanded(child: _buildTransactionList()),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final buyTotal = _transactions
        .where((t) => t.type == 'Buy')
        .fold(0.0, (sum, t) => sum + t.total);
    final sellTotal = _transactions
        .where((t) => t.type == 'Sell')
        .fold(0.0, (sum, t) => sum + t.total);
    final currentValue = widget.portfolio.fold(
      0.0,
      (sum, stock) => sum + (stock.price * stock.quantity),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Invested',
              '\$${buyTotal.toStringAsFixed(2)}',
              Icons.account_balance_wallet,
              COLOR_INFO,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              'Current Value',
              '\$${currentValue.toStringAsFixed(2)}',
              Icons.trending_up,
              COLOR_POSITIVE,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: CAPTION_TEXT),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: HEADING_MEDIUM.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ['All', 'Buy', 'Sell'].map((filter) {
          final isSelected = _filterType == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _filterType = filter);
                }
              },
              backgroundColor: CARD_BACKGROUND,
              selectedColor: ACCENT_GREEN,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : TEXT_SECONDARY,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: ACCENT_GREEN),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: COLOR_NEGATIVE),
            const SizedBox(height: 16),
            Text('Failed to load transactions', style: HEADING_MEDIUM.copyWith(color: TEXT_SECONDARY)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadTransactions,
              child: const Text('Retry', style: TextStyle(color: ACCENT_GREEN)),
            ),
          ],
        ),
      );
    }

    final transactions = _filteredTransactions;

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: TEXT_DISABLED),
            const SizedBox(height: 16),
            Text(
              _filterType == 'All' ? 'No transactions yet' : 'No $_filterType transactions',
              style: HEADING_MEDIUM.copyWith(color: TEXT_SECONDARY),
            ),
            const SizedBox(height: 8),
            Text(
              'Start adding stocks to see your history',
              style: BODY_SECONDARY,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      color: ACCENT_GREEN,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return _buildTransactionCard(transaction);
        },
      ),
    );
  }

  Widget _buildTransactionCard(TransactionData transaction) {
    final isBuy = transaction.type == 'Buy';
    final typeColor = isBuy ? COLOR_POSITIVE : COLOR_NEGATIVE;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isBuy ? Icons.add_shopping_cart : Icons.sell,
            color: typeColor,
          ),
        ),
        title: Text(
          transaction.symbol,
          style: HEADING_SMALL,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${transaction.quantity % 1 == 0 ? transaction.quantity.toInt().toString() : transaction.quantity.toStringAsFixed(2)} ${transaction.assetType == 'stock' ? 'shares' : 'units'} @ \$${transaction.price.toStringAsFixed(2)}',
              style: BODY_SECONDARY,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  DateFormat('MMM dd, yyyy • hh:mm a').format(transaction.date),
                  style: CAPTION_TEXT,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    transaction.assetType.toUpperCase(),
                    style: CAPTION_TEXT.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                transaction.type,
                style: CAPTION_TEXT.copyWith(
                  color: typeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '\$${transaction.total.toStringAsFixed(2)}',
              style: BODY_PRIMARY.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: CARD_BACKGROUND,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Transactions', style: HEADING_MEDIUM),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.all_inclusive, color: TEXT_PRIMARY),
              title: Text('All Transactions', style: BODY_PRIMARY),
              onTap: () {
                setState(() => _filterType = 'All');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.add_shopping_cart, color: COLOR_POSITIVE),
              title: Text('Purchases Only', style: BODY_PRIMARY),
              onTap: () {
                setState(() => _filterType = 'Buy');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.sell, color: COLOR_NEGATIVE),
              title: Text('Sales Only', style: BODY_PRIMARY),
              onTap: () {
                setState(() => _filterType = 'Sell');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTotalInvested() {
    return _transactions
        .where((t) => t.type == 'Buy')
        .fold(0.0, (sum, t) => sum + t.total);
  }

  double _calculateCurrentValue() {
    return widget.portfolio.fold(
      0.0,
      (sum, stock) => sum + (stock.price * stock.quantity),
    );
  }
}

class TransactionData {
  final String symbol;
  final String name;
  final String type; // 'Buy' or 'Sell'
  final String assetType; // 'stock', 'bond', 'commodity'
  final double quantity;
  final double price;
  final double total;
  final DateTime date;

  TransactionData({
    required this.symbol,
    this.name = '',
    required this.type,
    this.assetType = 'stock',
    required this.quantity,
    required this.price,
    required this.total,
    required this.date,
  });
}
