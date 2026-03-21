package ForexClient

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type Client struct {
	HTTPClient *http.Client
}

func NewClient() *Client {
	return &Client{
		HTTPClient: &http.Client{Timeout: 10 * time.Second},
	}
}

type ForexRates struct {
	Amount float64            `json:"amount"`
	Base   string             `json:"base"`
	Date   string             `json:"date"`
	Rates  map[string]float64 `json:"rates"`
}

// GetLatestRates fetches the latest foreign exchange reference rates.
// base: The currency to use as the base (e.g., "USD").
func (c *Client) GetLatestRates(base string) (*ForexRates, error) {
	url := fmt.Sprintf("https://api.frankfurter.app/latest?from=%s", base)

	resp, err := c.HTTPClient.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("Frankfurter API failed with status: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var rates ForexRates
	if err := json.Unmarshal(body, &rates); err != nil {
		return nil, fmt.Errorf("failed to parse Frankfurter response: %v", err)
	}

	return &rates, nil
}
