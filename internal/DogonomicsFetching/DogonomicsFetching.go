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
	"github.com/MadebyDaris/dogonomics/internal/PolygonClient"
	"github.com/MadebyDaris/dogonomics/sentAnalysis"
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
		News:                []sentAnalysis.NewsItem{},
		AnalyticsData:       []DogonomicsProcessing.ChartDataPoint{},
		Logo:                profile.Logo,
	}, nil
}
