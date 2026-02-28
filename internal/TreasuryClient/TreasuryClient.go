package TreasuryClient

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

const treasuryBaseURL = "https://api.fiscaldata.treasury.gov/services/api/fiscal_service"

// Client for Treasury Fiscal Data API
type Client struct {
	HTTPClient *http.Client
}

// TreasuryRate represents a treasury rate data point
type TreasuryRate struct {
	RecordDate            string `json:"record_date"`
	SecurityDesc          string `json:"security_desc"`
	AvgInterestRateAmt    string `json:"avg_interest_rate_amt"`
	SecurityTypeDesc      string `json:"security_type_desc"`
	SrcLineNbr            string `json:"src_line_nbr,omitempty"`
	RoundingAdjustmentInd string `json:"rounding_adjustment_ind,omitempty"`
}

// TreasuryYieldRate represents daily treasury yield rates
type TreasuryYieldRate struct {
	RecordDate string  `json:"record_date"`
	OneMonth   *string `json:"1_month,omitempty"`
	TwoMonth   *string `json:"2_month,omitempty"`
	ThreeMonth *string `json:"3_month,omitempty"`
	SixMonth   *string `json:"6_month,omitempty"`
	OneYear    *string `json:"1_year,omitempty"`
	TwoYear    *string `json:"2_year,omitempty"`
	ThreeYear  *string `json:"3_year,omitempty"`
	FiveYear   *string `json:"5_year,omitempty"`
	SevenYear  *string `json:"7_year,omitempty"`
	TenYear    *string `json:"10_year,omitempty"`
	TwentyYear *string `json:"20_year,omitempty"`
	ThirtyYear *string `json:"30_year,omitempty"`
}

// TreasuryResponse generic response structure
type TreasuryResponse struct {
	Data []map[string]interface{} `json:"data"`
	Meta struct {
		Count      int               `json:"count"`
		TotalCount int               `json:"total-count"`
		TotalPages int               `json:"total-pages"`
		Labels     map[string]string `json:"labels"`
	} `json:"meta"`
	Links struct {
		Self  string `json:"self"`
		First string `json:"first"`
		Prev  string `json:"prev,omitempty"`
		Next  string `json:"next,omitempty"`
		Last  string `json:"last"`
	} `json:"links"`
}

func NewClient() *Client {
	return &Client{
		HTTPClient: &http.Client{Timeout: 30 * time.Second},
	}
}

// GetAverageInterestRates fetches average interest rates on US Treasury Securities.
func (c *Client) GetAverageInterestRates(ctx context.Context, pageSize int, pageNumber int) (*TreasuryResponse, error) {
	endpoint := "/v2/accounting/od/avg_interest_rates"
	params := url.Values{}
	params.Set("page[size]", fmt.Sprintf("%d", pageSize))
	params.Set("page[number]", fmt.Sprintf("%d", pageNumber))
	params.Set("sort", "-record_date")

	return c.makeRequest(ctx, endpoint, params)
}

// GetDailyTreasuryYieldRates fetches daily treasury yield curve rates.
func (c *Client) GetDailyTreasuryYieldRates(ctx context.Context, days int) (*TreasuryResponse, error) {
	endpoint := "/v2/accounting/od/avg_interest_rates"
	params := url.Values{}

	// Calculate date range
	endDate := time.Now().Format("2006-01-02")
	startDate := time.Now().AddDate(0, 0, -days).Format("2006-01-02")

	params.Set("fields", "record_date,security_desc,avg_interest_rate_amt")
	params.Set("filter", fmt.Sprintf("record_date:gte:%s,record_date:lte:%s", startDate, endDate))
	params.Set("sort", "-record_date")
	params.Set("page[size]", "100")

	return c.makeRequest(ctx, endpoint, params)
}

// GetLatestYieldCurve gets the most recent yield curve rates.
func (c *Client) GetLatestYieldCurve(ctx context.Context) (*TreasuryResponse, error) {
	endpoint := "/v2/accounting/od/avg_interest_rates"
	params := url.Values{}
	params.Set("sort", "-record_date")
	params.Set("page[size]", "20")

	return c.makeRequest(ctx, endpoint, params)
}

// GetDebtToThePenny fetches total public debt outstanding.
func (c *Client) GetDebtToThePenny(ctx context.Context, days int) (*TreasuryResponse, error) {
	endpoint := "/v2/accounting/od/debt_to_penny"
	params := url.Values{}

	if days > 0 {
		endDate := time.Now().Format("2006-01-02")
		startDate := time.Now().AddDate(0, 0, -days).Format("2006-01-02")
		params.Set("filter", fmt.Sprintf("record_date:gte:%s,record_date:lte:%s", startDate, endDate))
	}

	params.Set("sort", "-record_date")
	params.Set("page[size]", fmt.Sprintf("%d", min(days, 1000)))

	return c.makeRequest(ctx, endpoint, params)
}

// makeRequest is a context-aware helper for Treasury API calls.
func (c *Client) makeRequest(ctx context.Context, endpoint string, params url.Values) (*TreasuryResponse, error) {
	u, err := url.Parse(treasuryBaseURL + endpoint)
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

	var treasuryResp TreasuryResponse
	err = json.Unmarshal(body, &treasuryResp)
	if err != nil {
		return nil, fmt.Errorf("failed to parse response: %v", err)
	}

	return &treasuryResp, nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
