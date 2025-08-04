package dataFetcher

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"time"

	"github.com/MadebyDaris/dogonomics/DogonomicsProcessing"
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
