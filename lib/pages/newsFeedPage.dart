import 'dart:async';
import 'package:Dogonomics/backend/dogonomicsApi.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:Dogonomics/widgets/stockDetailsWidgets.dart';
import 'package:Dogonomics/widgets/finbertInferenceDialog.dart';
import 'package:flutter/material.dart';

class NewsFeedPage extends StatefulWidget {
  final String? symbol; // optional symbol filter

  const NewsFeedPage({Key? key, this.symbol}) : super(key: key);

  @override
  _NewsFeedPageState createState() => _NewsFeedPageState();
}

class _NewsFeedPageState extends State<NewsFeedPage> {
  bool isLoading = true;
  String? error;
  List<NewsItem> news = [];

  // Search
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  String _searchQuery = '';

  // Sentiment toggle
  bool _showSentimentAnalyzed = false;
  NewsWithSentimentResponse? _sentimentResponse;
  bool _isLoadingSentiment = false;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadNews() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final List<NewsItem> fetched;
      if (widget.symbol != null && widget.symbol!.isNotEmpty) {
        fetched = await DogonomicsAPI.fetchNewsBySymbol(widget.symbol!);
      } else {
        fetched = await DogonomicsAPI.fetchNewsFeed();
      }

      if (mounted) {
        setState(() {
          news = fetched;
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

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isEmpty) {
        setState(() {
          _searchQuery = '';
          _isSearching = false;
        });
        _loadNews();
      } else {
        _performSearch(query.trim());
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _searchQuery = query;
      isLoading = true;
      error = null;
    });

    try {
      final results = await DogonomicsAPI.searchNews(query, limit: 20);
      if (mounted) {
        setState(() {
          news = results;
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

  Future<void> _loadSentimentNews() async {
    setState(() {
      _isLoadingSentiment = true;
    });

    try {
      final response = await DogonomicsAPI.fetchNewsWithSentiment(limit: 10);
      if (mounted) {
        setState(() {
          _sentimentResponse = response;
          _isLoadingSentiment = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSentiment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sentiment analysis failed: ${e.toString()}'),
            backgroundColor: COLOR_NEGATIVE,
          ),
        );
      }
    }
  }

  void _toggleSentimentMode(bool value) {
    setState(() {
      _showSentimentAnalyzed = value;
    });
    if (value && _sentimentResponse == null) {
      _loadSentimentNews();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: APP_BACKGROUND,
      appBar: AppBar(
        backgroundColor: APP_BACKGROUND,
        elevation: 0,
        leading: widget.symbol != null 
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          widget.symbol != null ? '${widget.symbol} News' : 'Market News',
          style: HEADING_MEDIUM,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.psychology_outlined, color: ACCENT_GREEN),
            tooltip: 'FinBERT Analysis',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => FinBertInferenceDialog(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: BODY_PRIMARY,
              decoration: InputDecoration(
                hintText: 'Search news...',
                hintStyle: BODY_SECONDARY,
                prefixIcon: Icon(Icons.search, color: TEXT_SECONDARY),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: TEXT_SECONDARY),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: CARD_BACKGROUND,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: BORDER_COLOR),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: BORDER_COLOR),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ACCENT_GREEN),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Sentiment toggle (only for general news, not symbol-specific)
          if (widget.symbol == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 18,
                    color: _showSentimentAnalyzed ? ACCENT_GREEN : TEXT_SECONDARY,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI Sentiment Analysis',
                    style: BODY_SECONDARY.copyWith(
                      color: _showSentimentAnalyzed ? ACCENT_GREEN : TEXT_SECONDARY,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _showSentimentAnalyzed,
                    onChanged: _toggleSentimentMode,
                    activeColor: ACCENT_GREEN,
                  ),
                ],
              ),
            ),

          // Aggregate sentiment banner
          if (_showSentimentAnalyzed && _sentimentResponse != null)
            _buildAggregateBanner(_sentimentResponse!.aggregateSentiment),

          // News list
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_showSentimentAnalyzed) {
      if (_isLoadingSentiment) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: ACCENT_GREEN),
              const SizedBox(height: 12),
              Text('Running AI sentiment analysis...', style: BODY_SECONDARY),
              Text('This may take a moment', style: CAPTION_TEXT),
            ],
          ),
        );
      }

      if (_sentimentResponse == null || _sentimentResponse!.articles.isEmpty) {
        return _buildEmpty();
      }

      return RefreshIndicator(
        onRefresh: _loadSentimentNews,
        child: ListView.separated(
          itemCount: _sentimentResponse!.articles.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final article = _sentimentResponse!.articles[index];
            return _buildSentimentArticleCard(article);
          },
        ),
      );
    }

    // Regular news mode
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: ACCENT_GREEN));
    }
    if (error != null) {
      return _buildError();
    }
    if (news.isEmpty) {
      return _buildEmpty();
    }
    return RefreshIndicator(
      onRefresh: _searchQuery.isNotEmpty ? () => _performSearch(_searchQuery) : _loadNews,
      child: ListView.separated(
        itemCount: news.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return NewsCard(newsItem: news[index]);
        },
      ),
    );
  }

  Widget _buildAggregateBanner(AggregateSentiment agg) {
    final isPositive = agg.averageScore >= 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Market Mood: ${isPositive ? "Positive" : "Negative"}',
                  style: BODY_PRIMARY.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Avg Score: ${agg.averageScore.toStringAsFixed(2)} | Confidence: ${(agg.averageConfidence * 100).toStringAsFixed(0)}%',
                  style: CAPTION_TEXT,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentArticleCard(NewsArticleWithSentiment article) {
    final sentimentLabel = article.sentiment?.label ?? 'neutral';
    final sentimentColor = sentimentLabel.toLowerCase() == 'positive'
        ? COLOR_POSITIVE
        : sentimentLabel.toLowerCase() == 'negative'
            ? COLOR_NEGATIVE
            : TEXT_DISABLED;
    final confidence = article.sentiment?.confidence ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CARD_BACKGROUND,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BORDER_COLOR),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  article.title,
                  style: BODY_PRIMARY.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sentimentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sentimentLabel.toUpperCase(),
                  style: TextStyle(
                    color: sentimentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (article.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              article.description,
              style: BODY_SECONDARY,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                article.source.isNotEmpty ? article.source : 'Unknown source',
                style: CAPTION_TEXT,
              ),
              Row(
                children: [
                  Icon(Icons.analytics_outlined, size: 14, color: TEXT_SECONDARY),
                  const SizedBox(width: 4),
                  Text(
                    '${(confidence * 100).toStringAsFixed(1)}% confident',
                    style: CAPTION_TEXT,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: COLOR_NEGATIVE, size: 48),
          const SizedBox(height: 12),
          Text('Failed to load news', style: HEADING_SMALL),
          const SizedBox(height: 8),
          Text(error ?? '', style: BODY_SECONDARY, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ACCENT_GREEN),
            onPressed: _loadNews,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.newspaper, size: 64, color: TEXT_DISABLED),
          const SizedBox(height: 12),
          Text('No news articles found', style: HEADING_SMALL),
          const SizedBox(height: 8),
          Text('Try a different search or refresh the feed.', style: BODY_SECONDARY),
        ],
      ),
    );
  }
}
