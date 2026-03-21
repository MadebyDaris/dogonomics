package CommoditiesClient

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"time"
)

const alphaVantageBaseURL = "https://www.alphavantage.co/query"

// Client for commodities data
type Client struct {
	APIKey     string
	HTTPClient *http.Client
}

// CommodityData represents commodity price data
type CommodityData struct {
	Name     string                 `json:"name"`
	Interval string                 `json:"interval"`
	Unit     string                 `json:"unit"`
	Data     []CommodityDataPoint   `json:"data"`
	MetaData map[string]interface{} `json:"meta_data,omitempty"`
}

// CommodityDataPoint represents a single data point
type CommodityDataPoint struct {
	Date  string `json:"date"`
	Value string `json:"value"`
}

// AlphaVantageResponse for commodities
type AlphaVantageResponse struct {
	Name     string              `json:"name"`
	Interval string              `json:"interval"`
	Unit     string              `json:"unit"`
	Data     []map[string]string `json:"data"`
}

func NewClient() *Client {
	return &Client{
		APIKey:     os.Getenv("ALPHA_VANTAGE_API_KEY"),
		HTTPClient: &http.Client{Timeout: 30 * time.Second},
	}
}

// GetCrudeOilWTI fetches WTI Crude Oil prices.
func (c *Client) GetCrudeOilWTI(ctx context.Context) (*CommodityData, error) {
	params := url.Values{}
	params.Set("function", "WTI")
	params.Set("interval", "daily")
	params.Set("apikey", c.APIKey)

	return c.makeRequest(ctx, params, "WTI Crude Oil")
}

// GetCrudeOilBrent fetches Brent Crude Oil prices.
func (c *Client) GetCrudeOilBrent(ctx context.Context) (*CommodityData, error) {
	params := url.Values{}
	params.Set("function", "BRENT")
	params.Set("interval", "daily")
	params.Set("apikey", c.APIKey)

	return c.makeRequest(ctx, params, "Brent Crude Oil")
}

// GetNaturalGas fetches Natural Gas prices.
func (c *Client) GetNaturalGas(ctx context.Context) (*CommodityData, error) {
	params := url.Values{}
	params.Set("function", "NATURAL_GAS")
	params.Set("interval", "daily")
	params.Set("apikey", c.APIKey)

	return c.makeRequest(ctx, params, "Natural Gas")
}

// GetCopper fetches Copper prices.
func (c *Client) GetCopper(ctx context.Context) (*CommodityData, error) {
	params := url.Values{}
	params.Set("function", "COPPER")
	params.Set("interval", "monthly")
	params.Set("apikey", c.APIKey)

	return c.makeRequest(ctx, params, "Copper")
}

// GetAluminum fetches Aluminum prices.
func (c *Client) GetAluminum(ctx context.Context) (*CommodityData, error) {
	params := url.Values{}
	params.Set("function", "ALUMINUM")
	params.Set("interval", "monthly")
	params.Set("apikey", c.APIKey)

	return c.makeRequest(ctx, params, "Aluminum")
}

// GetWheat fetches Wheat prices.
func (c *Client) GetWheat(ctx context.Context) (*CommodityData, error) {
	params := url.Values{}
	params.Set("function", "WHEAT")
	params.Set("interval", "monthly")
	params.Set("apikey", c.APIKey)

	return c.makeRequest(ctx, params, "Wheat")
}

// GetCorn fetches Corn prices.
func (c *Client) GetCorn(ctx context.Context) (*CommodityData, error) {
	params := url.Values{}
	params.Set("function", "CORN")
	params.Set("interval", "monthly")
	params.Set("apikey", c.APIKey)

	return c.makeRequest(ctx, params, "Corn")
}

// GetCotton fetches Cotton prices.
func (c *Client) GetCotton(ctx context.Context) (*CommodityData, error) {
	params := url.Values{}
	params.Set("function", "COTTON")
	params.Set("interval", "monthly")
	params.Set("apikey", c.APIKey)

	return c.makeRequest(ctx, params, "Cotton")
}

// GetSugar fetches Sugar prices.
func (c *Client) GetSugar(ctx context.Context) (*CommodityData, error) {
	params := url.Values{}
	params.Set("function", "SUGAR")
	params.Set("interval", "monthly")
	params.Set("apikey", c.APIKey)

	return c.makeRequest(ctx, params, "Sugar")
}

// GetCoffee fetches Coffee prices.
func (c *Client) GetCoffee(ctx context.Context) (*CommodityData, error) {
	params := url.Values{}
	params.Set("function", "COFFEE")
	params.Set("interval", "monthly")
	params.Set("apikey", c.APIKey)

	return c.makeRequest(ctx, params, "Coffee")
}

// GetGlobalOilPrice fetches All Countries Crude Oil prices (annual data).
func (c *Client) GetGlobalOilPrice(ctx context.Context) (*CommodityData, error) {
	params := url.Values{}
	params.Set("function", "ALL_COMMODITIES")
	params.Set("interval", "annual")

	if c.APIKey != "" {
		params.Set("apikey", c.APIKey)
	}

	return c.makeRequest(ctx, params, "Global Oil Price")
}

// makeRequest is a context-aware helper for commodity API calls.
func (c *Client) makeRequest(ctx context.Context, params url.Values, commodityName string) (*CommodityData, error) {
	if c.APIKey == "" && params.Get("apikey") == "" {
		return nil, fmt.Errorf("ALPHA_VANTAGE_API_KEY environment variable not set")
	}

	u, err := url.Parse(alphaVantageBaseURL)
	if err != nil {
		return nil, err
	}

	u.RawQuery = params.Encode()

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
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API request failed with status: %d, body: %s", resp.StatusCode, string(body))
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var avResp AlphaVantageResponse
	err = json.Unmarshal(body, &avResp)
	if err != nil {
		return nil, fmt.Errorf("failed to parse response: %v", err)
	}

	// Convert to our format
	data := &CommodityData{
		Name:     avResp.Name,
		Interval: avResp.Interval,
		Unit:     avResp.Unit,
		Data:     make([]CommodityDataPoint, 0, len(avResp.Data)),
	}

	for _, point := range avResp.Data {
		data.Data = append(data.Data, CommodityDataPoint{
			Date:  point["date"],
			Value: point["value"],
		})
	}

	return data, nil
}

// IsAPIKeyConfigured checks if Alpha Vantage API key is configured
func (c *Client) IsAPIKeyConfigured() bool {
	return c.APIKey != ""
}
