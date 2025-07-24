package sentAnalysis

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
)

const apiKey = "DEMO"

type Sentiment struct {
	Polarity float64 `json:"polarity"`
	Neg      float64 `json:"neg"`
	Neu      float64 `json:"neu"`
	Pos      float64 `json:"pos"`
}

type BERTSentiment struct {
	Label      string  `json:"label"`      // e.g., "positive", "neutral", "negative"
	Confidence float64 `json:"confidence"` // e.g., 0.87
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
	body, err := io.ReadAll(resp.Body)
	var news []NewsItem

	err = json.Unmarshal(body, &news)

	if err != nil {
		log.Fatal(err)
	}

	return news, nil
}

func GetBERTSentiment(text string) (BERTSentiment, error) {
	payload := map[string]string{"text": text}
	payloadBytes, _ := json.Marshal(payload)

	resp, err := http.Post("http://localhost:8000/analyze", "application/json", bytes.NewBuffer(payloadBytes))
	if err != nil {
		return BERTSentiment{}, err
	}
	defer resp.Body.Close()

	var result []map[string]interface{}
	err = json.NewDecoder(resp.Body).Decode(&result)
	if err != nil || len(result) == 0 {
		return BERTSentiment{}, err
	}

	label := result[0]["label"].(string)
	conf := result[0]["score"].(float64)

	return BERTSentiment{Label: label, Confidence: conf}, nil
}
