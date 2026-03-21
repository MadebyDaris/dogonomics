package FredClient

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

type Client struct {
	APIKey     string
	HTTPClient *http.Client
}

func NewClient() *Client {
	return &Client{
		APIKey:     os.Getenv("FRED_API_KEY"),
		HTTPClient: &http.Client{Timeout: 10 * time.Second},
	}
}

type Observation struct {
	RealtimeStart string `json:"realtime_start"`
	RealtimeEnd   string `json:"realtime_end"`
	Date          string `json:"date"`
	Value         string `json:"value"`
}

type FredResponse struct {
	RealtimeStart    string        `json:"realtime_start"`
	RealtimeEnd      string        `json:"realtime_end"`
	ObservationStart string        `json:"observation_start"`
	ObservationEnd   string        `json:"observation_end"`
	Units            string        `json:"units"`
	OutputType       int           `json:"output_type"`
	FileType         string        `json:"file_type"`
	OrderBy          string        `json:"order_by"`
	SortOrder        string        `json:"sort_order"`
	Count            int           `json:"count"`
	Offset           int           `json:"offset"`
	Limit            int           `json:"limit"`
	Observations     []Observation `json:"observations"`
}

// GetSeriesObservations fetches the observations for a data series.
// seriesID: The id for a series (e.g., "GNP", "UNRATE").
func (c *Client) GetSeriesObservations(seriesID string) (*FredResponse, error) {
	if c.APIKey == "" {
		return nil, fmt.Errorf("FRED_API_KEY is not set")
	}

	url := fmt.Sprintf("https://api.stlouisfed.org/fred/series/observations?series_id=%s&api_key=%s&file_type=json", seriesID, c.APIKey)

	resp, err := c.HTTPClient.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("FRED API failed with status: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var fredResp FredResponse
	if err := json.Unmarshal(body, &fredResp); err != nil {
		return nil, fmt.Errorf("failed to parse FRED response: %v", err)
	}

	return &fredResp, nil
}
