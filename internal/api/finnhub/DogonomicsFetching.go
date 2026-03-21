package DogonomicsFetching

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"sync"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/DogonomicsProcessing"
	"github.com/MadebyDaris/dogonomics/internal/api/polygon"
	"github.com/MadebyDaris/dogonomics/internal/service/sentiment"
)

type Quote struct {
	CurrentPrice  float64 `json:"c"`
	Change        float64 `json:"d"`
	PercentChange float64 `json:"dp"`
	HighPrice     float64 `json:"h"`
	LowPrice      float64 `json:"l"`
	OpenPrice     float64 `json:"o"`
	PreviousClose float64 `json:"pc"`
	Timestamp     int64   `json:"t"`
}

const baseURL = "https://finnhub.io/api/v1"

// Client wraps the Finnhub API.
type Client struct {
	APIKey     string
	HTTPClient *http.Client
}

func NewClient() *Client {
	return &Client{
		APIKey:     os.Getenv("FINNHUB_API_KEY"),
		HTTPClient: &http.Client{Timeout: 30 * time.Second},
	}
}

// makeRequest is a context-aware helper for Finnhub API calls.
func (c *Client) makeRequest(ctx context.Context, endpoint string, params map[string]string) ([]byte, error) {
	if c.APIKey == "" {
		return nil, fmt.Errorf("FINNHUB_API_KEY environment variable not set")
	}

	u, err := url.Parse(baseURL + endpoint)
	if err != nil {
		return nil, err
	}

	q := u.Query()
	q.Set("token", c.APIKey)
	for key, value := range params {
		q.Set(key, value)
	}
	u.RawQuery = q.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return nil, err
	}

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API request failed with status: %d", resp.StatusCode)
	}

	return io.ReadAll(resp.Body)
}

func (c *Client) GetCompanyProfile(ctx context.Context, symbol string) (*DogonomicsProcessing.CompanyProfile, error) {
	data, err := c.makeRequest(ctx, "/stock/profile2", map[string]string{
		"symbol": symbol,
	})
	if err != nil {
		return nil, err
	}

	var profile DogonomicsProcessing.CompanyProfile
	err = json.Unmarshal(data, &profile)
	if err != nil {
		return nil, fmt.Errorf("failed to parse company profile JSON: %v", err)
	}

	return &profile, err
}

func (c *Client) GetQuote(ctx context.Context, symbol string) (*Quote, error) {
	data, err := c.makeRequest(ctx, "/quote", map[string]string{
		"symbol": symbol,
	})
	if err != nil {
		return nil, err
	}

	var quote Quote
	err = json.Unmarshal(data, &quote)
	return &quote, err
}

func (c *Client) GetBasicFinancials(ctx context.Context, symbol string) (*DogonomicsProcessing.BasicFinancials, error) {
	data, err := c.makeRequest(ctx, "/stock/metric", map[string]string{
		"symbol": symbol,
		"metric": "all",
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get basic financials: %v", err)
	}

	var financials DogonomicsProcessing.BasicFinancials
	err = json.Unmarshal(data, &financials)
	if err != nil {
		// Log the raw JSON for debugging
		log.Printf("Failed to parse financials JSON: %v", err)
		log.Printf("Raw JSON data: %s", string(data))
		return nil, fmt.Errorf("failed to parse basic financials JSON: %v", err)
	}
	return &financials, err
}

// BuildStockDetailData fetches chart, profile, financials, and quote concurrently.
func (c *Client) BuildStockDetailData(ctx context.Context, symbol string) (*DogonomicsProcessing.StockDetailData, error) {
	var (
		chart      []DogonomicsProcessing.ChartDataPoint
		profile    *DogonomicsProcessing.CompanyProfile
		financials *DogonomicsProcessing.BasicFinancials
		quote      *Quote

		chartErr, profileErr, financialsErr, quoteErr error
		wg                                            sync.WaitGroup
	)

	wg.Add(4)

	go func() {
		defer wg.Done()
		chart, chartErr = PolygonClient.RequestHistoricalData(ctx, symbol, 30)
	}()

	go func() {
		defer wg.Done()
		profile, profileErr = c.GetCompanyProfile(ctx, symbol)
	}()

	go func() {
		defer wg.Done()
		financials, financialsErr = c.GetBasicFinancials(ctx, symbol)
	}()

	go func() {
		defer wg.Done()
		quote, quoteErr = c.GetQuote(ctx, symbol)
	}()

	wg.Wait()

	// Check for context cancellation first
	if ctx.Err() != nil {
		return nil, fmt.Errorf("request cancelled: %w", ctx.Err())
	}

	if chartErr != nil {
		return nil, fmt.Errorf("failed to fetch historical data: %v", chartErr)
	}
	if profileErr != nil {
		return nil, fmt.Errorf("failed to get company profile: %v", profileErr)
	}
	if financialsErr != nil {
		return nil, fmt.Errorf("failed to get basic financials: %v", financialsErr)
	}
	if quoteErr != nil {
		return nil, fmt.Errorf("failed to get quote: %v", quoteErr)
	}

	var peRatio, eps float64
	if financials != nil {
		if val, exists := financials.Metric["peBasicExclExtraTTM"]; exists {
			if v, ok := val.(float64); ok {
				peRatio = v
			}
		}
		if val, exists := financials.Metric["epsBasicExclExtraTTM"]; exists {
			if v, ok := val.(float64); ok {
				eps = v
			}
		}
	}
	return &DogonomicsProcessing.StockDetailData{
		CompanyName:         profile.Name,
		Description:         profile.Country,
		CurrentPrice:        quote.CurrentPrice,
		ChangePercentage:    quote.PercentChange,
		Exchange:            profile.Exchange,
		Symbol:              symbol,
		AssetType:           "Stock",
		EBITDA:              "N/A",
		PERatio:             peRatio,
		EPS:                 eps,
		AboutDescription:    fmt.Sprintf("%s is listed on %s", profile.Name, profile.Exchange),
		ChartData:           chart,
		TechnicalIndicators: []DogonomicsProcessing.TechnicalIndicator{},
		SentimentData:       []DogonomicsProcessing.ChartDataPoint{},
		News:                []sentiment.NewsItem{},
		AnalyticsData:       []DogonomicsProcessing.ChartDataPoint{},
		Logo:                profile.Logo,
	}, nil
}

// ============================================================
// Forex & Crypto
// ============================================================

// ForexRates represents exchange rates from Finnhub /forex/rates
type ForexRates struct {
	Base  string             `json:"base"`
	Quote map[string]float64 `json:"quote"`
}

// ForexSymbol represents a forex symbol pair from Finnhub /forex/symbol
type ForexSymbol struct {
	Description   string `json:"description"`
	DisplaySymbol string `json:"displaySymbol"`
	Symbol        string `json:"symbol"`
}

// CryptoSymbol represents a crypto symbol from Finnhub /crypto/symbol
type CryptoSymbol struct {
	Description   string `json:"description"`
	DisplaySymbol string `json:"displaySymbol"`
	Symbol        string `json:"symbol"`
}

// CryptoCandle represents OHLCV candle data from Finnhub /crypto/candle
type CryptoCandle struct {
	Close     []float64 `json:"c"`
	High      []float64 `json:"h"`
	Low       []float64 `json:"l"`
	Open      []float64 `json:"o"`
	Volume    []float64 `json:"v"`
	Timestamp []int64   `json:"t"`
	Status    string    `json:"s"`
}

// GetForexRates fetches forex exchange rates for the given base currency.
func (c *Client) GetForexRates(ctx context.Context, base string) (*ForexRates, error) {
	data, err := c.makeRequest(ctx, "/forex/rates", map[string]string{"base": base})
	if err != nil {
		return nil, err
	}
	var rates ForexRates
	if err := json.Unmarshal(data, &rates); err != nil {
		return nil, fmt.Errorf("failed to parse forex rates: %v", err)
	}
	return &rates, nil
}

// GetForexSymbols lists available forex symbols on the given exchange.
func (c *Client) GetForexSymbols(ctx context.Context, exchange string) ([]ForexSymbol, error) {
	data, err := c.makeRequest(ctx, "/forex/symbol", map[string]string{"exchange": exchange})
	if err != nil {
		return nil, err
	}
	var symbols []ForexSymbol
	if err := json.Unmarshal(data, &symbols); err != nil {
		return nil, fmt.Errorf("failed to parse forex symbols: %v", err)
	}
	return symbols, nil
}

// GetCryptoSymbols lists available crypto symbols on the given exchange.
func (c *Client) GetCryptoSymbols(ctx context.Context, exchange string) ([]CryptoSymbol, error) {
	data, err := c.makeRequest(ctx, "/crypto/symbol", map[string]string{"exchange": exchange})
	if err != nil {
		return nil, err
	}
	var symbols []CryptoSymbol
	if err := json.Unmarshal(data, &symbols); err != nil {
		return nil, fmt.Errorf("failed to parse crypto symbols: %v", err)
	}
	return symbols, nil
}

// GetCryptoCandle fetches OHLCV candle data for a crypto symbol.
func (c *Client) GetCryptoCandle(ctx context.Context, symbol, resolution string, from, to int64) (*CryptoCandle, error) {
	data, err := c.makeRequest(ctx, "/crypto/candle", map[string]string{
		"symbol":     symbol,
		"resolution": resolution,
		"from":       fmt.Sprintf("%d", from),
		"to":         fmt.Sprintf("%d", to),
	})
	if err != nil {
		return nil, err
	}
	var candle CryptoCandle
	if err := json.Unmarshal(data, &candle); err != nil {
		return nil, fmt.Errorf("failed to parse crypto candle: %v", err)
	}
	if candle.Status == "no_data" {
		return nil, fmt.Errorf("no data available for symbol %s", symbol)
	}
	return &candle, nil
}

