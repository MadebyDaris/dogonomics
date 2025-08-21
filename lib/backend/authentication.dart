import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Dogonomics/backend/stockHandler.dart';
import 'package:Dogonomics/backend/user.dart';
import 'package:Dogonomics/pages/frontpage.dart';
import 'package:Dogonomics/pages/landingpage.dart';
import 'package:Dogonomics/pages/stockview.dart';
import 'package:Dogonomics/utils/tickerData.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoginMode = true;
  bool _isLoading = false;


  Future<void> _login() async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
          final user = credential.user;

      if (user != null) {
        // Get username from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final username = userData['username'] ?? '';


        final List<Stock> portfolio = await _loadPortfolioFromFirestore(userData['portfolio'] ?? []);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', user.uid);
        await prefs.setString('userEmail', user.email ?? '');
        await prefs.setString('username', username);
        final myuser = AppUser.fromMap({
          'id': user.uid,
          'name': username,
          'email': user.email,
          'portfolio': portfolio,
        });
        Navigator.pushReplacement(context, 
          MaterialPageRoute(builder: (_) => 
            DogonomicsLandingPage(onContinueToPortfolio: null, userId: user.uid,
          )));        
        }
      }
    } catch (e) {
      print('Login failed: $e');
      _showErrorDialog('Login failed: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signup() async {
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if (user != null) {
        final username = _usernameController.text.trim();

        // Save to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'username': username,
          'portfolio': [], // Initialize with empty portfolio
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Save locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', user.uid);
        await prefs.setString('userEmail', user.email ?? '');
        await prefs.setString('username', username);

        final myuser = AppUser.fromMap({
          'id': user.uid,
          'name': username,
          'email': user.email,
          'portfolio': [],
        });
      Navigator.pushReplacement(context, 
        MaterialPageRoute(builder: (_) => DogonomicsLandingPage(onContinueToPortfolio: () {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute( 
              builder: (_) => MyHomePage(title: "DOGONOMICS", user: myuser)
            )
          );
        }
        )));
      }
    } catch (e) {
      print('Signup failed: $e');
      _showErrorDialog('Signup failed: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<List<Stock>> _loadPortfolioFromFirestore(List<dynamic> portfolioData) async {
    List<Stock> stocks = [];
    
    for (var stockData in portfolioData) {
      try {
        if (stockData is Map<String, dynamic>) {
          // If we have complete stock data stored
          stocks.add(Stock.fromMap(stockData));
        } else if (stockData is String) {
          // If we only have symbols stored, fetch current data
          final stock = await fetchSingleStock(
            symbol: stockData,
            name: 'Loading...',
            code: 'ETF',
          );
          if (stock != null) {
            stocks.add(stock);
          }
        }
      } catch (e) {
        print('Error loading stock data: $e');
      }
    }
    
    return stocks;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsetsGeometry.all(16.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_isLoginMode ? "Login" : "Sign Up", style: TextStyle(fontSize: 24, fontStyle: FontStyle.italic)),
              Text(_isLoginMode ? "Time to study some \nDogonomics!" : "Dog catch bones, you catch bonds, \nsame thing no?!", style: TextStyle(fontSize: 12)),
              SizedBox(height: 20),
              if (!_isLoginMode)

              TextField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: "Username"),
              ),
              TextField(
                controller: _emailController, 
                decoration: InputDecoration(labelText: "Email")),
              TextField(
                controller: _passwordController, 
                decoration: InputDecoration(labelText: "Password"), obscureText: true),

              SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isLoginMode ? _login : _signup,
                child: Text(_isLoginMode ? 'Login' : 'Sign Up'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                  });},
                child: Text(_isLoginMode
                    ? "Don't have an account? Sign Up"
                    : "Already have an account? Login"),
            ),
          ],
        ),
      )
    );
  }
}


// Portfolio Service for Firebase operations
class PortfolioService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add stock to user's portfolio
  static Future<bool> addStockToPortfolio(String userId, Stock stock) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final portfolioData = userDoc.data()?['portfolio'] ?? [];
        List<Stock> currentPortfolio = [];
        
        for (var stockData in portfolioData) {
          if (stockData is Map<String, dynamic>) {
            currentPortfolio.add(Stock.fromMap(stockData));
          }
        }
        int existingIndex = currentPortfolio.indexWhere((s) => s.symbol == stock.symbol);
        
        if (existingIndex != -1) {
          currentPortfolio[existingIndex] = currentPortfolio[existingIndex].copyWith(
            quantity: currentPortfolio[existingIndex].quantity + stock.quantity,
            price: stock.price,
            change: stock.change,
          );
        } else {
          currentPortfolio.add(stock);
        }
        
        await _firestore.collection('users').doc(userId).update({
          'portfolio': currentPortfolio.map((s) => s.toMap()).toList()
        });
      }
      return true;
    } catch (e) {
      print('Error adding stock to portfolio: $e');
      return false;
    }
  }

  static Future<bool> removeStockFromPortfolio(String userId, Stock stock, {int? quantityToRemove}) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists){
        final portfolioData = userDoc.data()?['portfolio'] ?? [];
        List<Stock> currentPortfolio = [];

                for (var stockData in portfolioData) {
          if (stockData is Map<String, dynamic>) {
            currentPortfolio.add(Stock.fromMap(stockData));
          }
        }
        
        // Find and update/remove stock
        int existingIndex = currentPortfolio.indexWhere((s) => s.symbol == stock.symbol);
        
        if (existingIndex != -1) {
          int removeQty = quantityToRemove ?? stock.quantity;
          int newQuantity = currentPortfolio[existingIndex].quantity - removeQty;
          
          if (newQuantity <= 0) {
            currentPortfolio.removeAt(existingIndex);
          } else {
            currentPortfolio[existingIndex] = currentPortfolio[existingIndex].copyWith(
              quantity: newQuantity,
            );
          }
          
          await _firestore.collection('users').doc(userId).update({
            'portfolio': currentPortfolio.map((s) => s.toMap()).toList()
          });
        }
      }
      return true;
    } catch (e) {
      print('Error removing stock from portfolio: $e');
      return false;
    }
  }

  static Future<List<Stock>> getUserPortfolio(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final portfolioData = userDoc.data()?['portfolio'] ?? [];
        List<Stock> stocks = [];
        
        for (var stockData in portfolioData) {
          if (stockData is Map<String, dynamic>) {
            stocks.add(Stock.fromMap(stockData));
          }
        }
        
        return stocks;
      }
    } catch (e) {
      print('Error getting user portfolio: $e');
    }
    return [];
  }

  // Update entire portfolio (useful for bulk updates)
static Future<bool> updateStockQuantity(String userId, String symbol, int newQuantity) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final portfolioData = userDoc.data()?['portfolio'] ?? [];
        List<Stock> currentPortfolio = [];
        
        for (var stockData in portfolioData) {
          if (stockData is Map<String, dynamic>) {
            currentPortfolio.add(Stock.fromMap(stockData));
          }
        }
        
        // Find and update stock quantity
        int existingIndex = currentPortfolio.indexWhere((s) => s.symbol == symbol);
        
        if (existingIndex != -1) {
          if (newQuantity <= 0) {
            currentPortfolio.removeAt(existingIndex);
          } else {
            currentPortfolio[existingIndex] = currentPortfolio[existingIndex].copyWith(
              quantity: newQuantity,
            );
          }
          
          await _firestore.collection('users').doc(userId).update({
            'portfolio': currentPortfolio.map((s) => s.toMap()).toList()
          });
        }
      }
      return true;
    } catch (e) {
      print('Error updating stock quantity: $e');
      return false;
    }
  }

  // Listen to portfolio changes in real-time
  static Stream<List<Stock>> listenToPortfolio(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (doc.exists) {
        final portfolioData = doc.data()?['portfolio'] ?? [];
        List<Stock> stocks = [];
        
        for (var stockData in portfolioData) {
          if (stockData is Map<String, dynamic>) {
            stocks.add(Stock.fromMap(stockData));
          }
        }
        
        return stocks;
      }
      return <Stock>[];
    });
  }
}