package controller

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/DogonomicsFetching"
	"github.com/MadebyDaris/dogonomics/internal/PolygonClient"
	"github.com/MadebyDaris/dogonomics/sentAnalysis"
	"github.com/gin-gonic/gin"
)

var (
	finnhubClient            *DogonomicsFetching.Client
	dogonomicsFetchingClient *DogonomicsFetching.Client
)

// ErrorResponse represents a standard error payload
type ErrorResponse struct {
	Error string `json:"error"`
}

// NewsSentimentBERTResponse is the response schema for /finnewsBert/{symbol}
type NewsSentimentBERTResponse struct {
	Symbol          string                               `json:"symbol"`
	AggregateResult *sentAnalysis.StockSentimentAnalysis `json:"aggregate_result"`
	NewsItems       []sentAnalysis.NewsItem              `json:"news_items"`
}

// SentimentOnlyResponse is the response schema for /sentiment/{symbol}
type SentimentOnlyResponse struct {
	Symbol    string                               `json:"symbol"`
	Sentiment *sentAnalysis.StockSentimentAnalysis `json:"sentiment"`
}

func Init(fc *DogonomicsFetching.Client) {
	finnhubClient = fc
	dogonomicsFetchingClient = fc
}

// GetTicker godoc
// @Summary      Get aggregated ticker data
// @Description  Returns aggregated ticker data for the given date (defaults to yesterday)
// @Tags         ticker
// @Param        symbol   path   string  true  "Ticker symbol (e.g., AAPL)"
// @Param        date     query  string  false "Date (YYYY-MM-DD)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      400  {object}  ErrorResponse
// @Failure      500  {object}  ErrorResponse
// @Router       /ticker/{symbol} [get]
func GetTicker(c *gin.Context) {
	symbol := c.Param("symbol")
	dateStr := c.Query("date")

	var date time.Time
	var err error

	if dateStr != "" {
		date, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid format try with YYYY-MM-DD"})
			return
		}
	} else {
		date = time.Now().UTC().AddDate(0, 0, -1) // default to yesterday
	}

	stock, _ := PolygonClient.RequestTicker(symbol, date)

	c.JSON(http.StatusOK, stock)
}

// GetQuote - Uses Finnhub quote endpoint
// GetQuote godoc
// @Summary      Get current quote
// @Description  Returns current quote for a ticker symbol (Finnhub)
// @Tags         quotes
// @Param        symbol   path   string  true  "Ticker symbol (e.g., AAPL)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /quote/{symbol} [get]
func GetQuote(c *gin.Context) {
	symbol := c.Param("symbol")
	quote, err := finnhubClient.GetQuote(symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, quote)
}

// GetNews godoc
// @Summary      Get latest news
// @Description  Returns recent news for a symbol (from EODHD)
// @Tags         news
// @Param        symbol   path   string  true  "Ticker symbol (e.g., AAPL)"
// @Produce      json
// @Success      200  {array}   sentAnalysis.NewsItem
// @Failure      500  {object}  ErrorResponse
// @Router       /finnews/{symbol} [get]
func GetNews(c *gin.Context) {
	symbol := c.Param("symbol")
	news, err := sentAnalysis.FetchData(symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, news)
}

// ---
// GetSentimentOnly fetches recent news for a symbol and returns only the aggregate sentiment.
// ---
// GetSentimentOnly godoc
// @Summary      Get aggregate sentiment only
// @Description  Fetches recent news and returns only the aggregate sentiment values
// @Tags         sentiment
// @Param        symbol   path   string  true  "Ticker symbol (e.g., AAPL)"
// @Produce      json
// @Success      200  {object}  SentimentOnlyResponse
// @Failure      500  {object}  ErrorResponse
// @Router       /sentiment/{symbol} [get]
func GetSentimentOnly(c *gin.Context) {
	symbol := c.Param("symbol")

	newsItems, err := sentAnalysis.FetchAndAnalyzeNews(symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("failed to fetch/analyze news: %v", err),
		})
		return
	}

	aggregate := sentAnalysis.FetchStockSentiment(newsItems)

	c.JSON(http.StatusOK, gin.H{
		"symbol":    symbol,
		"sentiment": aggregate,
	})
}

// GetNewsSentimentBERT fetches news for a symbol and returns both the news items with
// individual BERT sentiments and the aggregate sentiment score.
// GetNewsSentimentBERT godoc
// @Summary      Get news with BERT sentiment
// @Description  Fetches news for a symbol and returns items with BERT sentiment and aggregate
// @Tags         sentiment
// @Param        symbol   path   string  true  "Ticker symbol (e.g., AAPL)"
// @Produce      json
// @Success      200  {object}  NewsSentimentBERTResponse
// @Failure      500  {object}  ErrorResponse
// @Router       /finnewsBert/{symbol} [get]
func GetNewsSentimentBERT(c *gin.Context) {
	symbol := c.Param("symbol")

	newsItems, err := sentAnalysis.FetchAndAnalyzeNews(symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("failed to fetch/analyze news: %v", err),
		})
		return
	}

	aggregate := sentAnalysis.FetchStockSentiment(newsItems)

	c.JSON(http.StatusOK, gin.H{
		"symbol":           symbol,
		"aggregate_result": aggregate,
		"news_items":       newsItems,
	})
}

// GetStockDetail godoc
// @Summary      Get stock detail
// @Description  Returns comprehensive stock detail for a symbol
// @Tags         stocks
// @Param        symbol   path   string  true  "Ticker symbol (e.g., AAPL)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /stock/{symbol} [get]
func GetStockDetail(c *gin.Context) {
	symbol := c.Param("symbol")
	StockDetail, err := dogonomicsFetchingClient.BuildStockDetailData(symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"BuildStockDetailData error": err.Error()})
	}
	c.JSON(http.StatusOK, StockDetail)
}

// GetCompanyProfile godoc
// @Summary      Get company profile
// @Description  Returns company profile for a symbol
// @Tags         stocks
// @Param        symbol   path   string  true  "Ticker symbol (e.g., AAPL)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /profile/{symbol} [get]
func GetCompanyProfile(c *gin.Context) {
	symbol := c.Param("symbol")
	StockDetail, err := dogonomicsFetchingClient.GetCompanyProfile(symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"GetCompanyProfile error": err.Error()})
	}
	c.JSON(http.StatusOK, StockDetail)
}

// GetChartData - Uses free historical data sources
// GetChartData godoc
// @Summary      Get chart data
// @Description  Returns historical price data for a symbol
// @Tags         charts
// @Param        symbol   path   string  true  "Ticker symbol (e.g., AAPL)"
// @Param        days     query  int     false "Days of history (max 365)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /chart/{symbol} [get]
func GetChartData(c *gin.Context) {
	symbol := c.Param("symbol")
	daysStr := c.DefaultQuery("days", "30")

	days, err := strconv.Atoi(daysStr)
	if err != nil {
		days = 30
	}

	// Limit to reasonable ranges for free APIs
	if days > 365 {
		days = 365
	}

	data, err := PolygonClient.RequestHistoricalData(symbol, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, data)
}

// GetHealthStatus godoc
// @Summary      Health status
// @Description  Returns API health information and data sources
// @Tags         health
// @Produce      json
// @Success      200  {object}  interface{}
// @Router       /health [get]
func GetHealthStatus(c *gin.Context) {
	status := gin.H{
		"status":  "healthy",
		"service": "dogonomics-api",
		"version": "2.0.0-free-data",
		"data_sources": gin.H{
			"finnhub":       "active (quotes, profiles, limited news)",
			"yahoo_finance": "active (historical data)",
			"alpha_vantage": "available (requires API key)",
			"marketstack":   "available (requires API key)",
		},
	}

	c.JSON(http.StatusOK, status)
}
