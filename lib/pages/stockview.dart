import 'dart:io';

import 'package:dogonomics_frontend/utils/constant.dart';
import 'package:dogonomics_frontend/utils/logoManager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class StockViewTab extends StatelessWidget {
  final List<Stock> stocks;

  const StockViewTab({super.key, required this.stocks});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        ...stocks.map((stock) => Column(
          children: [
            buildStockCard(stock),
            SizedBox(height: 12),
          ],
        )),
        SizedBox(height: 12),
        Container(child: Align(child: 
          FloatingActionButton.extended(
            backgroundColor: MAINGREY,
            foregroundColor: MAINGREY_LIGHT,
            onPressed: () {
              // Respond to button press
            },
            icon: Icon(Icons.add),
            label: Text('ETF STOCKS'),
          ),),)
      ],
    );
  }
}

class StockCard extends StatefulWidget  {
  final String symbol, name, code;
  final double price, change;
  final bool isPositive;
  final Color color;

  const StockCard({
    required this.symbol,
    required this.name,
    required this.code,
    required this.price,
    required this.change,
    required this.isPositive,
    required this.color,
  });

  
  @override
  State<StockCard> createState() => _StockCardState();
}

class _StockCardState extends State<StockCard> {
  String? logoPath;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final logoManager = LogoManager();
    final path = await logoManager.fetchLogoPath(widget.symbol.toLowerCase());
    print('Logo path: $path');
    if (path.isNotEmpty) {
      setState(() {
        logoPath = path;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
  return InkWell(
    onTap: () {
      // Handle stock tap, e.g., navigate to a details page
      print('Tapped on ${widget.symbol}');
    },
    borderRadius: BorderRadius.circular(12),   
    child:Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MAINGREY,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Symbol of the Ticker and the company image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: BACKG_COLOR,
              shape: BoxShape.circle,        
              ),
            padding: EdgeInsets.all(15),           
            child: Center(
              child: logoPath != null
                  ? Image.file(File(logoPath!), width: 30, height: 30)
                  : Icon(Icons.image, size: 24, color: Colors.black),
            ),
          ),
          SizedBox(width: 16),

          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 15),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.symbol,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(widget.code, style: TextStyle(color: MAINGREY_LIGHT)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                widget.isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: widget.isPositive ? Colors.green : Colors.red,
              ),
              Text(
                '${widget.isPositive ? '+' : '-'}${widget.change.toStringAsFixed(2)}%',
                style: TextStyle(color: widget.isPositive ? Colors.green : Colors.red),
              ),
              SizedBox(height: 4),
              Text(
                '\$${widget.price.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 15),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.redAccent),
            onPressed: () {
              // Handle remove action (e.g., remove from list)
              print('Remove ${widget.symbol}');
            },
          ),
        ],
      ),
    )
    );
  }
}

class Stock {
  final String symbol;
  final String name;
  final String code;
  final double price;
  final double change;

  Stock({
    required this.symbol,
    required this.name,
    required this.code,
    required this.price,
    required this.change,
  });

  bool get isPositive => change >= 0;

  factory Stock.fromMap(Map<String, dynamic> map) {
    return Stock(
      symbol: map['symbol'],
      name: map['name'],
      code: map['code'],
      price: (map['price'] as num).toDouble(),
      change: (map['change'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'symbol': symbol,
    'name': name,
    'code': code,
    'price': price,
    'change': change,
  };
}

Widget buildStockCard(Stock stock) {
  return StockCard(
    symbol: stock.symbol,
    name: stock.name,
    code: stock.code,
    price: stock.price,
    change: stock.change,
    isPositive: stock.isPositive,
    color: Colors.amber.shade700,
  );
}
