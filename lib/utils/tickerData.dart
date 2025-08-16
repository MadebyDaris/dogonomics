import 'package:dogonomics_frontend/backend/dogonomicsApi.dart';
import 'package:dogonomics_frontend/backend/stockHandler.dart';
import 'package:dogonomics_frontend/pages/stockview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Stock {
  final String symbol;
  final String name;
  final String code;
  final double price;
  final double change;
  final int quantity;

  Stock({
    required this.symbol,
    required this.name,
    required this.code,
    required this.price,
    required this.change,
    this.quantity = 1,
  });

  // Factory method to create Stock from map (for Firebase)
  factory Stock.fromMap(Map<String, dynamic> data) {
    return Stock(
      symbol: data['symbol'] ?? '',
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      change: (data['change'] ?? 0.0).toDouble(),
      quantity: data['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'name': name,
      'code': code,
      'price': price,
      'change': change,
      'quantity': quantity,
    };
  }

  double get changePercentage {
    if (price == 0) return 0.0;
    return (change / (price - change)) * 100;
  }

  bool get isPositive => change >= 0;

  Stock copyWith({int? quantity, double? price, double? change}) {
    return Stock(
      symbol: symbol,
      name: name,
      code: code,
      price: price ?? this.price,
      change: change ?? this.change,
      quantity: quantity ?? this.quantity,
    );
  }
}

class LiveQuote {
  final String symbol;
  final double current;
  final double high;
  final double low;
  final double open;
  final double previousClose;

  LiveQuote({
    required this.symbol,
    required this.current,
    required this.high,
    required this.low,
    required this.open,
    required this.previousClose,
  });

  factory LiveQuote.fromJson(Map<String, dynamic> json) {
    return LiveQuote(
      symbol: json['symbol'],
      current: (json['c'] as num).toDouble(),
      high: (json['h'] as num).toDouble(),
      low: (json['l'] as num).toDouble(),
      open: (json['o'] as num).toDouble(),
      previousClose: (json['pc'] as num).toDouble(),
    );
  }
}

Future<LiveQuote?> fetchLiveQuote(String symbol) async {
  final url = Uri.parse('http://10.0.2.2:8080/quote/$symbol');
  try {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return LiveQuote.fromJson(data);
    } else {
      print('Error: ${response.statusCode}');
    }
  } catch (e) {
    print('Failed to fetch quote: $e');
  }
  return null;
}

Future<List<Stock>> fetchUserQuotes(List<Stock> stocks) async {
  final List<Stock> stocksFetched = [];
  for (final stock in stocks) {
    final quote = await fetchLiveQuote(stock.symbol);
    if (quote == null) {
      stocksFetched.add(stock);
    }
    else {
      final double price = quote.current;
      final double change = quote.current - quote.previousClose;

      final newstock = Stock(
        symbol: stock.symbol,
        name: stock.name,
        code: stock.code,
        price: price,
        change: change,
      );
      stocksFetched.add(newstock);
    }
  }
  return stocksFetched;
}

Future<Stock> enrichStockWithQuote(Stock stock) async {
  final quote = await fetchLiveQuote(stock.symbol);
  if (quote == null) return stock;

  final double price = quote.current;
  final double change = quote.current - quote.previousClose;

  return Stock(
    symbol: stock.symbol,
    name: stock.name,
    code: stock.code,
    price: price,
    change: change,
  );
}

Future<Stock?> fetchSingleStock({
  required String symbol,
  String? name,
  String? code,
  int quantity = 1,
}) async {
  try {
    final quote = await fetchLiveQuote(symbol);
    
    if (quote != null) {
      final double change = quote.current - quote.previousClose;
      
      return Stock(
        symbol: symbol,
        name: name ?? symbol,
        code: code ?? 'STOCK',
        price: quote.current,
        change: change,
        quantity: quantity,
      );
    }
    
    // Fallback to DogonomicsAPI for detailed stock data
    final stockData = await DogonomicsAPI.fetchStockData(symbol);
    
    return Stock(
      symbol: stockData.symbol,
      name: stockData.companyName,
      code: stockData.exchange,
      price: stockData.currentPrice,
      change: stockData.changePercentage, // This is already a percentage from API
      quantity: quantity,
    );
    
  } catch (e) {
    print('Failed to fetch stock data for $symbol: $e');
    return null;
  }
}

// Convert StockData from DogonomicsAPI to Stock model
Stock stockDataToStock(StockData stockData, {int quantity = 1}) {
  return Stock(
    symbol: stockData.symbol,
    name: stockData.companyName,
    code: stockData.exchange,
    price: stockData.currentPrice,
    change: stockData.changePercentage,
    quantity: quantity,
  );
}