package DogonomicsFetching

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
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

// Client struct
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

// Make Request helper function for finnHub API calls with specific endpoint and parameters
// It constructs the URL with the API key and parameters, makes the GET request,
// and returns the response body or an error if the request fails.
func (c *Client) makeRequest(endpoint string, params map[string]string) ([]byte, error) {
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

	resp, err := c.HTTPClient.Get(u.String())
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API request failed with status: %d", resp.StatusCode)
	}

	return io.ReadAll(resp.Body)
}

func (c *Client) GetCompanyProfile(symbol string) (*DogonomicsProcessing.CompanyProfile, error) {
	data, err := c.makeRequest("/stock/profile2", map[string]string{
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

func (c *Client) GetQuote(symbol string) (*Quote, error) {
	data, err := c.makeRequest("/quote", map[string]string{
		"symbol": symbol,
	})
	if err != nil {
		return nil, err
	}

	var quote Quote
	err = json.Unmarshal(data, &quote)
	return &quote, err
}

func (c *Client) GetBasicFinancials(symbol string) (*DogonomicsProcessing.BasicFinancials, error) {
	data, err := c.makeRequest("/stock/metric", map[string]string{
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

func (c *Client) BuildStockDetailData(symbol string) (*DogonomicsProcessing.StockDetailData, error) {
	chart, err := PolygonClient.RequestHistoricalData(symbol, 30)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch historical data: %v", err)
	}

	profile, err := c.GetCompanyProfile(symbol)
	if err != nil {
		return nil, fmt.Errorf("failed to get company profile: %v", err)
	}

	financials, err := c.GetBasicFinancials(symbol)
	if err != nil {
		return nil, fmt.Errorf("failed to get basic financials: %v", err)
	}

	quote, err := c.GetQuote(symbol)
	if err != nil {
		return nil, fmt.Errorf("failed to get quote: %v", err)
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
		AssetType:           "Stock", // Default, could be enhanced
		EBITDA:              "N/A",   // Not available on free plan
		PERatio:             peRatio,
		EPS:                 eps,
		AboutDescription:    fmt.Sprintf("%s is listed on %s", profile.Name, profile.Exchange),
		ChartData:           chart,                                       // Fetch last 30 days of data
		TechnicalIndicators: []DogonomicsProcessing.TechnicalIndicator{},
		SentimentData:       []DogonomicsProcessing.ChartDataPoint{},
		News:                []sentAnalysis.NewsItem{},
		AnalyticsData:       []DogonomicsProcessing.ChartDataPoint{},
		Logo:                profile.Logo,
	}, nil
}