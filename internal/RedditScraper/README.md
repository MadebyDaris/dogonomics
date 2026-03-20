# Reddit Scraper

This package provides functionality to scrape and aggregate content from Reddit, specifically targeting financial subreddits.

## Features

- **Subreddit Scraping**: Fetches "hot" posts from any specified subreddit.
- **Financial News Aggregation**: Aggregates posts from multiple financial subreddits:
  - r/finance
  - r/StockMarket
  - r/investing
  - r/stocks
  - r/wallstreetbets
  - r/Economics

## Usage

```go
scraper := RedditScraper.NewScraper()

// Fetch from a specific subreddit
posts, err := scraper.ScrapeSubreddit("golang", 10)

// Fetch aggregated financial news
posts, errors := scraper.GetFinancialNews(10)
```

## API Endpoints

The functionality is exposed via the following endpoints:

- `GET /social/reddit/financial`: Returns aggregated posts from financial subreddits.
- `GET /social/reddit/:subreddit`: Returns posts from a specific subreddit.

## Implementation Details

- Uses Reddit's JSON API (e.g., `https://www.reddit.com/r/subreddit/hot.json`).
- Sets a custom User-Agent to comply with Reddit's API rules.
- Does not require authentication (OAuth) for public read-only access, but rate limits apply.

## Future Improvements

- Add support for other sorting methods (new, top, rising).
- Implement proper OAuth2 authentication for higher rate limits.
- Add caching (Redis) to avoid hitting Reddit API too frequently.
- Add sentiment analysis on post titles/content using the existing FinBERT model.
