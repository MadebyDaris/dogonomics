import 'package:Dogonomics/backend/user.dart';
import 'package:Dogonomics/pages/stockview.dart';
import 'package:Dogonomics/pages/commoditiesPage.dart';
import 'package:Dogonomics/pages/treasuriesPage.dart';
import 'package:Dogonomics/pages/forexCryptoPage.dart';
import 'package:Dogonomics/pages/economicIndicatorsPage.dart';
import 'package:Dogonomics/pages/walletPage.dart';
import 'package:Dogonomics/pages/newsFeedPage.dart';
import 'package:Dogonomics/pages/dogonomicsAdvicePage.dart';
import 'package:Dogonomics/backend/providers.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:Dogonomics/utils/tickerData.dart';
import 'package:Dogonomics/utils/walletData.dart';
import 'package:Dogonomics/widgets/doggo_sidebar_widget.dart';
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
  final RouteProvider _routeProvider = RouteProvider();
  final MetricExplanationProvider _explanationProvider = MetricExplanationProvider();

  final tabs = ['Stocks', 'News', 'Commodities', 'Treasuries', 'Forex/Crypto', 'Economy'];

  String _routeForTabIndex(int index) {
    switch (index) {
      case 0:
        return '/frontpage';
      case 1:
        return '/news_feed';
      case 2:
        return '/commodities';
      case 3:
        return '/treasuries';
      case 4:
        return '/forex_crypto';
      case 5:
        return '/economy';
      default:
        return '/frontpage';
    }
  }

  void _syncRouteContext() {
    _routeProvider.setRoute(_routeForTabIndex(_tabController.index));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110.0),
        child: AppBar(
          backgroundColor: MAINGREY,
          elevation: 0,
          title: Row(
            children: [
              Image.asset("assets/images/dogonomicsLogo.png", height: 40),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DOGONOMICS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Liberation Sans',
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'ASSISTANT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: ACCENT_GREEN,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
            indicatorColor: ACCENT_GREEN,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF757575),
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            tabs: const [
              Tab(text: 'Stocks'),
              Tab(text: 'News'),
              Tab(text: 'Commodities'),
              Tab(text: 'Treasuries'),
              Tab(text: 'Forex/Crypto'),
              Tab(text: 'Economy'),
            ],
          ),
        ),
      ),

      body: SidebarScaffold(
        currentRoute: _routeForTabIndex(_tabController.index),
        routeProvider: _routeProvider,
        explanationProvider: _explanationProvider,
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
              return ForexCryptoPage(
                onSymbolContextChanged: (symbol) {
                  _routeProvider.setRoute(
                    '/forex_crypto',
                    symbol: symbol,
                    data: {'assetClass': 'crypto'},
                  );
                },
              );
            } else if (tab == 'Economy') {
              return EconomicIndicatorsPage();
            } else {
              return Center(child: Text('Coming Soon...', style: TextStyle(color: Colors.grey)));
            }
          }).toList(),
        ),
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this, initialIndex: 0);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _syncRouteContext();
      }
    });
    _syncRouteContext();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
