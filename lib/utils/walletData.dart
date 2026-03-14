import 'package:Dogonomics/utils/tickerData.dart';

// Wallet Asset Types
enum AssetType {
  stock,
  bond,
  commodity,
  crypto,
}

// Base Asset Class
abstract class WalletAsset {
  final String symbol;
  final String name;
  final double currentValue;
  final double quantity;
  final AssetType type;

  WalletAsset({
    required this.symbol,
    required this.name,
    required this.currentValue,
    required this.quantity,
    required this.type,
  });

  double get totalValue => currentValue * quantity;
  
  Map<String, dynamic> toMap();
  
  factory WalletAsset.fromMap(Map<String, dynamic> data) {
    final typeStr = data['type'] as String?;
    
    switch (typeStr) {
      case 'bond':
        return BondAsset.fromMap(data);
      case 'commodity':
        return CommodityAsset.fromMap(data);
      case 'crypto':
        return CryptoAsset.fromMap(data);
      case 'stock':
      default:
        return StockAsset.fromStock(Stock.fromMap(data));
    }
  }
}

// Stock Asset
class StockAsset extends WalletAsset {
  final Stock stock;
  final double change;

  StockAsset({
    required this.stock,
    required this.change,
  }) : super(
          symbol: stock.symbol,
          name: stock.name,
          currentValue: stock.price,
          quantity: stock.quantity.toDouble(),
          type: AssetType.stock,
        );

  factory StockAsset.fromStock(Stock stock) {
    return StockAsset(
      stock: stock,
      change: stock.change,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...stock.toMap(),
      'type': 'stock',
    };
  }
}

// Bond Asset
class BondAsset extends WalletAsset {
  final String issuer;
  final double couponRate;
  final String maturityDate;
  final double faceValue;

  BondAsset({
    required String symbol,
    required String name,
    required double currentValue,
    required double quantity,
    required this.issuer,
    required this.couponRate,
    required this.maturityDate,
    required this.faceValue,
  }) : super(
          symbol: symbol,
          name: name,
          currentValue: currentValue,
          quantity: quantity,
          type: AssetType.bond,
        );

  factory BondAsset.fromMap(Map<String, dynamic> data) {
    return BondAsset(
      symbol: data['symbol'] ?? '',
      name: data['name'] ?? '',
      currentValue: (data['currentValue'] ?? 0.0).toDouble(),
      quantity: (data['quantity'] ?? 0.0).toDouble(),
      issuer: data['issuer'] ?? '',
      couponRate: (data['couponRate'] ?? 0.0).toDouble(),
      maturityDate: data['maturityDate'] ?? '',
      faceValue: (data['faceValue'] ?? 0.0).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'name': name,
      'currentValue': currentValue,
      'quantity': quantity,
      'type': 'bond',
      'issuer': issuer,
      'couponRate': couponRate,
      'maturityDate': maturityDate,
      'faceValue': faceValue,
    };
  }
}

// Commodity Asset
class CommodityAsset extends WalletAsset {
  final String category; // oil, gold, silver, etc.
  final String unit; // barrels, ounces, etc.

  CommodityAsset({
    required String symbol,
    required String name,
    required double currentValue,
    required double quantity,
    required this.category,
    required this.unit,
  }) : super(
          symbol: symbol,
          name: name,
          currentValue: currentValue,
          quantity: quantity,
          type: AssetType.commodity,
        );

  factory CommodityAsset.fromMap(Map<String, dynamic> data) {
    return CommodityAsset(
      symbol: data['symbol'] ?? '',
      name: data['name'] ?? '',
      currentValue: (data['currentValue'] ?? 0.0).toDouble(),
      quantity: (data['quantity'] ?? 0.0).toDouble(),
      category: data['category'] ?? '',
      unit: data['unit'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'name': name,
      'currentValue': currentValue,
      'quantity': quantity,
      'type': 'commodity',
      'category': category,
      'unit': unit,
    };
  }
}

// Crypto Asset
class CryptoAsset extends WalletAsset {
  final String network; // e.g., Ethereum, Bitcoin, Solana

  CryptoAsset({
    required String symbol,
    required String name,
    required double currentValue,
    required double quantity,
    this.network = '',
  }) : super(
          symbol: symbol,
          name: name,
          currentValue: currentValue,
          quantity: quantity,
          type: AssetType.crypto,
        );

  factory CryptoAsset.fromMap(Map<String, dynamic> data) {
    return CryptoAsset(
      symbol: data['symbol'] ?? '',
      name: data['name'] ?? '',
      currentValue: (data['currentValue'] ?? 0.0).toDouble(),
      quantity: (data['quantity'] ?? 0.0).toDouble(),
      network: data['network'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'name': name,
      'currentValue': currentValue,
      'quantity': quantity,
      'type': 'crypto',
      'network': network,
    };
  }
}

// Wallet Class
class Wallet {
  final List<WalletAsset> assets;

  Wallet({required this.assets});

  double get totalValue {
    return assets.fold(0.0, (sum, asset) => sum + asset.totalValue);
  }

  double get stocksValue {
    return assets
        .where((a) => a.type == AssetType.stock)
        .fold(0.0, (sum, asset) => sum + asset.totalValue);
  }

  double get bondsValue {
    return assets
        .where((a) => a.type == AssetType.bond)
        .fold(0.0, (sum, asset) => sum + asset.totalValue);
  }

  double get commoditiesValue {
    return assets
        .where((a) => a.type == AssetType.commodity)
        .fold(0.0, (sum, asset) => sum + asset.totalValue);
  }

  double get cryptoValue {
    return assets
        .where((a) => a.type == AssetType.crypto)
        .fold(0.0, (sum, asset) => sum + asset.totalValue);
  }

  int get totalAssets => assets.length;

  int get stockCount => assets.where((a) => a.type == AssetType.stock).length;
  int get bondCount => assets.where((a) => a.type == AssetType.bond).length;
  int get commodityCount => assets.where((a) => a.type == AssetType.commodity).length;
  int get cryptoCount => assets.where((a) => a.type == AssetType.crypto).length;

  List<StockAsset> get stocks => assets.whereType<StockAsset>().toList();
  List<BondAsset> get bonds => assets.whereType<BondAsset>().toList();
  List<CommodityAsset> get commodities => assets.whereType<CommodityAsset>().toList();
  List<CryptoAsset> get cryptos => assets.whereType<CryptoAsset>().toList();

  void addAsset(WalletAsset asset) {
    assets.add(asset);
  }

  void removeAsset(String symbol, AssetType type) {
    assets.removeWhere((a) => a.symbol == symbol && a.type == type);
  }

  Map<String, dynamic> toMap() {
    return {
      'assets': assets.map((a) => a.toMap()).toList(),
    };
  }

  factory Wallet.fromMap(Map<String, dynamic> data) {
    final assetsList = data['assets'] as List?;
    final assets = assetsList?.map((a) => WalletAsset.fromMap(a)).toList() ?? [];
    return Wallet(assets: assets);
  }
}
