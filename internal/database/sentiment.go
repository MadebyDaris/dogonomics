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

// GetSentimentHistory retrieves sentiment history for a symbol
func GetSentimentHistory(ctx context.Context, symbol string, days int) ([]SentimentAnalysis, error) {
	if DB == nil {
		return nil, ErrDatabaseNotConnected
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
