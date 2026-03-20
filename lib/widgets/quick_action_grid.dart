import 'package:flutter/material.dart';
import '../utils/constant.dart';

class QuickActionGrid extends StatelessWidget {
  final VoidCallback onAddAsset;
  final VoidCallback onAiInsights;
  final VoidCallback onNewsFeed;
  final VoidCallback onMarketIndic;
  final VoidCallback onSocialSentiment;
  final VoidCallback onPortfolioAnalysis;

  const QuickActionGrid({
    super.key,
    required this.onAddAsset,
    required this.onAiInsights,
    required this.onNewsFeed,
    required this.onMarketIndic,
    required this.onSocialSentiment,
    required this.onPortfolioAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Discover & Actions',
            style: HEADING_MEDIUM,
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: [
            _buildActionCard(
              context,
              'Add Asset',
              Icons.add_circle_outline,
              Colors.blueAccent,
              onAddAsset,
            ),
            _buildActionCard(
              context,
              'AI Advice',
              Icons.psychology,
              Colors.purpleAccent,
              onAiInsights,
            ),
            _buildActionCard(
              context,
              'News Feed',
              Icons.newspaper,
              Colors.orangeAccent,
              onNewsFeed,
            ),
            _buildActionCard(
              context,
              'Market',
              Icons.analytics,
              Colors.tealAccent,
              onMarketIndic,
            ),
            _buildActionCard(
              context,
              'Social',
              Icons.public,
              Colors.pinkAccent,
              onSocialSentiment,
            ),
            _buildActionCard(
              context,
              'Analysis',
              Icons.pie_chart,
              Colors.greenAccent,
              onPortfolioAnalysis,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: CARD_BACKGROUND,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BORDER_COLOR),
          gradient: LinearGradient(
            colors: [
              CARD_BACKGROUND,
              color.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TEXT_PRIMARY,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
