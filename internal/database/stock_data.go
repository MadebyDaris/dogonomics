package database

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/DogonomicsFetching"
	"github.com/MadebyDaris/dogonomics/internal/DogonomicsProcessing"
	"github.com/MadebyDaris/dogonomics/internal/NewsClient"
	"github.com/MadebyDaris/dogonomics/sentAnalysis"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
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

// SaveCompanyProfile upserts a company profile into the database
func SaveCompanyProfile(ctx context.Context, symbol string, profile *DogonomicsProcessing.CompanyProfile) error {
	if DB == nil {
		return ErrDatabaseNotConnected
	}

	rawData, err := json.Marshal(profile)
	if err != nil {
		return err
	}

	query := `
		INSERT INTO company_profiles (symbol, name, country, currency, exchange, industry, market_cap, logo_url, website_url, raw_data)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		ON CONFLICT (symbol) DO UPDATE SET
			name = EXCLUDED.name,
			country = EXCLUDED.country,
			currency = EXCLUDED.currency,
			exchange = EXCLUDED.exchange,
			industry = EXCLUDED.industry,
			market_cap = EXCLUDED.market_cap,
			logo_url = EXCLUDED.logo_url,
			website_url = EXCLUDED.website_url,
			raw_data = EXCLUDED.raw_data,
			last_updated = NOW()
	`

	_, err = DB.Exec(ctx, query,
		symbol,
		profile.Name,
		profile.Country,
		profile.Currency,
		profile.Exchange,
		profile.FinnhubIndustry,
		int64(profile.MarketCap),
		profile.Logo,
		profile.WebURL,
		rawData,
	)

	return err
}

// GetCompanyProfile retrieves a company profile from the database
func GetCompanyProfile(ctx context.Context, symbol string) (*DogonomicsProcessing.CompanyProfile, error) {
	if DB == nil {
		return nil, ErrDatabaseNotConnected
	}

	query := `SELECT raw_data FROM company_profiles WHERE symbol = $1`

	var rawData []byte
	err := DB.QueryRow(ctx, query, symbol).Scan(&rawData)
	if err != nil {
		return nil, err
	}

	var profile DogonomicsProcessing.CompanyProfile
	if err := json.Unmarshal(rawData, &profile); err != nil {
		return nil, err
	}

	return &profile, nil
}

// SaveChartData saves a batch of historical chart data points efficiently using pgx Batch API
func SaveChartData(ctx context.Context, symbol string, data []DogonomicsProcessing.ChartDataPoint, source string) error {
	if DB == nil {
		return ErrDatabaseNotConnected
	}

	if len(data) == 0 {
		return nil
	}

	// Use batch API for efficient bulk insert
	batch := &pgx.Batch{}
	query := `
		INSERT INTO chart_data (symbol, date, open_price, high_price, low_price, close_price, volume, source)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT (symbol, date, source, fetched_at) DO NOTHING
	`

	for _, point := range data {
		batch.Queue(query,
			symbol,
			point.Timestamp.Format("2006-01-02"),
			point.Open,
			point.High,
			point.Low,
			point.Close,
			point.Volume,
			source,
		)
	}

	// Execute batch with timeout
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	results := DB.SendBatch(ctx, batch)
	defer results.Close()

	// Check results for errors
	for i := 0; i < batch.Len(); i++ {
		_, err := results.Exec()
		if err != nil {
			return fmt.Errorf("batch insert failed at row %d: %w", i, err)
		}
	}

	return nil
}

// SaveNewsArticle saves a generic news article (from NewsClient) to the database
func SaveNewsArticle(ctx context.Context, symbol string, article *NewsClient.NewsArticle) error {
	if DB == nil {
		return ErrDatabaseNotConnected
	}

	query := `
		INSERT INTO news_items (symbol, title, content, published_date, source, link)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (symbol, link, fetched_at) DO NOTHING
	`

	var content *string
	if article.Content != "" {
		content = &article.Content
	} else if article.Description != "" {
		content = &article.Description
	}

	_, err := DB.Exec(ctx, query,
		symbol,
		article.Title,
		content,
		article.PublishedAt,
		article.Source,
		article.URL,
	)

	return err
}

// SaveTickerData saves Polygon OHLC ticker data
func SaveTickerData(ctx context.Context, symbol string, data interface{}) error {
	if DB == nil {
		return ErrDatabaseNotConnected
	}

	rawData, err := json.Marshal(data)
	if err != nil {
		return err
	}

	query := `
		INSERT INTO stock_quotes (symbol, source, raw_data)
		VALUES ($1, $2, $3)
	`

	_, err = DB.Exec(ctx, query, symbol, "polygon", rawData)
	return err
}
