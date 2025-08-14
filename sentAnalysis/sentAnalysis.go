package sentAnalysis

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"net/url"
	"os"
	"strings"
	"unicode"

	_ "github.com/MadebyDaris/Dogonomics/BertInference"
	"github.com/MadebyDaris/dogonomics/BertInference"
	"github.com/owulveryck/onnx-go"
	"github.com/owulveryck/onnx-go/backend/x/gorgonnx"
	"gorgonia.org/tensor"
)

var apiKey = os.Getenv("EODHD_API_KEY")

func LoadVocab(path string) (map[string]int, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	vocab := make(map[string]int)
	scanner := bufio.NewScanner(file)
	index := 0
	for scanner.Scan() {
		token := scanner.Text()
		vocab[token] = index
		index++
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return vocab, nil
}

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
	NegativeRatio    float64 `json:"negative_ratio"`
}

type BERTSentiment struct {
	Label      string  `json:"label"`      // "positive", "negative", "neutral"
	Confidence float64 `json:"confidence"` // 0.0 to 1.0
	Score      float64 `json:"score"`      // Raw logit score
}

type NewsItem struct {
	Title         string        `json:"title"`
	Content       string        `json:"content"`
	Date          string        `json:"date"`
	Link          string        `json:"link"`
	Sentiment     Sentiment     `json:"sentiment"`
	BERTSentiment BERTSentiment `json:"bert_sentiment"` // <-- FinBERT sentiment*
	Symbols       []string      `json:"symbols"`
	Tags          []string      `json:"tags"`
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

// type TokenBERT {

// }

func encode_word(word string, vocab map[string]int) []string {
	tokens := []string{}

	for len(word) > 0 {
		i := len(word)
		found := false

		for i > 0 {
			sub := word[:i]
			if _, exists := vocab[sub]; exists {
				found = true
				tokens = append(tokens, sub)
				word = word[i:]
				if len(word) > 0 {
					word = "##" + word
				}
				break
			}
			i--
		}
		if !found {
			tokens = append(tokens, "[UNK]")
			break
		}
	}
	return tokens
}

func TokenizeBert(text string, vocab map[string]int) []string {
	tokens := []string{}
	word := ""

	for _, char := range text {
		if unicode.IsLetter(char) || unicode.IsDigit(char) {
			word += string(char)
		} else {
			if word != "" {
				encoded_word := encode_word(strings.ToLower(word), vocab)
				tokens = append(tokens, encoded_word...)
				word = ""
			}
			if !unicode.IsSpace(char) {
				tokens = append(tokens, string(char))
			}
		}
	}

	if word != "" {
		tokens = append(tokens, word)
	}

	return tokens
}

func BertEncode(text string, vocab map[string]int, maxLen int) ([]int64, []int64, []int64) {
	tokens := []string{"[CLS]"}
	tokens = append(tokens, TokenizeBert(text, vocab)...)
	tokens = append(tokens, "[SEP]")

	// Fixed: Use proper indexing instead of append
	inputIds := make([]int64, 0, len(tokens))
	for _, token := range tokens {
		id, exists := vocab[token]
		if !exists {
			id = vocab["[UNK]"]
		}
		inputIds = append(inputIds, int64(id))
	}

	attentionMask := make([]int64, len(inputIds))
	for i := range attentionMask {
		attentionMask[i] = 1
	}

	tokenTypeIDs := make([]int64, len(inputIds))

	// Padding to maxLen
	for len(inputIds) < maxLen {
		inputIds = append(inputIds, 0)
		attentionMask = append(attentionMask, 0)
		tokenTypeIDs = append(tokenTypeIDs, 0)
	}

	// Truncate if too long
	if len(inputIds) > maxLen {
		inputIds = inputIds[:maxLen]
		attentionMask = attentionMask[:maxLen]
		tokenTypeIDs = tokenTypeIDs[:maxLen]
	}

	return inputIds, attentionMask, tokenTypeIDs
}

func RunBERTInferenceONNX(text string, model_path string, vocab_path string) (*BERTSentiment, error) {
	vocab, err := LoadVocab(vocab_path)
	if err != nil {
		return nil, fmt.Errorf("failed to load vocabulary: %v", err)
	}

	modelBytes, err := os.ReadFile(model_path)
	if err != nil {
		return nil, fmt.Errorf("failed to read model file: %v", err)
	}

	backend := gorgonnx.NewGraph()
	model := onnx.NewModel(backend)

	if err := model.UnmarshalBinary(modelBytes); err != nil {
		return nil, fmt.Errorf("failed to unmarshal ONNX model: %v", err)
	}

	inputIdsRaw, attentionMaskRaw, tokenTypeIdsRaw := BertEncode(text, vocab, 256)
	inputIds := tensor.New(
		tensor.WithShape(1, 256),
		tensor.WithBacking(inputIdsRaw),
	)
	attentionMask := tensor.New(
		tensor.WithShape(1, 256),
		tensor.WithBacking(attentionMaskRaw),
	)
	tokenTypeIds := tensor.New(
		tensor.WithShape(1, 256),
		tensor.WithBacking(tokenTypeIdsRaw),
	)
	model.SetInput(0, inputIds)
	model.SetInput(1, attentionMask)
	model.SetInput(2, tokenTypeIds)

	// INFERENCE
	if err := backend.Run(); err != nil {
		return nil, fmt.Errorf("failed to run model: %v", err)
	}

	outputs, err := model.GetOutputTensors()
	if err != nil {
		return nil, fmt.Errorf("failed to get outputs: %v", err)
	}

	logits := outputs[0].Data().([]float32)
	fmt.Println("test:", logits)
	return &BERTSentiment{}, nil
}

func ProcessLogits(logits []float32) *BERTSentiment {
	if len(logits) < 3 {
		return &BERTSentiment{
			Label:      "neutral",
			Confidence: 0.0,
			Score:      0.0,
		}
	}
	maxLogit := float32(math.Inf(-1))
	for _, logit := range logits[:3] {
		if logit > maxLogit {
			maxLogit = logit
		}
	}
	var sum float32 = 0
	probs := make([]float32, 3)
	// exponential confidence
	for i := 0; i <= 2; i++ {
		probs[i] = float32(math.Exp(float64(logits[i] - maxLogit)))
		sum += probs[i]
	}
	for i := range probs {
		probs[i] /= sum
	}
	maxIdx := 0
	maxProb := probs[0]
	for i := 1; i < 3; i++ {
		if probs[i] > maxProb {
			maxProb = probs[i]
			maxIdx = i
		}
	}

	labels := []string{"negative", "neutral", "positive"}

	// Calculate sentiment score (-1 to 1)
	sentimentScore := float64(probs[2] - probs[0]) // positive - negative

	return &BERTSentiment{
		Label:      labels[maxIdx],
		Confidence: float64(maxProb),
		Score:      sentimentScore,
	}
}

func AnalyzeNewsArticle(title, content string) (*BERTSentiment, error) {
	// Combine title and content (title often more important)
	fullText := fmt.Sprintf("%s. %s", title, content)

	// Truncate if too long (BERT has token limits)
	if len(fullText) > 1000 {
		fullText = fullText[:1000] + "..."
	}

	return BertInference.RunBERTInference(fullText, "./sentAnalysis/DoggoFinBERT.onnx")
}

func GetStockSentiment(newsItems []NewsItem) *StockSentimentAnalysis {
	if len(newsItems) == 0 {
		return &StockSentimentAnalysis{
			OverallSentiment: 0.0,
			Confidence:       0.0,
			NewsCount:        0,
		}
	}

	var totalSentiment float64 = 0
	var totalConfidence float64 = 0
	var positiveCount int = 0
	var negativeCount int = 0

	for articleIndex := range newsItems {
		article := newsItems[articleIndex]
		sentiment, err := AnalyzeNewsArticle(article.Title, article.Content)
		if err != nil {
			log.Printf("Error analyzing news item: %v", err)
			continue
		}
		// Its set as null so reaffecting it
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
	avgSentiment := totalSentiment / float64(len(newsItems))
	avgConfidence := totalConfidence / float64(len(newsItems))
	return &StockSentimentAnalysis{
		OverallSentiment: avgSentiment,
		Confidence:       avgConfidence,
		NewsCount:        len(newsItems),
		PositiveRatio:    float64(positiveCount) / float64(len(newsItems)),
		NegativeRatio:    float64(negativeCount) / float64(len(newsItems)),
	}
}

func FetchAndAnalyzeNews(symbol string) (*StockSentimentAnalysis, error) {
	newsItems, err := FetchData(symbol)
	if err != nil {
		return nil, err
	}
	analysis := GetStockSentiment(newsItems)
	analysis.Symbol = symbol
	// Add a simple recommendation based on sentiment

	return analysis, nil
}

func Examplef() float64 {
	// Analyze single news article
	sentiment, err := AnalyzeNewsArticle(
		"Apple Reports Strong Q4 Earnings",
		"Apple Inc. reported better than expected earnings for Q4, with revenue up 15% year over year...",
	)
	if err != nil {
		log.Printf("Error: %v", err)
		return 0
	}

	fmt.Printf("Sentiment: %s (%.2f confidence, %.2f score)\n",
		sentiment.Label, sentiment.Confidence, sentiment.Score)

	// Analyze stock based on news
	stockAnalysis, err := FetchAndAnalyzeNews("AAPL")
	if err != nil {
		log.Printf("Error: %v", err)
		return 0
	}

	fmt.Printf("Stock Analysis for %s:\n", stockAnalysis.Symbol)
	fmt.Printf("Overall Sentiment: %.2f\n", stockAnalysis.OverallSentiment)
	fmt.Printf("Confidence: %.2f\n", stockAnalysis.Confidence)
	return stockAnalysis.Confidence
}
