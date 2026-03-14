# News & FinBERT Integration Guide

## Overview
The Dogonomics frontend now integrates with your backend's news and FinBERT sentiment analysis endpoints.

## Features Added

### 1. News Feed Tab
- **Location**: Main navigation (second tab after Stocks)
- **Functionality**: Displays global financial news feed
- **Access**: Click the "News" tab in the main app navigation

### 2. Symbol-Specific News
- **Location**: Stock details page → Sentiment tab → "View all news" button
- **Functionality**: Shows news filtered for a specific stock symbol
- **Access**: View any stock → Go to Sentiment tab → Click "View all news"

### 3. FinBERT Sentiment Analysis Tool
- **Location**: News feed page (brain icon in AppBar)
- **Functionality**: Analyze custom financial text for sentiment
- **Access**: News tab → Click brain icon (ψ) in top-right corner

## Backend Endpoints Required

### News Endpoints
The frontend tries multiple common patterns for news endpoints:

```
GET /news?limit={number}              # General news feed
GET /news/{symbol}?limit={number}     # Symbol-specific news
GET /news?symbol={symbol}&limit={number}  # Alternative format
```

**Response Format Expected:**
```json
[
  {
    "title": "string",
    "content": "string",
    "date": "string",
    "bert_sentiment": {
      "label": "positive|negative|neutral",
      "confidence": 0.95,
      "score": 0.85
    }
  }
]
```

Or wrapped in a data object:
```json
{
  "data": [ /* NewsItem array */ ]
}
```

### FinBERT Inference Endpoint
```
POST /finbert/inference
Content-Type: application/json

{
  "text": "Your financial text to analyze"
}
```

**Response Format Expected:**
```json
{
  "label": "positive|negative|neutral",
  "confidence": 0.95,
  "score": 0.85
}
```

## API Implementation

### DogonomicsAPI Methods

#### `fetchNewsFeed({int limit = 50})`
Fetches general market news feed.

```dart
final news = await DogonomicsAPI.fetchNewsFeed(limit: 100);
```

#### `fetchNewsBySymbol(String symbol, {int limit = 100})`
Fetches news for a specific stock symbol.

```dart
final appleNews = await DogonomicsAPI.fetchNewsBySymbol('AAPL', limit: 50);
```

#### `runFinBertInference(String text)`
Runs sentiment analysis on custom text.

```dart
final sentiment = await DogonomicsAPI.runFinBertInference(
  'Apple reported strong quarterly earnings...'
);
print('Sentiment: ${sentiment.label}');
print('Confidence: ${sentiment.confidence}');
```

## UI Components

### NewsFeedPage
Displays news in a scrollable list with:
- Loading state
- Error handling with retry
- Empty state
- Pull-to-refresh
- FinBERT analysis button in AppBar

```dart
// Global news feed
Navigator.push(context, MaterialPageRoute(
  builder: (context) => NewsFeedPage()
));

// Symbol-filtered news
Navigator.push(context, MaterialPageRoute(
  builder: (context) => NewsFeedPage(symbol: 'AAPL')
));
```

### FinBertInferenceDialog
Interactive dialog for sentiment analysis with:
- Multi-line text input
- Real-time analysis
- Visual sentiment results
- Confidence metrics
- Color-coded sentiment (green=positive, red=negative, orange=neutral)

```dart
showDialog(
  context: context,
  builder: (context) => FinBertInferenceDialog()
);
```

### FinBertInferencePage
Full-page version for more space:

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (context) => FinBertInferencePage()
));
```

## Backend Setup Notes

### If your endpoints are different:
Update `lib/backend/dogonomicsApi.dart`:

```dart
static const String baseUrl = 'http://YOUR_IP:8080';

// Adjust endpoint paths if needed
static Future<List<NewsItem>> fetchNewsFeed({int limit = 50}) async {
  final response = await http.get(
    Uri.parse('$baseUrl/YOUR_NEWS_PATH?limit=$limit'),  // ← Change this
    ...
  );
  ...
}
```

### Expected Backend Routes (Update as needed)
- `GET /news?limit=50` - General news feed
- `GET /news/{symbol}?limit=100` - Symbol-specific news
- `POST /finbert/inference` - FinBERT sentiment analysis

### Database Schema (Reference)
Your backend likely uses these tables:
- `news_items` - Stores news articles
- `bert_sentiment` - Stores sentiment analysis results
- `sentiment_aggregates` - Aggregated sentiment by symbol

## Testing

### Test News Feed
1. Run the app
2. Navigate to "News" tab
3. Should see list of news articles
4. Pull down to refresh

### Test Symbol News
1. Go to any stock (e.g., AAPL)
2. Navigate to "Sentiment" tab
3. Click "View all news" button
4. Should see AAPL-specific news

### Test FinBERT Inference
1. Go to News tab
2. Click brain icon (ψ) in top-right
3. Enter text: "Tesla stock surged after strong earnings report"
4. Click "Analyze Sentiment"
5. Should see positive sentiment with confidence score

## Error Handling

All API calls include:
- 30-60 second timeouts
- Try-catch error handling
- User-friendly error messages
- Retry buttons on failures

### Common Errors

**"No response from news endpoints"**
- Backend not running or wrong IP/port
- Check `baseUrl` in `dogonomicsApi.dart`

**"FinBERT inference error"**
- Backend inference endpoint not available
- Check `/finbert/inference` route exists
- Verify ONNX runtime is set up on backend

**"Failed to load news feed: 404"**
- Endpoint path mismatch
- Check your backend routes match expected paths

## Future Enhancements

Potential additions:
- [ ] News source filtering
- [ ] Date range filtering
- [ ] Sentiment-based filtering
- [ ] Search functionality
- [ ] Save favorite articles
- [ ] Share news articles
- [ ] Batch sentiment analysis
- [ ] News alerts/notifications

## Architecture

```
Frontend (Flutter)
├── lib/pages/
│   ├── newsFeedPage.dart           # News list UI
│   └── frontpage.dart              # Main nav with News tab
├── lib/widgets/
│   ├── finbertInferenceDialog.dart # Sentiment analysis UI
│   └── stockDetailsWidgets.dart    # NewsCard, NewsList
└── lib/backend/
    └── dogonomicsApi.dart          # API client

Backend (Go)
├── /news?limit=N                   # News feed endpoint
├── /news/{symbol}                  # Symbol news endpoint
└── /finbert/inference              # FinBERT analysis endpoint
```

## Data Models

### NewsItem
```dart
class NewsItem {
  final String title;
  final String content;
  final String date;
  final BERTSentiment bertSentiment;
}
```

### BERTSentiment
```dart
class BERTSentiment {
  final String label;       // positive, negative, neutral
  final double confidence;  // 0.0 to 1.0
  final double score;       // sentiment score
}
```

## Summary

✅ News feed accessible from main navigation  
✅ Symbol-specific news from stock details  
✅ FinBERT inference tool with dialog UI  
✅ Complete error handling and loading states  
✅ Pull-to-refresh functionality  
✅ Standardized design with app theme  

The integration is ready! Just ensure your backend endpoints match the expected routes and response formats.
