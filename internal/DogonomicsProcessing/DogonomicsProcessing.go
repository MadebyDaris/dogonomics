package DogonomicsProcessing

import (
	"time"

	"github.com/MadebyDaris/dogonomics/sentAnalysis"
)

// StockDetailData represents detailed stock information
// including company details, technical indicators, and sentiment data.
// Made to fit the Frontend requirements on dogonomics.
// It includes fields for company name, description, current price,
// change percentage, exchange, symbol, asset type, and various financial metrics.
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

type BasicFinancials struct {
	Series struct {
		Annual    map[string][]AnnualData    `json:"annual"`
		Quarterly map[string][]QuarterlyData `json:"quarterly"`
	} `json:"series"`
	Metric map[string]float64 `json:"metric"`
}
