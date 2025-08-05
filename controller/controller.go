package controller

import (
	"net/http"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/DogonomicsFetching"
	"github.com/MadebyDaris/dogonomics/internal/PolygonClient"
	"github.com/MadebyDaris/dogonomics/sentAnalysis"
	"github.com/gin-gonic/gin"
)

var (
	finnhubClient    = DogonomicsFetching.NewClient()
	historicalClient = DogonomicsFetching.NewYahooFinanceClient()
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
	// BERTnews :)=
	// for _, item := range news {
	// 	sentAnalysis.AnalyzeWithPython(item.Content)
	// }
	c.JSON(http.StatusOK, news)
}
