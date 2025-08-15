package sentAnalysis

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"

	"github.com/MadebyDaris/dogonomics/BertInference"
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

func FetchData(symbol string) ([]NewsItem, error) {
	endpoint := "https://eodhd.com/api/news"
	params := url.Values{}
	params.Set("api_token", apiKey)
	params.Set("s", symbol)
	params.Set("limit", "5")
	fullURL := fmt.Sprintf("%s?%s", endpoint, params.Encode())
	resp, respErr := http.Get(fullURL)
	print(fullURL)
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

	if len(fullText) > 800 {
		fullText = fullText[:800]
		if lastPeriod := strings.LastIndex(fullText, "."); lastPeriod > 400 {
			fullText = fullText[:lastPeriod+1]
		}
	}
	return BertInference.RunBERTInference(text, "./sentAnalysis/DoggoFinBERT.onnx")
}

func RunBERTInferenceONNX(text, modelPath, vocabPath string) (*BertInference.BERTSentiment, error) {
	return BertInference.RunBERTInference(text, modelPath)
}

// Analyses numerous news items and gives an overall analysis
func FetchStockSentiment(newsItems []NewsItem) *StockSentimentAnalysis {
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

	var totalSentiment float64 = 0
	var totalConfidence float64 = 0
	var positiveCount int = 0
	var negativeCount int = 0
	var neutralCount int = 0

	validArticles := 0

	for articleIndex := range newsItems {
		article := newsItems[articleIndex]
		sentiment, err := AnalyzeNews(article.Title, article.Content)
		if err != nil {
			log.Printf("Error analyzing news item: %v", err)
			continue
		}
		if sentiment.Confidence < 0.1 {
			continue
		}
		validArticles++

		newsItems[articleIndex].BERTSentiment = *sentiment

		weightedSentiment := sentiment.Score * sentiment.Confidence
		totalSentiment += weightedSentiment
		totalConfidence += sentiment.Confidence

		if sentiment.Label == "positive" {
			positiveCount++
		} else if sentiment.Label == "negative" {
			negativeCount++
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

func FetchAndAnalyzeNews(symbol string) ([]NewsItem, error) {
	newsItems, err := FetchData(symbol)
	if err != nil {
		return nil, err
	}

	for news := range newsItems {
		analysis, err := AnalyzeNews(newsItems[news].Title, newsItems[news].Content)
		if err != nil {
			log.Printf("Error analyzing news item: %v", err)
			continue
		}
		newsItems[news].BERTSentiment = *analysis
	}
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
