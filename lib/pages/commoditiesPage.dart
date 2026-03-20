import 'package:Dogonomics/backend/dogonomicsApi.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:Dogonomics/utils/walletData.dart';
import 'package:Dogonomics/widgets/addAssetDialog.dart';
import 'package:Dogonomics/widgets/doggo_inline_insight.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class CommoditiesPage extends StatefulWidget {
  const CommoditiesPage({Key? key}) : super(key: key);

  @override
  _CommoditiesPageState createState() => _CommoditiesPageState();
}

class _CommoditiesPageState extends State<CommoditiesPage> {
  String selectedCategory = 'oil';
  String selectedSubtype = 'wti';
  bool isLoading = false;
  CommodityData? commodityData;
  String? error;

  final Map<String, List<String>> commodityOptions = {
    'oil': ['wti', 'brent'],
    'gas': [],
    'metals': ['copper', 'aluminum'],
    'agriculture': ['wheat', 'corn', 'cotton', 'sugar', 'coffee'],
  };

  @override
  void initState() {
    super.initState();
    _loadCommodityData();
  }

  Future<void> _loadCommodityData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final data = await DogonomicsAPI.fetchCommodityData(
        selectedCategory,
        subtype: selectedSubtype.isNotEmpty ? selectedSubtype : null,
      );
      if (mounted) {
        setState(() {
          commodityData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
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
          _buildCategorySelector(),
          if (commodityOptions[selectedCategory]!.isNotEmpty)
            _buildSubtypeSelector(),
            
          const DoggoInlineInsightWidget(
            context: 'Commodities',
            prompt: 'Give a brief 2-sentence update on the current state of commodities like oil and gold.',
          ),
          
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: commodityOptions.keys.map((category) {
                  final isSelected = selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: ACCENT_COLOR,
                      backgroundColor: STOCK_CARD,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            selectedCategory = category;
                            selectedSubtype = commodityOptions[category]!.isNotEmpty
                                ? commodityOptions[category]!.first
                                : '';
                          });
                          _loadCommodityData();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtypeSelector() {
    final subtypes = commodityOptions[selectedCategory]!;
    if (subtypes.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: subtypes.map((subtype) {
            final isSelected = selectedSubtype == subtype;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  subtype.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.grey,
                  ),
                ),
                selected: isSelected,
                selectedColor: ACCENT_COLOR_BRIGHT,
                backgroundColor: STOCK_CARD,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      selectedSubtype = subtype;
                    });
                    _loadCommodityData();
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.oil_barrel_outlined, size: 48, color: COLOR_COMMODITIES),
            SizedBox(height: 12),
            CircularProgressIndicator(color: COLOR_COMMODITIES),
            SizedBox(height: 14),
            Text(
              'Loading commodity prices...',
              style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: COLOR_NEGATIVE),
            const SizedBox(height: 12),
            const Text(
              'Unable to load commodity data',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: COLOR_COMMODITIES),
              onPressed: _loadCommodityData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (commodityData == null) {
      return const Center(
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 48, color: TEXT_SECONDARY),
            SizedBox(height: 12),
            Text(
              'No commodity data available',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildPriceChart(),
          const SizedBox(height: 24),
          _buildDataTable(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    if (commodityData == null) return const SizedBox.shrink();

    final latestPrice = commodityData!.data.isNotEmpty
        ? double.tryParse(commodityData!.data.first.value) ?? 0.0
        : 0.0;

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
              Expanded(
                child: Text(
                  commodityData!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showAddCommodityDialog(latestPrice),
                icon: const Icon(Icons.add),
                label: const Text('Add to Wallet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BUTTON_PRIMARY,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Interval: ${commodityData!.interval}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '\$${latestPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                commodityData!.unit,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChart() {
    if (commodityData == null || commodityData!.data.length < 2) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: STOCK_CARD,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: const Center(
          child: Text(
            'Not enough data for chart',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final spots = commodityData!.data
        .asMap()
        .entries
        .map((e) => FlSpot(
              e.key.toDouble(),
              double.tryParse(e.value.value) ?? 0.0,
            ))
        .toList()
        .reversed
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
              color: ACCENT_COLOR,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: ACCENT_COLOR.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (commodityData == null || commodityData!.data.isEmpty) {
      return const SizedBox.shrink();
    }

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
              'Recent Data',
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
            itemCount: commodityData!.data.length > 10 ? 10 : commodityData!.data.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.grey[800]!,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final item = commodityData!.data[index];
              return ListTile(
                title: Text(
                  item.date,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Text(
                  '\$${double.tryParse(item.value)?.toStringAsFixed(2) ?? item.value}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddCommodityDialog(double currentPrice) async {
    if (commodityData == null) return;

    final success = await showAddAssetDialog(
      context: context,
      assetType: AssetType.commodity,
      symbol: selectedSubtype.replaceAll(' ', '_').toUpperCase(),
      name: commodityData!.name,
      currentPrice: currentPrice,
      category: selectedCategory,
      unit: commodityData!.unit,
    );

    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${commodityData!.name} added to wallet!'),
          backgroundColor: COLOR_POSITIVE,
        ),
      );
    }
  }
}