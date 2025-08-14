package controller

import (
	"net/http"
	"strconv"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/DogonomicsFetching"
	"github.com/MadebyDaris/dogonomics/internal/PolygonClient"
	"github.com/MadebyDaris/dogonomics/sentAnalysis"
	"github.com/gin-gonic/gin"
)

// INIITIATE THE CLIENTS
var (
	finnhubClient = DogonomicsFetching.NewClient()
)

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
func GetQuote(c *gin.Context) {
	symbol := c.Param("symbol")
	quote, err := finnhubClient.GetQuote(symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, quote)
}
func GetNews(c *gin.Context) {
	symbol := c.Param("symbol")
	news, _ := sentAnalysis.FetchData(symbol)
	c.JSON(http.StatusOK, news)
}

func GetNewsSentimentBERT(c *gin.Context) {
	symbol := c.Param("symbol")
	news, _ := sentAnalysis.FetchData(symbol)
	sentAnalysis.RunBERTInferenceONNX(news[0].Title, "./sentAnalysis/DoggoFinBERT.onnx", "./sentAnalysis/finbert/vocab.txt")
	c.JSON(http.StatusOK, news)
}

func GetStockDetail(c *gin.Context) {
	symbol := c.Param("symbol")
	StockDetail, err := DogonomicsFetching.NewClient().BuildStockDetailData(symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"BuildStockDetailData error": err.Error()})
	}
	c.JSON(http.StatusOK, StockDetail)
}

func GetCompanyProfile(c *gin.Context) {
	symbol := c.Param("symbol")
	StockDetail, err := DogonomicsFetching.NewClient().GetCompanyProfile(symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"GetCompanyProfile error": err.Error()})
	}
	c.JSON(http.StatusOK, StockDetail)
}

// GetChartData - Uses free historical data sources
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
