import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/tickerData.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  List<Stock> portfolio; 

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.portfolio
  });

  factory AppUser.fromMap(Map<String, dynamic> data) {
    List<Stock> portfolioList = [];
   if (data['portfolio'] != null) {
      if (data['portfolio'] is List<Stock>) {
        portfolioList = List<Stock>.from(data['portfolio']);
      } else if (data['portfolio'] is List) {
        // Convert from maps or strings
        for (var item in data['portfolio']) {
          if (item is Map<String, dynamic>) {
            portfolioList.add(Stock.fromMap(item));
          } else if (item is String) {
            portfolioList.add(Stock(
              symbol: item,
              name: item,
              code: 'STOCK',
              price: 0.0,
              change: 0.0,
              quantity: 1,
            ));
          }
        }
      }
    }

    return AppUser(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      portfolio: portfolioList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'portfolio': portfolio.map((stock) => stock.toMap()).toList(),
    };
  }
  String getUserId() {
    return FirebaseAuth.instance.currentUser!.uid;
  }


  // Updated this
  Future<void> addToPortfolio(String symb, {int quantity = 1}) async {
    try {
      String? userId = getUserId();
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      // await userRef.update({
      //   'portfolio': FieldValue.arrayUnion([symb])
      // });

      final stockData = await fetchSingleStock(
        symbol: symb, 
        quantity: quantity
      );

      if (stockData != null) {
        final userDoc = await userRef.get();
        if (userDoc.exists) {
          final portfolioData = userDoc.data()?['portfolio'] ?? [];
          List<Stock> currentPortfolio = [];
          // Convert existing portfolio
          for (var item in portfolioData) {
            if (item is Map<String, dynamic>) {
              currentPortfolio.add(Stock.fromMap(item));
            }
          }
          int existingIndex = currentPortfolio.indexWhere((s) => s.symbol == symb);
          
          if (existingIndex != -1) {
            currentPortfolio[existingIndex] = currentPortfolio[existingIndex].copyWith(
              quantity: currentPortfolio[existingIndex].quantity + quantity,
              price: stockData.price,
              change: stockData.change,
            );
          } else {
            // Add new stock
            currentPortfolio.add(stockData);
          }
          
          // Update local portfolio
          portfolio = currentPortfolio;
          
          // Update Firestore
          await userRef.update({
            'portfolio': currentPortfolio.map((stock) => stock.toMap()).toList()
          });
        }
      }
    } catch (e) {
      print('Error adding to portfolio: $e');
    }
  }


  Future<void> removeFromPortfolio(String symb, {int? qty}) async {
    try {
      String? userId = getUserId();
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

      int existingIndex = portfolio.indexWhere((s) => s.symbol == symb);
      if (existingIndex != -1) {
        int removeQty = qty ?? portfolio[existingIndex].quantity;
        int newQuantity = portfolio[existingIndex].quantity - removeQty;
        
        if (newQuantity <= 0) {
          portfolio.removeAt(existingIndex);
        } else {
          portfolio[existingIndex] = portfolio[existingIndex].copyWith(
            quantity: newQuantity
          );
        }
        
        // Update Firestore
        await userRef.update({
          'portfolio': portfolio.map((stock) => stock.toMap()).toList()
        });
      }

    } catch (e) {
      print('Error removing from portfolio: $e');
    }
  }

  Future<void> updateStockQuantity(String symbol, int newQuantity) async {
    try {
      String? userId = getUserId();
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      
      int existingIndex = portfolio.indexWhere((s) => s.symbol == symbol);
      
      if (existingIndex != -1) {
        if (newQuantity <= 0) {
          portfolio.removeAt(existingIndex);
        } else {
          portfolio[existingIndex] = portfolio[existingIndex].copyWith(
            quantity: newQuantity
          );
        }
        
        await userRef.update({
          'portfolio': portfolio.map((stock) => stock.toMap()).toList()
        });
      }
    } catch (e) {
      print('Error updating stock quantity: $e');
    }
  }
  double getTotalPortfolioValue() {
    return portfolio.fold(0.0, (sum, stock) => sum + (stock.price * stock.quantity));
  }

  double getTotalPortfolioChange() {
    return portfolio.fold(0.0, (sum, stock) => sum + (stock.change * stock.quantity));
  }

  Stock? getStock(String symbol) {
    try {
      return portfolio.firstWhere((stock) => stock.symbol == symbol);
    } catch (e) {
      return null;
    }
  }

  bool hasStock(String symbol) {
    return portfolio.any((stock) => stock.symbol == symbol);
  }

  List<String> getPortfolioSymbols() {
    return portfolio.map((stock) => stock.symbol).toList();
  }

  Future<void> refreshPortfolioData() async {
    try {
      List<Stock> refreshedPortfolio = await fetchUserQuotes(portfolio);
      portfolio = refreshedPortfolio;
      
      String? userId = getUserId();
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      await userRef.update({
        'portfolio': portfolio.map((stock) => stock.toMap()).toList()
      });
    } catch (e) {
      print('Error refreshing portfolio: $e');
    }
  }
}