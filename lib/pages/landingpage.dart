  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:Dogonomics/pages/frontpage.dart';
  import 'package:Dogonomics/utils/constant.dart';
  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'dart:math' as math;
  import 'package:url_launcher/url_launcher.dart' as url;

  import '../backend/user.dart';
  import '../utils/tickerData.dart';
  import '../widgets/landingPageWidget.dart';


class DogonomicsLandingPage extends StatefulWidget {
  final String? userId;
  final VoidCallback? onContinueToPortfolio;
  
  const DogonomicsLandingPage({
    Key? key, 
    this.userId,
    this.onContinueToPortfolio,
    }) : super(key: key);
  @override
  State<DogonomicsLandingPage> createState() => _DogonomicsLandingPageState();
}

class _DogonomicsLandingPageState extends State<DogonomicsLandingPage> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _currentQuoteIndex = 0;
  AppUser? _user;
  bool _isLoadingUser = false;
  
  final List<String> _quotes = [
    "Sit. Stay. Invest.",
    "Remember: every dog has its day… and every stock its dip.",
    "We sniff out opportunities better than a beagle at the park.",
    "No chasing tails here, only trends.",
    "Paw-sitively the best place to watch your money grow.",
    "Woof! Time to fetch those gains.",
    "Bad market? Just roll over and hold.",
    "Bone or bond, we know what to fetch.",
    "Sit tight, your portfolio is learning new tricks.",
    "Arf-ificial intelligence meets finance."
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
    
    // Load user data if userId is provided
    if (widget.userId != null) {
      _loadUserData();
    }
        Future.delayed(Duration.zero, () {
      _startQuoteRotation();
    });
  }
  // 
  // Portfolio firestore methods
  // 
  Future<void> _loadUserData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingUser = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = widget.userId!;
      final userEmail = prefs.getString('userEmail') ?? '';
      
      // Get user data from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!mounted) return;
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final username = userData['username'] ?? '';
        
        // Save username to preferences if not already saved
        await prefs.setString('username', username);
        
        // Load portfolio data
        final List<Stock> portfolio = await _loadPortfolioFromFirestore(userData['portfolio'] ?? []);
        
        if (mounted) {
          setState(() {
            _user = AppUser.fromMap({
              'id': userId,
              'name': username,
              'email': userEmail,
              'portfolio': portfolio,
            });
            _isLoadingUser = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load user data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<Stock>> _loadPortfolioFromFirestore(List<dynamic> portfolioData) async {
    List<Stock> stocks = [];
    
    for (var stockData in portfolioData) {
      try {
        if (stockData is Map<String, dynamic>) {
          stocks.add(Stock.fromMap(stockData));
        } else if (stockData is String) {
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

  void _continueToPortfolio() {
    if (widget.onContinueToPortfolio != null) {
      widget.onContinueToPortfolio!();
    } else if (_user != null) {
      // Navigate to portfolio with loaded user data
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MyHomePage(title: "Dogonomics", user: _user),
        ),
      );
    } else if (widget.userId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading user data... Please wait a moment.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }


  void _startQuoteRotation() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentQuoteIndex = (_currentQuoteIndex + 1) % _quotes.length;
        });
        _startQuoteRotation();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050E14),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF050E14),
              const Color(0xFF0B0B0C),
              const Color(0xFF19B305).withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(),
                      _buildQuoteSection(),
                      _buildActionButtons(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Animated Logo
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _animationController.value * 2 * math.pi * 0.05, // Subtle rotation
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF19B305),
                        const Color(0xFF23C00F),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF19D900).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.pets,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          
          // App Title
          Text(
            'DOGONOMICS',
            style: GoogleFonts.libreFranklin(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ASSISTANT',
            style: GoogleFonts.libreFranklin(
              fontSize: 18,
              fontWeight: FontWeight.w300,
              color: const Color(0xFF19B305),
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 16),
          
          // Subtitle
          Text(
            'AI-Powered Financial Sentiment Analysis',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[400],
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF19B305).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.format_quote,
            size: 32,
            color: Color(0xFF19B305),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Text(
              _quotes[_currentQuoteIndex],
              key: ValueKey(_currentQuoteIndex),
              style: GoogleFonts.inter(
                fontSize: 18,
                color: Colors.white,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              color: const Color(0xFF19B305),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildActionButton(
            icon: Icons.info_outline,
            title: 'About Dogonomics',
            subtitle: 'Learn about our mission and technology',
            onTap: () => _navigateToPage(const AboutPage()),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            icon: Icons.settings_input_composite,
            title: 'How It Works',
            subtitle: 'Discover the power of ONNX & sentiment analysis',
            onTap: () => _navigateToPage(const HowItWorksPage()),
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            icon: Icons.favorite,
            title: 'Support Creator',
            subtitle: 'Meet the creator and support the project',
            onTap: () => _navigateToPage(const SupportCreatorPage()),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B0C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey[800]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF19B305).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF19B305),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[600],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoadingUser ? null : _continueToPortfolio,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF19B305),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Continue to Portfolio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }
}
