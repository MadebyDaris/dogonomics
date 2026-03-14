import 'package:Dogonomics/backend/user.dart';
import 'package:Dogonomics/pages/stockview.dart';
import 'package:Dogonomics/pages/commoditiesPage.dart';
import 'package:Dogonomics/pages/treasuriesPage.dart';
import 'package:Dogonomics/pages/forexCryptoPage.dart';
import 'package:Dogonomics/pages/walletPage.dart';
import 'package:Dogonomics/pages/newsFeedPage.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:Dogonomics/utils/tickerData.dart';
import 'package:Dogonomics/utils/walletData.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, this.user});

  final String title;
  final AppUser? user;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final tabs = ['Stocks', 'News', 'Commodities', 'Treasuries', 'Forex/Crypto'];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
      preferredSize: const Size.fromHeight(140.0), // here the desired height
      child: AppBar(
        backgroundColor: MAINGREY,
        title: Container(
            padding: const EdgeInsets.only(top: 3, bottom: 0),
            margin: const EdgeInsets.only(left: 15, right: 20, top: 20, bottom: 20),
            child:
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              const Image(
                image: AssetImage("assets/images/dogonomicsLogo.png"),
                width: 90,
                height: 90,
              ),
              const Flexible(
                child: Text('DOGONOMICS! \n ASSISTANT', 
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Liberation Sans'),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              )
        ])),
        actions: [
          IconButton(
            icon: const Icon(Icons.wallet),
            tooltip: 'Total Wallet',
            onPressed: () => _openWallet(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      bottom: TabBar(
        dividerHeight: 0,
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          tabs: tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
          children: tabs.map((tab) {
          if (tab == 'Stocks') {
            return StockViewTab(stocks: List<Stock>.from(widget.user!.portfolio), userId: widget.user!.id,);
          } else if (tab == 'News') {
            return NewsFeedPage();
          } else if (tab == 'Commodities') {
            return CommoditiesPage();
          } else if (tab == 'Treasuries') {
            return TreasuriesPage();
          } else if (tab == 'Forex/Crypto') {
            return const ForexCryptoPage();
          } else {
            return Center(child: Text('Coming Soon...', style: TextStyle(color: Colors.grey)));
          }
        }).toList(),
      ),
    );
  }
  @override
  void initState() {
    super.initState();
        _tabController = TabController(length: tabs.length, vsync: this, initialIndex: 0);
  }

  void _openWallet(BuildContext context) async {
    // Stock assets from the current portfolio
    final stockAssets = widget.user!.portfolio.map((stock) => StockAsset.fromStock(stock)).toList();

    // Load bonds & commodities from Firestore
    List<WalletAsset> savedAssets = [];
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          final walletData = doc.data()!['wallet'] as Map<String, dynamic>?;
          if (walletData != null) {
            final assetsList = walletData['assets'] as List<dynamic>?;
            if (assetsList != null) {
              for (final item in assetsList) {
                if (item is Map<String, dynamic>) {
                  final type = item['type'] as String?;
                  // Only load bonds and commodities (stocks come from portfolio)
                  if (type == 'bond' || type == 'commodity') {
                    savedAssets.add(WalletAsset.fromMap(item));
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      // Silently continue with just stock assets
      debugPrint('Failed to load wallet assets: $e');
    }

    final wallet = Wallet(
      assets: [
        ...stockAssets,
        ...savedAssets,
      ],
    );

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WalletPage(wallet: wallet),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        // Clear shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        // Sign out from Firebase
        await FirebaseAuth.instance.signOut();
        
        // Navigation will be handled automatically by the AuthenticationWrapper
        // in main.dart which listens to auth state changes
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
