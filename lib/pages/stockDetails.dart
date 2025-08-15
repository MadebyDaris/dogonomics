// Rewriting whole StockDetails the old one was a template generated to test
import 'package:dogonomics_frontend/widgets/stockDetailsWidgets.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../backend/dogonomicsApi.dart';

class StockDetailsPage extends StatefulWidget {
  final String symbol;

  const StockDetailsPage({Key? key, required this.symbol}) : super(key: key);


  @override
  _StockDetailsPageState createState() => _StockDetailsPageState();
}

class _StockDetailsPageState extends State<StockDetailsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StockData? stockData;
  SentimentData? sentimentData;
  bool isLoadingStock = true;
  bool isLoadingSentiment = true;
  String? stockError;
  String? sentimentError;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

    Future<void> _loadData() async {
    await Future.wait([
      _loadStockData(),
      _loadSentimentData(),
    ]);
  }
    Future<void> _loadStockData() async {
    try {
      final data = await DogonomicsAPI.fetchStockData(widget.symbol);
      if (mounted) {
        setState(() {
          stockData = data;
          isLoadingStock = false;
          stockError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingStock = false;
          stockError = e.toString();
        });
      }
    }
  }

  Future<void> _loadSentimentData() async {
    try {
      final data = await DogonomicsAPI.fetchSentimentData(widget.symbol);
      if (mounted) {
        setState(() {
          sentimentData = data;
          isLoadingSentiment = false;
          sentimentError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingSentiment = false;
          sentimentError = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
return Scaffold(
      backgroundColor: const Color(0xFF0D1421),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (isLoadingStock) 
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.blue),
            )
          else if (stockError != null)
            _buildErrorWidget(stockError!)
          else if (stockData != null) ...[
            CompanyHeader(stockData: stockData!),
            if (stockData!.chartData.isNotEmpty)
              ChartWidget(chartData: stockData!.chartData),
          ],
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildSentimentTab(),
              ],
            ),
          ),
        ],
      )
    );
  }
    PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D1421),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.symbol,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      centerTitle: true,
    );
  }

    Widget _buildOverviewTab() {
    if (stockData == null) {
      return const Center(
        child: Text(
          'No stock data available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Key Metrics'),
          const SizedBox(height: 16),
          KeyMetricsGrid(stockData: stockData!),
          const SizedBox(height: 24),
          const SectionTitle(title: 'About Company'),
          const SizedBox(height: 16),
          CompanyInfo(aboutDescription: stockData!.aboutDescription),
        ],
      ),
    );
  }

  Widget _buildSentimentTab() {
    if (isLoadingSentiment) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Analyzing sentiment...\nThis may take up to 60 seconds',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (sentimentError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Sentiment analysis failed',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              sentimentError!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSentimentData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (sentimentData == null) {
      return const Center(
        child: Text(
          'No sentiment data available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Overall Sentiment'),
          const SizedBox(height: 16),
          SentimentOverview(sentimentData: sentimentData!),
          const SizedBox(height: 24),
          const SectionTitle(title: 'News Analysis'),
          const SizedBox(height: 16),
          NewsList(news: sentimentData!.newsItems),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
    Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[400],
        indicatorColor: Colors.blue,
        indicatorWeight: 2,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Sentiment'),
        ],
      ),
    );
  }
}