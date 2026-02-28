package database

import (
	"context"
	"encoding/json"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/DogonomicsFetching"
	"github.com/MadebyDaris/dogonomics/sentAnalysis"
	"github.com/google/uuid"
)

// SaveStockQuote saves a stock quote to the database
func SaveStockQuote(ctx context.Context, symbol string, quote *DogonomicsFetching.Quote) error {
	if DB == nil {
		return ErrDatabaseNotConnected
	}

	rawData, err := json.Marshal(quote)
	if err != nil {
		return err
	}

	query := `
		INSERT INTO stock_quotes (symbol, current_price, change, percent_change, high_price, low_price, open_price, previous_close, source, raw_data)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`

	_, err = DB.Exec(ctx, query,
		symbol,
		quote.CurrentPrice,
		quote.Change,
		quote.PercentChange,
		quote.HighPrice,
		quote.LowPrice,
		quote.OpenPrice,
		quote.PreviousClose,
		"finnhub",
		rawData,
	)

	return err
}

// SaveNewsWithSentiment saves a news item from sentAnalysis package and returns the generated ID
func SaveNewsWithSentiment(ctx context.Context, symbol string, news *sentAnalysis.NewsItem) (uuid.UUID, error) {
	if DB == nil {
		return uuid.Nil, ErrDatabaseNotConnected
	}

	// Parse the date string to time.Time
	var publishedDate *time.Time
	if news.Date != "" {
		if parsed, err := time.Parse(time.RFC3339, news.Date); err == nil {
			publishedDate = &parsed
		} else if parsed, err := time.Parse("2006-01-02", news.Date); err == nil {
			publishedDate = &parsed
		}
	}

	// Extract source from link if available
	var source *string
	if news.Link != "" {
		src := news.Link
		source = &src
	}

	query := `
		INSERT INTO news_items (symbol, title, content, published_date, source, link, tags)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		ON CONFLICT (symbol, link, fetched_at) DO UPDATE SET
			title = EXCLUDED.title,
			content = EXCLUDED.content
		RETURNING id
	`

	var id uuid.UUID
	var content *string
	if news.Content != "" {
		content = &news.Content
	}

	err := DB.QueryRow(ctx, query,
		symbol,
		news.Title,
		content,
		publishedDate,
		source,
		news.Link,
		news.Tags,
	).Scan(&id)

	return id, err
}

// SaveNewsSentiment saves BERT sentiment analysis results for a news item
func SaveNewsSentiment(ctx context.Context, newsItemID uuid.UUID, news *sentAnalysis.NewsItem) error {
	if DB == nil {
		return ErrDatabaseNotConnected
	}

	// Extract symbol from news.Symbols array
	symbol := ""
	if len(news.Symbols) > 0 {
		symbol = news.Symbols[0]
	}

	query := `
		INSERT INTO sentiment_analysis (
			news_item_id, symbol, bert_label, bert_confidence, bert_score,
			polarity, positive_score, neutral_score, negative_score,
			model_version
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`

	_, err := DB.Exec(ctx, query,
		newsItemID,
		symbol,
		news.BERTSentiment.Label,
		news.BERTSentiment.Confidence,
		news.BERTSentiment.Score,
		news.Sentiment.Polarity,
		news.Sentiment.Pos,
		news.Sentiment.Neu,
		news.Sentiment.Neg,
		"FinBERT-ONNX",
	)

	return err
}

// SaveAggregatedSentiment saves aggregate sentiment analysis for a symbol
func SaveAggregatedSentiment(ctx context.Context, symbol string, aggregate *sentAnalysis.StockSentimentAnalysis) error {
	if DB == nil {
		return ErrDatabaseNotConnected
	}

	// Use 24-hour period ending now
	now := time.Now()
	periodEnd := now
	periodStart := now.Add(-24 * time.Hour)

	query := `
		INSERT INTO aggregate_sentiment (
			symbol, period_start, period_end, overall_sentiment, confidence,
			news_count, positive_ratio, neutral_ratio, negative_ratio, recommendation
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		ON CONFLICT (symbol, period_start, period_end) DO UPDATE SET
			overall_sentiment = EXCLUDED.overall_sentiment,
			confidence = EXCLUDED.confidence,
			news_count = EXCLUDED.news_count,
			positive_ratio = EXCLUDED.positive_ratio,
			neutral_ratio = EXCLUDED.neutral_ratio,
			negative_ratio = EXCLUDED.negative_ratio,
			recommendation = EXCLUDED.recommendation,
			analyzed_at = NOW()
	`

	_, err := DB.Exec(ctx, query,
		symbol,
		periodStart,
		periodEnd,
		aggregate.OverallSentiment,
		aggregate.Confidence,
		aggregate.NewsCount,
		aggregate.PositiveRatio,
		aggregate.NeutralRatio,
		aggregate.NegativeRatio,
		aggregate.Recommendation,
	)

	return err
}

// GetSymbolSentimentTrend retrieves sentiment trend using the PostgreSQL function
func GetSymbolSentimentTrend(ctx context.Context, symbol string, days int) ([]map[string]interface{}, error) {
	if DB == nil {
		return nil, ErrDatabaseNotConnected
	}

	query := `SELECT * FROM get_sentiment_trend($1, $2)`

	rows, err := DB.Query(ctx, query, symbol, days)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var date time.Time
		var avgSentiment, avgConfidence *float64
		var newsCount int

		if err := rows.Scan(&date, &avgSentiment, &avgConfidence, &newsCount); err != nil {
			return nil, err
		}

		results = append(results, map[string]interface{}{
			"date":           date,
			"avg_sentiment":  avgSentiment,
			"avg_confidence": avgConfidence,
			"news_count":     newsCount,
		})
	}

	return results, rows.Err()
}
