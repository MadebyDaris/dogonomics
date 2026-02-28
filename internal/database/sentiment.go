package database

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// NewsItem represents a news article
type NewsItem struct {
	ID            uuid.UUID
	Symbol        string
	Title         string
	Content       *string
	PublishedDate *time.Time
	Source        *string
	Link          *string
	FetchedAt     time.Time
	Tags          []string
}

// SentimentAnalysis represents sentiment analysis results
type SentimentAnalysis struct {
	ID              uuid.UUID
	NewsItemID      *uuid.UUID
	Symbol          string
	AnalyzedAt      time.Time
	BERTLabel       *string
	BERTConfidence  *float64
	BERTScore       *float64
	Polarity        *float64
	PositiveScore   *float64
	NeutralScore    *float64
	NegativeScore   *float64
	ModelVersion    *string
	InferenceTimeMS *int
}

// AggregateSentiment represents aggregate sentiment for a symbol over a period
type AggregateSentiment struct {
	ID               uuid.UUID
	Symbol           string
	AnalyzedAt       time.Time
	PeriodStart      time.Time
	PeriodEnd        time.Time
	OverallSentiment *float64
	Confidence       *float64
	NewsCount        int
	PositiveRatio    *float64
	NeutralRatio     *float64
	NegativeRatio    *float64
	Recommendation   *string
}

// SaveNewsItem saves a news item to the database
func SaveNewsItem(ctx context.Context, news *NewsItem) (uuid.UUID, error) {
	if DB == nil {
		return uuid.Nil, nil
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
	err := DB.QueryRow(ctx, query,
		news.Symbol,
		news.Title,
		news.Content,
		news.PublishedDate,
		news.Source,
		news.Link,
		news.Tags,
	).Scan(&id)

	return id, err
}

// SaveSentimentAnalysis saves sentiment analysis results
func SaveSentimentAnalysis(ctx context.Context, sentiment *SentimentAnalysis) error {
	if DB == nil {
		return nil
	}

	query := `
		INSERT INTO sentiment_analysis (
			news_item_id, symbol, bert_label, bert_confidence, bert_score,
			polarity, positive_score, neutral_score, negative_score,
			model_version, inference_time_ms
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`

	_, err := DB.Exec(ctx, query,
		sentiment.NewsItemID,
		sentiment.Symbol,
		sentiment.BERTLabel,
		sentiment.BERTConfidence,
		sentiment.BERTScore,
		sentiment.Polarity,
		sentiment.PositiveScore,
		sentiment.NeutralScore,
		sentiment.NegativeScore,
		sentiment.ModelVersion,
		sentiment.InferenceTimeMS,
	)

	return err
}

// SaveAggregateSentiment saves aggregate sentiment analysis
func SaveAggregateSentiment(ctx context.Context, agg *AggregateSentiment) error {
	if DB == nil {
		return nil
	}

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
		agg.Symbol,
		agg.PeriodStart,
		agg.PeriodEnd,
		agg.OverallSentiment,
		agg.Confidence,
		agg.NewsCount,
		agg.PositiveRatio,
		agg.NeutralRatio,
		agg.NegativeRatio,
		agg.Recommendation,
	)

	return err
}

// GetSentimentHistory retrieves sentiment history for a symbol
func GetSentimentHistory(ctx context.Context, symbol string, days int) ([]SentimentAnalysis, error) {
	if DB == nil {
		return nil, nil
	}

	query := `
		SELECT id, news_item_id, symbol, analyzed_at, bert_label, bert_confidence,
		       bert_score, polarity, positive_score, neutral_score, negative_score
		FROM sentiment_analysis
		WHERE symbol = $1
		  AND analyzed_at >= NOW() - ($2 || ' days')::INTERVAL
		ORDER BY analyzed_at DESC
	`

	rows, err := DB.Query(ctx, query, symbol, days)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []SentimentAnalysis
	for rows.Next() {
		var sa SentimentAnalysis
		err := rows.Scan(
			&sa.ID,
			&sa.NewsItemID,
			&sa.Symbol,
			&sa.AnalyzedAt,
			&sa.BERTLabel,
			&sa.BERTConfidence,
			&sa.BERTScore,
			&sa.Polarity,
			&sa.PositiveScore,
			&sa.NeutralScore,
			&sa.NegativeScore,
		)
		if err != nil {
			return nil, err
		}
		results = append(results, sa)
	}

	return results, rows.Err()
}

// GetSentimentTrend calls the database function to get sentiment trend
func GetSentimentTrend(ctx context.Context, symbol string, days int) ([]map[string]interface{}, error) {
	if DB == nil {
		return nil, nil
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
		var count int64

		err := rows.Scan(&date, &avgSentiment, &avgConfidence, &count)
		if err != nil {
			return nil, err
		}

		results = append(results, map[string]interface{}{
			"date":           date,
			"avg_sentiment":  avgSentiment,
			"avg_confidence": avgConfidence,
			"analysis_count": count,
		})
	}

	return results, rows.Err()
}
