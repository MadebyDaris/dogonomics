package DogonomicsFetching

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/DogonomicsProcessing"
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

// makeRequest helper function for API calls
func (c *Client) makeRequest(endpoint string, params map[string]string) ([]byte, error) {
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
		return nil, err
	}

	var financials DogonomicsProcessing.BasicFinancials
	err = json.Unmarshal(data, &financials)
	return &financials, err
}

func (c *Client) BuildStockDetailData(symbol string) (*DogonomicsProcessing.StockDetailData, error) {
	yahooClient := NewYahooFinanceClient()
	chart, err := yahooClient.GetHistoricalData(symbol, 30)
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
			peRatio = val
		}
		if val, exists := financials.Metric["epsBasicExclExtraaTTM"]; exists {
			eps = val
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
		TechnicalIndicators: []DogonomicsProcessing.TechnicalIndicator{}, // Not available on free plan
		SentimentData:       []DogonomicsProcessing.ChartDataPoint{},     // Not available on free plan
		News:                []sentAnalysis.NewsItem{},
		AnalyticsData:       []DogonomicsProcessing.ChartDataPoint{}, // Custom analytics would go here
	}, nil
}

// Historical data with Yahoo finance API
type YahooFinanceClient struct {
	HTTPClient *http.Client
}

type YahooResponse struct {
	Chart struct {
		Result []struct {
			Meta struct {
				Currency           string  `json:"currency"`
				Symbol             string  `json:"symbol"`
				ExchangeName       string  `json:"exchangeName"`
				RegularMarketPrice float64 `json:"regularMarketPrice"`
			} `json:"meta"`
			Timestamp  []int64 `json:"timestamp"`
			Indicators struct {
				Quote []struct {
					Open   []float64 `json:"open"`
					High   []float64 `json:"high"`
					Low    []float64 `json:"low"`
					Close  []float64 `json:"close"`
					Volume []int64   `json:"volume"`
				} `json:"quote"`
			} `json:"indicators"`
		} `json:"result"`
	} `json:"chart"`
}

func NewYahooFinanceClient() *YahooFinanceClient {
	return &YahooFinanceClient{
		HTTPClient: &http.Client{Timeout: 30 * time.Second},
	}
}

func (y *YahooFinanceClient) GetHistoricalData(symbol string, days int) ([]DogonomicsProcessing.ChartDataPoint, error) {
	now := time.Now()
	from := now.AddDate(0, 0, -days)

	baseURL := "https://query1.finance.yahoo.com/v8/finance/chart/" + symbol
	params := url.Values{}
	params.Set("period1", strconv.FormatInt(from.Unix(), 10))
	params.Set("period2", strconv.FormatInt(now.Unix(), 10))
	params.Set("interval", "2d")
	params.Set("includePrePost", "true")

	resp, err := y.HTTPClient.Get(baseURL + "?" + params.Encode())
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	fmt.Println("RAW RESPONSE BODY:")
	fmt.Println(string(body))

	var yahooResponse YahooResponse
	if err := json.Unmarshal(body, &yahooResponse); err != nil {
		return nil, err
	}

	if len(yahooResponse.Chart.Result) == 0 {
		return nil, fmt.Errorf("no data found for symbol %s", symbol)
	}

	result := yahooResponse.Chart.Result[0]
	var chartData []DogonomicsProcessing.ChartDataPoint

	for i, timestamp := range result.Timestamp {
		if i >= len(result.Indicators.Quote[0].Close) {
			break
		}

		chartData = append(chartData, DogonomicsProcessing.ChartDataPoint{
			Timestamp: time.Unix(timestamp, 0),
			Open:      result.Indicators.Quote[0].Open[i],
			High:      result.Indicators.Quote[0].High[i],
			Low:       result.Indicators.Quote[0].Low[i],
			Close:     result.Indicators.Quote[0].Close[i],
			Volume:    result.Indicators.Quote[0].Volume[i],
		})
	}

	return chartData, nil
}
