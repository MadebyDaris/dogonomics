package sentAnalysis

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"

	"github.com/MadebyDaris/dogonomics/BertInference"
	"github.com/MadebyDaris/dogonomics/internal/workerpool"
)

var apiKey = os.Getenv("EODHD_API_KEY")

type Sentiment struct {
	Polarity float64 `json:"polarity"`
	Neg      float64 `json:"neg"`
	Neu      float64 `json:"neu"`
	Pos      float64 `json:"pos"`
}

type StockSentimentAnalysis struct {
	Symbol           string  `json:"symbol"`
	OverallSentiment float64 `json:"overall_sentiment"` // -1.0 to 1.0
	Confidence       float64 `json:"confidence"`
	NewsCount        int     `json:"news_count"`
	PositiveRatio    float64 `json:"positive_ratio"`
	NeutralRatio     float64 `json:"neutral_ratio"`
	NegativeRatio    float64 `json:"negative_ratio"`
	Recommendation   string  `json:"recommendation"`
}

type NewsItem struct {
	Title         string                      `json:"title"`
	Content       string                      `json:"content"`
	Date          string                      `json:"date"`
	Link          string                      `json:"link"`
	Sentiment     Sentiment                   `json:"sentiment"`
	BERTSentiment BertInference.BERTSentiment `json:"bert_sentiment"` // <-- FinBERT sentiment*
	Symbols       []string                    `json:"symbols"`
	Tags          []string                    `json:"tags"`
}

func FetchData(ctx context.Context, symbol string) ([]NewsItem, error) {
	endpoint := "https://eodhd.com/api/news"
	params := url.Values{}
	params.Set("api_token", apiKey)
	params.Set("s", symbol)
	params.Set("limit", "4")
	fullURL := fmt.Sprintf("%s?%s", endpoint, params.Encode())

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fullURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}

	resp, respErr := http.DefaultClient.Do(req)
	if respErr != nil {
		return nil, respErr
	}
	defer resp.Body.Close()
	body, _err := io.ReadAll(resp.Body)
	var news []NewsItem

	_err = json.Unmarshal(body, &news)

	if _err != nil {
		log.Fatal(_err)
	}

	return news, nil
}

func AnalyzeNews(title string, content string) (*BertInference.BERTSentiment, error) {
	fullText := fmt.Sprintf("%s. %s", title, content)
	text := preprocessText(fullText)

	maxLength := 400
	if len(fullText) > maxLength {
		fullText = fullText[:maxLength]
		if lastPeriod := strings.LastIndex(fullText, "."); lastPeriod > 400 {
			fullText = fullText[:lastPeriod+1]
		}
	}
	return BertInference.RunBERTInference(text, "./sentAnalysis/DoggoFinBERT.onnx")
}

func RunBERTInferenceONNX(text, modelPath, vocabPath string) (*BertInference.BERTSentiment, error) {
	return BertInference.RunBERTInference(text, modelPath)
}

// FetchStockSentiment analyses news items using a worker pool for concurrent BERT inference.
func FetchStockSentiment(ctx context.Context, newsItems []NewsItem) *StockSentimentAnalysis {
	if len(newsItems) == 0 {
		return &StockSentimentAnalysis{
			OverallSentiment: 0.0,
			Confidence:       0.0,
			NewsCount:        0,
			Recommendation:   "HOLD",
			PositiveRatio:    0.0,
			NegativeRatio:    0.0,
		}
	}

	// Run BERT analysis concurrently via worker pool
	type sentimentResult struct {
		index     int
		sentiment *BertInference.BERTSentiment
	}

	var (
		mu      sync.Mutex
		results []sentimentResult
	)

	tasks := make([]workerpool.Task, len(newsItems))
	for i, article := range newsItems {
		idx := i
		title := article.Title
		content := article.Content
		tasks[i] = func(_ context.Context) error {
			log.Printf("Processing article %d/%d: %s", idx+1, len(newsItems), title)
			sentiment, err := AnalyzeNews(title, content)
			if err != nil {
				log.Printf("Error analyzing news item: %v", err)
				return nil // non-fatal; we skip this article
			}
			mu.Lock()
			results = append(results, sentimentResult{index: idx, sentiment: sentiment})
			mu.Unlock()
			return nil
		}
	}

	workerpool.Run(ctx, 3, tasks)

	// Apply results back to newsItems and compute aggregates
	var totalSentiment float64
	var totalConfidence float64
	var positiveCount, negativeCount, neutralCount, validArticles int

	for _, r := range results {
		if r.sentiment == nil || r.sentiment.Confidence < 0.1 {
			continue
		}
		validArticles++
		newsItems[r.index].BERTSentiment = *r.sentiment

		weightedSentiment := r.sentiment.Score * r.sentiment.Confidence
		totalSentiment += weightedSentiment
		totalConfidence += r.sentiment.Confidence

		switch r.sentiment.Label {
		case "positive":
			positiveCount++
		case "negative":
			negativeCount++
		case "neutral":
			neutralCount++
		}
	}

	if validArticles == 0 {
		return &StockSentimentAnalysis{
			OverallSentiment: 0.0,
			Confidence:       0.0,
			NewsCount:        len(newsItems),
			Recommendation:   "HOLD",
		}
	}
	avgSentiment := totalSentiment / float64(validArticles)
	avgConfidence := totalConfidence / float64(validArticles)

	positiveRatio := float64(positiveCount) / float64(validArticles)
	negativeRatio := float64(negativeCount) / float64(validArticles)
	neutralRatio := float64(neutralCount) / float64(validArticles)

	return &StockSentimentAnalysis{
		OverallSentiment: avgSentiment,
		Confidence:       avgConfidence,
		NewsCount:        len(newsItems),
		PositiveRatio:    positiveRatio,
		NegativeRatio:    negativeRatio,
		NeutralRatio:     neutralRatio,
		Recommendation:   generateRecommendation(avgSentiment, avgConfidence, positiveRatio, negativeRatio),
	}
}

func generateRecommendation(sentiment, confidence, positiveRatio, negativeRatio float64) string {
	// High confidence required for strong recommendations
	if confidence < 0.6 {
		return "HOLD"
	}

	// Strong positive sentiment
	if sentiment > 0.3 && positiveRatio > 0.6 {
		return "BUY"
	}

	// Strong negative sentiment
	if sentiment < -0.3 && negativeRatio > 0.6 {
		return "SELL"
	}

	// Moderate positive sentiment
	if sentiment > 0.1 && positiveRatio > negativeRatio {
		return "WEAK_BUY"
	}

	// Moderate negative sentiment
	if sentiment < -0.1 && negativeRatio > positiveRatio {
		return "WEAK_SELL"
	}

	return "HOLD"
}

// FetchAndAnalyzeNews fetches news and runs BERT analysis via worker pool.
func FetchAndAnalyzeNews(ctx context.Context, symbol string) ([]NewsItem, error) {
	newsItems, err := FetchData(ctx, symbol)
	if err != nil {
		return nil, err
	}

	tasks := make([]workerpool.Task, len(newsItems))
	for i := range newsItems {
		idx := i
		tasks[i] = func(_ context.Context) error {
			analysis, err := AnalyzeNews(newsItems[idx].Title, newsItems[idx].Content)
			if err != nil {
				log.Printf("Error analyzing news item: %v", err)
				return nil // non-fatal
			}
			newsItems[idx].BERTSentiment = *analysis
			return nil
		}
	}

	workerpool.Run(ctx, 3, tasks)
	return newsItems, nil
}

func preprocessText(text string) string {
	// Remove excessive whitespace
	text = strings.TrimSpace(text)

	// Replace multiple spaces with single space
	text = strings.Join(strings.Fields(text), " ")

	// Basic HTML cleanup
	text = strings.ReplaceAll(text, "<br>", " ")
	text = strings.ReplaceAll(text, "<p>", " ")
	text = strings.ReplaceAll(text, "</p>", " ")

	return text
}
