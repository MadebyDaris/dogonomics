import 'package:dogonomics_frontend/backend/stockHandler.dart';
import 'package:dogonomics_frontend/pages/stockview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  required String name,
  required String code,
}) async {
  final quote = await fetchLiveQuote(symbol);
  if (quote == null) return null;

  final double price = quote.current;
  final double change = quote.current - quote.previousClose;

  return Stock(
    symbol: symbol,
    name: name,
    code: code,
    price: price,
    change: change,
  );
}