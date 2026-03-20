import 'dart:async';
import 'package:Dogonomics/backend/dogonomicsApi.dart';
import 'package:Dogonomics/backend/providers.dart';
import 'package:Dogonomics/utils/constant.dart';
import 'package:Dogonomics/widgets/doggo_sidebar_widget.dart';
import 'package:Dogonomics/widgets/explain_tooltip_widget.dart';
import 'package:Dogonomics/widgets/stockDetailsWidgets.dart';
import 'package:Dogonomics/widgets/finbertInferenceDialog.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:Dogonomics/widgets/doggo_inline_insight.dart';

class NewsFeedPage extends StatefulWidget {
  final String? symbol; // optional symbol filter

  const NewsFeedPage({Key? key, this.symbol}) : super(key: key);

  @override
  _NewsFeedPageState createState() => _NewsFeedPageState();
}

class _NewsFeedPageState extends State<NewsFeedPage> {
  final RouteProvider _routeProvider = RouteProvider();
  final MetricExplanationProvider _explanationProvider = MetricExplanationProvider();
  bool isLoading = true;
  String? error;
  List<NewsItem> news = [];

  // Search
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';

  // Sentiment toggle
  bool _showSentimentAnalyzed = false;
  NewsWithSentimentResponse? _sentimentResponse;
  bool _isLoadingSentiment = false;
  List<RedditPost> _redditPosts = [];
  bool _isLoadingReddit = false;

  @override
  void initState() {
    super.initState();
    _loadNews();
    if (widget.symbol == null) {
      _loadRedditPulse();
    }
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
        });
        _loadNews();
      } else {
        _performSearch(query.trim());
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
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

  Future<void> _loadRedditPulse() async {
    if (widget.symbol != null) return;

    setState(() {
      _isLoadingReddit = true;
    });

    try {
      final posts = await DogonomicsAPI.fetchRedditFinancialNews(limit: 8);
      if (!mounted) return;
      setState(() {
        _redditPosts = posts;
        _isLoadingReddit = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingReddit = false;
      });
    }
  }

  Future<void> _refreshRegularMode() async {
    await _loadNews();
    if (widget.symbol == null) {
      await _loadRedditPulse();
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
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'Analyze Sentiment',
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
          
          if (widget.symbol == null)
            const DoggoInlineInsightWidget(
              context: 'News',
              prompt: 'Please summarize the key current financial headlines for the day into 3 bullet points.',
            ),

          // Sentiment toggle (only for general news, not symbol-specific)
          if (widget.symbol == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: _showSentimentAnalyzed ? ACCENT_GREEN : TEXT_SECONDARY,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sentiment Analysis Mode',
                    style: BODY_SECONDARY.copyWith(
                      color: _showSentimentAnalyzed ? ACCENT_GREEN : TEXT_SECONDARY,
                      fontWeight: _showSentimentAnalyzed ? FontWeight.w600 : FontWeight.normal,
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

          if (widget.symbol == null)
            _buildRedditPulseSection(),

          // News list
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SidebarScaffold(
                currentRoute: '/news_feed',
                currentSymbol: widget.symbol,
                routeProvider: _routeProvider,
                explanationProvider: _explanationProvider,
                contextData: {
                  'sentimentMode': _showSentimentAnalyzed,
                  'query': _searchQuery,
                },
                body: _buildBody(),
              ),
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
              const Icon(Icons.insights_outlined, size: 44, color: ACCENT_GREEN_LIGHT),
              const SizedBox(height: 12),
              const CircularProgressIndicator(color: ACCENT_GREEN),
              const SizedBox(height: 12),
              Text('Analyzing headline sentiment...', style: BODY_SECONDARY),
              const SizedBox(height: 4),
              Text('Preparing signal confidence scores', style: CAPTION_TEXT),
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
      onRefresh: _searchQuery.isNotEmpty
          ? () => _performSearch(_searchQuery)
          : _refreshRegularMode,
      child: ListView.separated(
        itemCount: news.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return NewsCard(newsItem: news[index]);
        },
      ),
    );
  }

  Widget _buildRedditPulseSection() {
    if (_isLoadingReddit) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: LinearProgressIndicator(minHeight: 2, color: ACCENT_GREEN),
      );
    }

    if (_redditPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CARD_BACKGROUND,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BORDER_COLOR),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_outlined, color: ACCENT_GREEN_LIGHT, size: 18),
              const SizedBox(width: 8),
              Text(
                'Reddit Pulse',
                style: BODY_PRIMARY.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${_redditPosts.length} posts',
                style: CAPTION_TEXT,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._redditPosts.take(3).map(_buildRedditPulseCard),
        ],
      ),
    );
  }

  Widget _buildRedditPulseCard(RedditPost post) {
    final subtitle = post.selfText.trim().isNotEmpty
        ? post.selfText.trim()
        : 'u/${post.author} in r/${post.subreddit}';

    return InkWell(
      onTap: () => _openRedditPost(post),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 38,
              decoration: BoxDecoration(
                color: ACCENT_GREEN.withOpacity(0.5),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BODY_PRIMARY.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CAPTION_TEXT,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Up ${post.upvotes}', style: CAPTION_TEXT),
                Text('Cmts ${post.comments}', style: CAPTION_TEXT),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRedditPost(RedditPost post) async {
    final String target = post.url.trim().isNotEmpty
        ? post.url.trim()
        : 'https://www.reddit.com${post.permalink}';
    final uri = Uri.tryParse(target);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildAggregateBanner(AggregateSentiment agg) {
    final isPositive = agg.averageScore >= 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE).withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE).withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            size: 22,
            color: isPositive ? COLOR_POSITIVE : COLOR_NEGATIVE,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isPositive ? 'Market Sentiment: Positive' : 'Market Sentiment: Negative',
                      style: BODY_PRIMARY.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    ExplainTooltipWidget(
                      metricName: 'Aggregate Sentiment Score',
                      metricValue: agg.averageScore.toStringAsFixed(2),
                      iconSize: 13,
                    ),
                  ],
                ),
                Text(
                  'Avg Score: ${agg.averageScore.toStringAsFixed(2)} • Confidence: ${(agg.averageConfidence * 100).toStringAsFixed(0)}%',
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
        border: Border(
          left: BorderSide(color: sentimentColor, width: 3),
          top: BorderSide(color: BORDER_COLOR),
          right: BorderSide(color: BORDER_COLOR),
          bottom: BorderSide(color: BORDER_COLOR),
        ),
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
                  style: BODY_PRIMARY.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sentimentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sentimentColor.withOpacity(0.4)),
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
                  const Icon(Icons.auto_awesome, size: 14, color: TEXT_SECONDARY),
                  const SizedBox(width: 4),
                  Text(
                    '${(confidence * 100).toStringAsFixed(1)}% confidence',
                    style: CAPTION_TEXT,
                  ),
                  const SizedBox(width: 6),
                  ExplainTooltipWidget(
                    metricName: 'Sentiment Confidence',
                    metricValue: '${(confidence * 100).toStringAsFixed(1)}%',
                    iconSize: 12,
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
          const Icon(Icons.newspaper_outlined, size: 52, color: TEXT_SECONDARY),
          const SizedBox(height: 12),
          Text('No news available', style: HEADING_SMALL),
          const SizedBox(height: 8),
          Text('Try a different search or refresh the feed.', style: BODY_SECONDARY),
        ],
      ),
    );
  }
}
