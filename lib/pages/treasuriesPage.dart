import 'package:Dogonomics/backend/dogonomicsApi.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:Dogonomics/utils/walletData.dart';
import 'package:Dogonomics/widgets/addAssetDialog.dart';
import 'package:Dogonomics/widgets/infoTooltip.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class TreasuriesPage extends StatefulWidget {
  const TreasuriesPage({Key? key}) : super(key: key);

  @override
  _TreasuriesPageState createState() => _TreasuriesPageState();
}

class _TreasuriesPageState extends State<TreasuriesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  YieldCurveData? yieldCurveData;
  TreasuryRatesData? ratesData;
  PublicDebtData? debtData;
  bool isLoadingYield = true;
  bool isLoadingRates = true;
  bool isLoadingDebt = true;
  String? yieldError;
  String? ratesError;
  String? debtError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    _loadYieldCurve();
    _loadRates();
    _loadDebt();
  }

  Future<void> _loadYieldCurve() async {
    setState(() {
      isLoadingYield = true;
      yieldError = null;
    });

    try {
      final data = await DogonomicsAPI.fetchYieldCurve();
      if (mounted) {
        setState(() {
          yieldCurveData = data;
          isLoadingYield = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          yieldError = e.toString();
          isLoadingYield = false;
        });
      }
    }
  }

  Future<void> _loadRates() async {
    setState(() {
      isLoadingRates = true;
      ratesError = null;
    });

    try {
      final data = await DogonomicsAPI.fetchTreasuryRates(days: 90);
      if (mounted) {
        setState(() {
          ratesData = data;
          isLoadingRates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          ratesError = e.toString();
          isLoadingRates = false;
        });
      }
    }
  }

  Future<void> _loadDebt() async {
    setState(() {
      isLoadingDebt = true;
      debtError = null;
    });

    try {
      final data = await DogonomicsAPI.fetchPublicDebt(days: 90);
      if (mounted) {
        setState(() {
          debtData = data;
          isLoadingDebt = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          debtError = e.toString();
          isLoadingDebt = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKG_COLOR,
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildYieldCurveTab(),
                _buildRatesTab(),
                _buildDebtTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        indicatorColor: ACCENT_COLOR,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Yield Curve'),
          Tab(text: 'Rates History'),
          Tab(text: 'Public Debt'),
        ],
      ),
    );
  }

  Widget _buildYieldCurveTab() {
    if (isLoadingYield) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      );
    }

    if (yieldError != null) {
      return _buildErrorWidget(yieldError!, _loadYieldCurve);
    }

    if (yieldCurveData == null || yieldCurveData!.data.isEmpty) {
      return const Center(
        child: Text(
          'No yield curve data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildYieldCurveHeader(),
          const SizedBox(height: 24),
          _buildYieldCurveChart(),
          const SizedBox(height: 24),
          _buildYieldDataList(),
        ],
      ),
    );
  }

  Widget _buildRatesTab() {
    if (isLoadingRates) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      );
    }

    if (ratesError != null) {
      return _buildErrorWidget(ratesError!, _loadRates);
    }

    if (ratesData == null || ratesData!.data.isEmpty) {
      return const Center(
        child: Text(
          'No rates data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRatesHeader(),
          const SizedBox(height: 24),
          _buildRatesChart(),
        ],
      ),
    );
  }

  Widget _buildDebtTab() {
    if (isLoadingDebt) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      );
    }

    if (debtError != null) {
      return _buildErrorWidget(debtError!, _loadDebt);
    }

    if (debtData == null || debtData!.data.isEmpty) {
      return const Center(
        child: Text(
          'No debt data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDebtHeader(),
          const SizedBox(height: 24),
          _buildDebtChart(),
        ],
      ),
    );
  }

  Widget _buildYieldCurveHeader() {
    return Column(
      children: [
        QuickTipBanner(
          tip: 'Treasury bonds are debt securities issued by the U.S. government. They\'re considered one of the safest investments!',
          color: COLOR_INFO,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: STOCK_CARD,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'US Treasury Yield Curve',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  InfoTooltip(
                    title: 'Yield Curve Explained',
                    message: 'The yield curve shows the relationship between interest rates (yields) and time to maturity for Treasury securities. \n\n• Normal Curve: Long-term rates higher than short-term (healthy economy)\n• Inverted Curve: Short-term rates higher than long-term (potential recession)\n• Flat Curve: Similar rates across maturities (economic uncertainty)\n\nInvestors use the yield curve to gauge economic outlook and make investment decisions.',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'As of ${yieldCurveData!.data.first.recordDate}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InfoCard(
          icon: Icons.school_outlined,
          iconColor: COLOR_WARNING,
          title: 'Understanding Treasury Securities',
          summary: 'Learn about different types of U.S. government bonds',
          detailedInfo: '''
Treasury securities are debt instruments issued by the U.S. Department of the Treasury:

Types of Treasury Securities:
• T-Bills (Treasury Bills): Short-term, mature in 1 year or less
• T-Notes (Treasury Notes): Medium-term, mature in 2-10 years
• T-Bonds (Treasury Bonds): Long-term, mature in 20-30 years
• TIPS (Treasury Inflation-Protected Securities): Principal adjusts with inflation

Key Terms:
• Maturity Date: When the bond pays back the full principal (face value)
• Coupon Rate: The fixed interest rate paid periodically
• Yield: The return you actually earn, which changes with market price
• Par Value: The face value of the bond (usually \$1,000)

Why Invest in Treasuries?
✓ Backed by U.S. government (extremely low risk)
✓ Predictable income stream
✓ Liquid market (easy to buy/sell)
✓ Favorable tax treatment (exempt from state/local taxes)
✓ Portfolio diversification

Risks to Consider:
- Interest Rate Risk: Bond prices fall when rates rise
- Inflation Risk: Fixed payments lose purchasing power
- Opportunity Cost: Lower returns than riskier investments
          ''',
        ),
      ],
    );
  }

  Widget _buildYieldCurveChart() {
    final chartData = yieldCurveData!.data
        .where((item) => item.avgInterestRateAmt != null)
        .toList();

    if (chartData.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = chartData
        .asMap()
        .entries
        .map((e) => FlSpot(
              e.key.toDouble(),
              double.tryParse(e.value.avgInterestRateAmt!) ?? 0.0,
            ))
        .toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[800]!,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYieldDataList() {
    return Container(
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Treasury Securities',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: yieldCurveData!.data.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.grey[800]!,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final item = yieldCurveData!.data[index];
              final rate = double.tryParse(item.avgInterestRateAmt ?? '0') ?? 0.0;
              return ListTile(
                title: Text(
                  item.securityDesc ?? 'Unknown',
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Text(
                  'Rate: ${item.avgInterestRateAmt ?? 'N/A'}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.avgInterestRateAmt ?? 'N/A'}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showAddBondDialog(item, rate),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BUTTON_PRIMARY,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRatesHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Historical Treasury Rates',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              InfoTooltip(
                title: 'Treasury Rates',
                message: 'Treasury rates represent the interest (yield) the government pays to borrow money. These rates:\n\n• Change daily based on market demand\n• Rise when inflation expectations increase\n• Fall during economic uncertainty (flight to safety)\n• Influence mortgage rates, loan rates, and other financial products\n\nWatching rate trends helps predict Federal Reserve policy and economic conditions.',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Last 90 days • ${ratesData!.data.length} data points',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatesChart() {
    final chartData = ratesData!.data
        .where((item) => item.avgInterestRateAmt != null)
        .toList()
        .reversed
        .toList();

    if (chartData.isEmpty) {
      return const Center(
        child: Text(
          'Not enough data for chart',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final spots = chartData
        .asMap()
        .entries
        .map((e) => FlSpot(
              e.key.toDouble(),
              double.tryParse(e.value.avgInterestRateAmt!) ?? 0.0,
            ))
        .toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[800]!,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.orange,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.orange.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtHeader() {
    final latestDebt = debtData!.data.isNotEmpty
        ? debtData!.data.first.totPubDebtOutAmt
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'US Public Debt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              InfoTooltip(
                title: 'Public Debt Explained',
                message: 'Public debt is the total amount the U.S. government owes to bondholders. It grows when:\n\n• Government spending exceeds tax revenue (deficit)\n• Interest accumulates on existing debt\n• Economic stimulus programs are enacted\n\nWhy it matters:\n• High debt can lead to higher interest rates\n• Affects currency value and inflation\n• Influences government\'s ability to borrow\n• Impacts future generations through debt service\n\nDebt-to-GDP ratio is a key metric for comparing debt burden across countries and time periods.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (latestDebt != null)
            Text(
              '\$${_formatLargeNumber(double.tryParse(latestDebt) ?? 0.0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'As of ${debtData!.data.first.recordDate}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtChart() {
    final chartData = debtData!.data
        .where((item) => item.totPubDebtOutAmt != null)
        .toList()
        .reversed
        .toList();

    if (chartData.isEmpty) {
      return const Center(
        child: Text(
          'Not enough data for chart',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final spots = chartData
        .asMap()
        .entries
        .map((e) => FlSpot(
              e.key.toDouble(),
              (double.tryParse(e.value.totPubDebtOutAmt!) ?? 0.0) / 1e12, // Convert to trillions
            ))
        .toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: STOCK_CARD,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[800]!,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.red,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.red.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Failed to load data',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _formatLargeNumber(double value) {
    if (value >= 1e12) {
      return '${(value / 1e12).toStringAsFixed(2)} Trillion';
    } else if (value >= 1e9) {
      return '${(value / 1e9).toStringAsFixed(2)} Billion';
    } else if (value >= 1e6) {
      return '${(value / 1e6).toStringAsFixed(2)} Million';
    }
    return value.toStringAsFixed(2);
  }

  Future<void> _showAddBondDialog(YieldCurveItem item, double rate) async {
    final success = await showAddAssetDialog(
      context: context,
      assetType: AssetType.bond,
      symbol: (item.securityDesc ?? 'Treasury').replaceAll(' ', '_').toUpperCase(),
      name: item.securityDesc ?? 'US Treasury Bond',
      currentPrice: 100.0, // Face value of treasury bonds
      category: 'Treasury',
      unit: 'bonds',
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.securityDesc} added to wallet!'),
          backgroundColor: COLOR_POSITIVE,
        ),
      );
    }
  }
}