
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

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0C),
        title: const Text('About Dogonomics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Our Mission',
              'Dogonomics combines the loyalty of man\'s best friend with cutting-edge financial technology. I believe that investing shouldn\'t be intimidating or overwhelming.',
              Icons.flag,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'How?',
              'Using AI-powered sentiment analysis for financial markets using advanced machine learning models. Dogonomics analyzes news articles, social media, and market data to help you make informed investment decisions.',
              Icons.analytics,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Why Dogonomics?',
              'Just like dogs are known for their instincts and loyalty, our AI models are trained to sniff out market opportunities and stay faithful to delivering accurate sentiment analysis. Making complex financial data accessible and actionable.',
              Icons.pets,
            ),
            const SizedBox(height: 24),
            _buildTechStack(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF19B305), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechStack() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.code, color: Color(0xFF19B305), size: 24),
              const SizedBox(width: 12),
              const Text(
                'Technology Stack',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTechItem('Frontend', 'Flutter & Dart', Icons.phone_android),
          _buildTechItem('Backend', 'Go (Golang)', Icons.storage),
          _buildTechItem('AI/ML', 'FinBERT + ONNX Runtime', Icons.psychology),
          _buildTechItem('Database', 'Firebase Firestore', Icons.cloud),
          _buildTechItem('APIs', 'Finnhub Financial Data', Icons.api),
        ],
      ),
    );
  }

  Widget _buildTechItem(String category, String tech, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 20),
          const SizedBox(width: 12),
          Text(
            '$category: ',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            tech,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// How It Works Page
class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0C),
        title: const Text('How It Works'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildStep(
              1,
              'Data Collection',
              'Dogonomics gathers financial news articles, market data, and social sentiment from multiple sources including Finnhub API and other financial APIs',
              Icons.download,
              const Color(0xFF4CAF50),
            ),
            _buildArrow(),
            _buildStep(
              2,
              'FinBERT Analysis',
              'The FinBERT model, specifically trained on financial text, analyzes each piece of content for sentiment indicators.',
              Icons.psychology,
              const Color(0xFF2196F3),
            ),
            _buildArrow(),
            _buildStep(
              3,
              'ONNX Runtime',
              'Dogonomics leverages the ONNX (Open Neural Network Exchange) runtime for fast, efficient AI inference directly in our Go backend.',
              Icons.speed,
              const Color(0xFF9C27B0),
            ),
            _buildArrow(),
            _buildStep(
              4,
              'Sentiment Scoring',
              'Each article receives a sentiment score (positive, negative, neutral) with confidence levels and aggregated insights.',
              Icons.analytics,
              const Color(0xFFFF9800),
            ),
            _buildArrow(),
            _buildStep(
              5,
              'Portfolio Integration',
              'Sentiment data is integrated with your portfolio holdings to provide context-aware investment insights.',
              Icons.account_balance_wallet,
              const Color(0xFF19B305),
            ),
            const SizedBox(height: 32),
            _buildONNXInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int number, String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrow() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Icon(
        Icons.keyboard_arrow_down,
        color: Colors.grey[600],
        size: 32,
      ),
    );
  }

  Widget _buildONNXInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF19B305).withOpacity(0.1),
            const Color(0xFF23C00F).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF19B305).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info, color: Color(0xFF19B305), size: 24),
              const SizedBox(width: 12),
              const Text(
                'Why ONNX?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'ONNX (Open Neural Network Exchange) allows us to run machine learning models efficiently across different platforms. This means faster sentiment analysis, lower latency, and better performance for real-time financial insights.',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Support Creator Page
class SupportCreatorPage extends StatelessWidget {
  const SupportCreatorPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BACKG_COLOR,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0C),
        title: const Text('Support Creator'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Creator Profile
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF19B305).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    // radius: 50,
                    // backgroundColor: const Color(0xFF19B305),
                    child: Image.asset("./assets/images/Darispfp.jpg", fit:BoxFit.cover)
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Idirene Daris',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Creator & Developer',
                    style: TextStyle(
                      color: Color(0xFF19B305),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF050E14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Passionate about technology in all its forms — from software engineering and cloud computing to AI, electronics, and physics. I love building things that connect ideas with impact, whether it’s coding applications, designing hardware, or exploring how finance and science intersect. Currently pursuing my studies at Université Paris-Saclay.',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Social Links
            _buildSocialLinks(),
            const SizedBox(height: 24),
            
            // Support Section
            _buildSupportSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connect with me',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSocialLink(
            'GitHub',
            'View source code and contribute',
            Icons.code,
            Colors.grey[300]!,
            () {url.launchUrl(Uri.http('github.com', '/madebyDaris'));},
          ),
          _buildSocialLink(
            'Twitter',
            'Follow for updates and insights',
            Icons.alternate_email,
            const Color(0xFF1DA1F2),
            () {url.launchUrl(Uri.http('x.com', '/ByDaris'));},
          ),
          _buildSocialLink(
            'Blog',
            'Read about development journey',
            Icons.article,
            const Color(0xFF19B305),
            () {url.launchUrl(Uri.http('MadebyDaris.github.io'));},
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLink(String platform, String description, IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        platform,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  color: Colors.grey[600],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSupportSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Support the Project',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Dogonomics is a passion project built to make financial analysis more accessible. If you find it helpful, consider supporting its development!',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {url.launchUrl(Uri.http('patreon.com','/c/DarisIdirene'));},
              icon: const Icon(Icons.volunteer_activism),
              label: const Text('Support on Patreon'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF424D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}