import 'package:flutter/material.dart';
// Placeholder for Market Indicators Page
class MarketIndicatorsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Market Indicators'),
        backgroundColor: Colors.blue[700],
      ),
      body: Center(
        child: Text(
          'Market Indicators Page\n\nThis will show:\n• S&P 500\n• Dow Jones\n• NASDAQ\n• VIX\n• Sector Performance',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}