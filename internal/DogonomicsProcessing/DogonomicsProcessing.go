package DogonomicsProcessing

import (
	"encoding/json"
	"strconv"
	"time"

	"github.com/MadebyDaris/dogonomics/sentAnalysis"
)

// StockDetailData represents the comprehensive stock payload sent to the frontend.
type StockDetailData struct {
	CompanyName         string                  `json:"companyName"`
	Description         string                  `json:"description"`
	CurrentPrice        float64                 `json:"currentPrice"`
	ChangePercentage    float64                 `json:"changePercentage"`
	Exchange            string                  `json:"exchange"`
	Symbol              string                  `json:"symbol"`
	AssetType           string                  `json:"assetType"`
	EBITDA              string                  `json:"ebitda"`
	PERatio             float64                 `json:"peRatio"`
	EPS                 float64                 `json:"eps"`
	AboutDescription    string                  `json:"aboutDescription"`
	ChartData           []ChartDataPoint        `json:"chartData"`
	TechnicalIndicators []TechnicalIndicator    `json:"technicalIndicators"`
	SentimentData       []ChartDataPoint        `json:"sentimentData"`
	News                []sentAnalysis.NewsItem `json:"news"`
	AnalyticsData       []ChartDataPoint        `json:"analyticsData"`
	Logo                string                  `json:"logo"`
}

// Common structures
type ChartDataPoint struct {
	Timestamp time.Time `json:"timestamp"`
	Open      float64   `json:"open"`
	High      float64   `json:"high"`
	Low       float64   `json:"low"`
	Close     float64   `json:"close"`
	Volume    int64     `json:"volume"`
}

type TechnicalIndicator struct {
	Name      string    `json:"name"`
	Value     float64   `json:"value"`
	Signal    string    `json:"signal"` // "BUY", "SELL", "HOLD"
	Timestamp time.Time `json:"timestamp"`
}

type CompanyProfile struct {
	Country          string  `json:"country"`
	Currency         string  `json:"currency"`
	Exchange         string  `json:"exchange"`
	Ipo              string  `json:"ipo"`
	MarketCap        float64 `json:"marketCapitalization"`
	Name             string  `json:"name"`
	Phone            string  `json:"phone"`
	ShareOutstanding float64 `json:"shareOutstanding"`
	Ticker           string  `json:"ticker"`
	WebURL           string  `json:"weburl"`
	Logo             string  `json:"logo"`
	FinnhubIndustry  string  `json:"finnhubIndustry"`
}

type AnnualData struct {
	Period string  `json:"period"`
	V      float64 `json:"v"`
}

type QuarterlyData struct {
	Period string  `json:"period"`
	V      float64 `json:"v"`
}

type FlexibleFloat float64

func (ff *FlexibleFloat) UnmarshalJSON(data []byte) error {
	// Try to unmarshal as float64 first
	var f float64
	if err := json.Unmarshal(data, &f); err == nil {
		*ff = FlexibleFloat(f)
		return nil
	}

	// Try to unmarshal as string
	var s string
	if err := json.Unmarshal(data, &s); err != nil {
		return err
	}

	// Handle empty string or "N/A" cases
	if s == "" || s == "N/A" || s == "null" {
		*ff = FlexibleFloat(0)
		return nil
	}

	// Try to parse string as float
	if parsed, err := strconv.ParseFloat(s, 64); err == nil {
		*ff = FlexibleFloat(parsed)
		return nil
	}

	// Default to 0 if parsing fails
	*ff = FlexibleFloat(0)
	return nil
}

// Float64 converts FlexibleFloat to float64
func (ff FlexibleFloat) Float64() float64 {
	return float64(ff)
}

type BasicFinancials struct {
	Series struct {
		Annual    map[string][]AnnualData    `json:"annual"`
		Quarterly map[string][]QuarterlyData `json:"quarterly"`
	} `json:"series"`
	Metric map[string]interface{} `json:"metric"`
}
