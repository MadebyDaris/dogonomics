import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Dogonomics/utils/walletData.dart';
import 'package:Dogonomics/utils/constant.dart';

class WalletPage extends StatefulWidget {
  final Wallet wallet;

  const WalletPage({
    Key? key,
    required this.wallet,
  }) : super(key: key);

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedView = 'All'; // All, Stocks, Bonds, Commodities

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: APP_BACKGROUND,
      appBar: AppBar(
        title: const Text('Total Wallet'),
        backgroundColor: CARD_BACKGROUND,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildWalletOverview(),
            const SizedBox(height: 16),
            _buildAllocationChart(),
            const SizedBox(height: 16),
            _buildAssetTypeBreakdown(),
            const SizedBox(height: 16),
            _buildAssetsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletOverview() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: gradientCardDecoration(
        startColor: ACCENT_GREEN,
        endColor: ACCENT_GREEN_LIGHT,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Wallet Value',
            style: BODY_SECONDARY.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${widget.wallet.totalValue.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 36,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWalletStat('Total Assets', widget.wallet.totalAssets.toString()),
              _buildWalletStat('Stocks', widget.wallet.stockCount.toString()),
              _buildWalletStat('Bonds', widget.wallet.bondCount.toString()),
              _buildWalletStat('Commodities', widget.wallet.commodityCount.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildAllocationChart() {
    if (widget.wallet.totalValue == 0) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: cardDecoration(),
        child: Center(
          child: Text(
            'No assets in wallet',
            style: BODY_SECONDARY,
          ),
        ),
      );
    }

    final stocksPercent = (widget.wallet.stocksValue / widget.wallet.totalValue) * 100;
    final bondsPercent = (widget.wallet.bondsValue / widget.wallet.totalValue) * 100;
    final commoditiesPercent = (widget.wallet.commoditiesValue / widget.wallet.totalValue) * 100;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Asset Allocation', style: HEADING_MEDIUM),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  if (widget.wallet.stocksValue > 0)
                    PieChartSectionData(
                      value: stocksPercent,
                      title: '${stocksPercent.toStringAsFixed(1)}%',
                      color: COLOR_STOCKS,
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (widget.wallet.bondsValue > 0)
                    PieChartSectionData(
                      value: bondsPercent,
                      title: '${bondsPercent.toStringAsFixed(1)}%',
                      color: COLOR_BONDS,
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (widget.wallet.commoditiesValue > 0)
                    PieChartSectionData(
                      value: commoditiesPercent,
                      title: '${commoditiesPercent.toStringAsFixed(1)}%',
                      color: COLOR_COMMODITIES,
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        if (widget.wallet.stocksValue > 0)
          _buildLegendItem(
            color: COLOR_STOCKS,
            label: 'Stocks',
            value: widget.wallet.stocksValue,
            percent: (widget.wallet.stocksValue / widget.wallet.totalValue) * 100,
          ),
        if (widget.wallet.bondsValue > 0)
          _buildLegendItem(
            color: COLOR_BONDS,
            label: 'Bonds',
            value: widget.wallet.bondsValue,
            percent: (widget.wallet.bondsValue / widget.wallet.totalValue) * 100,
          ),
        if (widget.wallet.commoditiesValue > 0)
          _buildLegendItem(
            color: COLOR_COMMODITIES,
            label: 'Commodities',
            value: widget.wallet.commoditiesValue,
            percent: (widget.wallet.commoditiesValue / widget.wallet.totalValue) * 100,
          ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required double value,
    required double percent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: BODY_SECONDARY,
          ),
          const Spacer(),
          Text(
            '\$${value.toStringAsFixed(2)} (${percent.toStringAsFixed(1)}%)',
            style: BODY_PRIMARY.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetTypeBreakdown() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Asset Type Summary', style: HEADING_MEDIUM),
          const SizedBox(height: 16),
          _buildAssetTypeCard(
            'Stocks',
            widget.wallet.stockCount,
            widget.wallet.stocksValue,
            COLOR_STOCKS,
            Icons.show_chart,
          ),
          const SizedBox(height: 12),
          _buildAssetTypeCard(
            'Bonds',
            widget.wallet.bondCount,
            widget.wallet.bondsValue,
            COLOR_BONDS,
            Icons.account_balance,
          ),
          const SizedBox(height: 12),
          _buildAssetTypeCard(
            'Commodities',
            widget.wallet.commodityCount,
            widget.wallet.commoditiesValue,
            COLOR_COMMODITIES,
            Icons.eco,
          ),
        ],
      ),
    );
  }

  Widget _buildAssetTypeCard(
    String type,
    int count,
    double value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CARD_BACKGROUND_ELEVATED,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: HEADING_SMALL),
                const SizedBox(height: 4),
                Text(
                  '$count ${count == 1 ? 'asset' : 'assets'}',
                  style: BODY_SECONDARY,
                ),
              ],
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('All Assets', style: HEADING_MEDIUM),
          const SizedBox(height: 8),
          _buildFilterChips(),
          const SizedBox(height: 16),
          _buildFilteredAssetsList(),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Stocks', 'Bonds', 'Commodities'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedView == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedView = filter;
                });
              },
              backgroundColor: CARD_BACKGROUND_ELEVATED,
              selectedColor: ACCENT_GREEN,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : TEXT_SECONDARY,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilteredAssetsList() {
    List<WalletAsset> filteredAssets;

    switch (_selectedView) {
      case 'Stocks':
        filteredAssets = widget.wallet.stocks;
        break;
      case 'Bonds':
        filteredAssets = widget.wallet.bonds;
        break;
      case 'Commodities':
        filteredAssets = widget.wallet.commodities;
        break;
      default:
        filteredAssets = widget.wallet.assets;
    }

    if (filteredAssets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No ${_selectedView.toLowerCase()} in wallet',
            style: BODY_SECONDARY,
          ),
        ),
      );
    }

    return Column(
      children: filteredAssets.map((asset) => _buildAssetListItem(asset)).toList(),
    );
  }

  Widget _buildAssetListItem(WalletAsset asset) {
    Color typeColor;
    IconData typeIcon;
    String subtitle;

    switch (asset.type) {
      case AssetType.stock:
        final stockAsset = asset as StockAsset;
        typeColor = COLOR_STOCKS;
        typeIcon = Icons.show_chart;
        subtitle = '${stockAsset.quantity.toInt()} shares @ \$${stockAsset.currentValue.toStringAsFixed(2)}';
        break;
      case AssetType.bond:
        final bondAsset = asset as BondAsset;
        typeColor = COLOR_BONDS;
        typeIcon = Icons.account_balance;
        subtitle = '${bondAsset.quantity.toInt()} bonds • ${bondAsset.couponRate.toStringAsFixed(2)}% • ${bondAsset.maturityDate}';
        break;
      case AssetType.commodity:
        final commodityAsset = asset as CommodityAsset;
        typeColor = COLOR_COMMODITIES;
        typeIcon = Icons.eco;
        subtitle = '${commodityAsset.quantity.toStringAsFixed(2)} ${commodityAsset.unit} @ \$${commodityAsset.currentValue.toStringAsFixed(2)}';
        break;
      case AssetType.crypto:
        typeColor = const Color(0xFFF7931A);
        typeIcon = Icons.currency_bitcoin;
        subtitle = '${asset.quantity.toStringAsFixed(6)} coins @ \$${asset.currentValue.toStringAsFixed(2)}';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CARD_BACKGROUND_ELEVATED,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(typeIcon, color: typeColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name, 
                  style: HEADING_SMALL,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle, 
                  style: CAPTION_TEXT,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${asset.totalValue.toStringAsFixed(2)}',
                style: HEADING_SMALL,
              ),
              if (asset is StockAsset)
                Text(
                  formatChangeText(asset.change),
                  style: CAPTION_TEXT.copyWith(
                    color: getChangeColor(asset.change),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
