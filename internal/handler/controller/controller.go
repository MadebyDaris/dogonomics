package controller

import (
	"context"
	"fmt"
	"log"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/DogonomicsProcessing"
	"github.com/MadebyDaris/dogonomics/internal/api/coingecko"
	"github.com/MadebyDaris/dogonomics/internal/api/commodities"
	"github.com/MadebyDaris/dogonomics/internal/api/finnhub"
	"github.com/MadebyDaris/dogonomics/internal/api/forex"
	"github.com/MadebyDaris/dogonomics/internal/api/fred"
	"github.com/MadebyDaris/dogonomics/internal/api/news"
	"github.com/MadebyDaris/dogonomics/internal/api/polygon"
	"github.com/MadebyDaris/dogonomics/internal/api/treasury"
	"github.com/MadebyDaris/dogonomics/internal/cache"
	"github.com/MadebyDaris/dogonomics/internal/database"
	"github.com/MadebyDaris/dogonomics/internal/events"
	"github.com/MadebyDaris/dogonomics/internal/service/bertinference"
	"github.com/MadebyDaris/dogonomics/internal/service/sentiment"
	"github.com/MadebyDaris/dogonomics/internal/workerpool"
	"github.com/MadebyDaris/dogonomics/internal/ws"
	"github.com/gin-gonic/gin"
)

var (
	finnhubClient            *DogonomicsFetching.Client
	dogonomicsFetchingClient *DogonomicsFetching.Client
	treasuryClient           *TreasuryClient.Client
	commoditiesClient        *CommoditiesClient.Client
	newsClient               *NewsClient.NewsClient
	coinGeckoClient          *CoinGeckoClient.Client
	forexClient              *ForexClient.Client
	fredClient               *FredClient.Client
	wsHub                    *ws.Hub
	kafkaProducer            *events.Producer
)

// ErrorResponse represents a standard error payload
type ErrorResponse struct {
	Error string `json:"error"`
}

// NewsSentimentBERTResponse is the response schema for /finnewsBert/{symbol}
type NewsSentimentBERTResponse struct {
	Symbol          string                            `json:"symbol"`
	AggregateResult *sentiment.StockSentimentAnalysis `json:"aggregate_result"`
	NewsItems       []sentiment.NewsItem              `json:"news_items"`
}

// SentimentOnlyResponse is the response schema for /sentiment/{symbol}
type SentimentOnlyResponse struct {
	Symbol    string                            `json:"symbol"`
	Sentiment *sentiment.StockSentimentAnalysis `json:"sentiment"`
}

func Init(fc *DogonomicsFetching.Client) {
	finnhubClient = fc
	dogonomicsFetchingClient = fc
	treasuryClient = TreasuryClient.NewClient()
	commoditiesClient = CommoditiesClient.NewClient()
	newsClient = NewsClient.NewNewsClient()
	coinGeckoClient = CoinGeckoClient.NewClient()
	forexClient = ForexClient.NewClient()
	fredClient = FredClient.NewClient()
}

// SetWSHub sets the WebSocket hub for real-time broadcasting
func SetWSHub(h *ws.Hub) {
	wsHub = h
}

// SetKafkaProducer sets the Kafka producer for event publishing
func SetKafkaProducer(p *events.Producer) {
	kafkaProducer = p
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
	ctx := c.Request.Context()
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

	stock, _ := PolygonClient.RequestTicker(ctx, symbol, date)

	// Persist ticker data asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := database.SaveTickerData(dbCtx, symbol, stock); err != nil {
			log.Printf("Failed to save ticker data for %s: %v", symbol, err)
		}
	}()

	c.JSON(http.StatusOK, stock)
}

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
	ctx := c.Request.Context()
	symbol := c.Param("symbol")
	quote, err := finnhubClient.GetQuote(ctx, symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	// Persist quote to database asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if err := database.SaveStockQuote(dbCtx, symbol, quote); err != nil {
			log.Printf("Failed to save stock quote for %s: %v", symbol, err)
		}

		// Publish to WebSocket and Kafka
		ws.PublishQuoteEvent(wsHub, symbol, quote)
		if kafkaProducer != nil {
			kafkaProducer.PublishQuote(dbCtx, symbol, quote)
		}
	}()

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
	ctx := c.Request.Context()
	symbol := c.Param("symbol")
	news, err := sentiment.FetchData(ctx, symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Persist news items asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		for _, item := range news {
			if _, err := database.SaveNewsWithSentiment(dbCtx, symbol, &item); err != nil {
				log.Printf("Failed to save news item for %s: %v", symbol, err)
			}
		}
		// Publish to WebSocket and Kafka
		ws.PublishNewsEvent(wsHub, symbol, news)
		if kafkaProducer != nil {
			kafkaProducer.PublishNews(dbCtx, symbol, news)
		}
	}()

	c.JSON(http.StatusOK, news)
}

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
	ctx := c.Request.Context()
	symbol := c.Param("symbol")

	newsItems, err := sentiment.FetchAndAnalyzeNews(ctx, symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("failed to fetch/analyze news: %v", err),
		})
		return
	}

	aggregate := sentiment.FetchStockSentiment(ctx, newsItems)

	// Persist news items and aggregate sentiment asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		for _, newsItem := range newsItems {
			newsID, err := database.SaveNewsWithSentiment(dbCtx, symbol, &newsItem)
			if err != nil {
				log.Printf("Failed to save news item for %s: %v", symbol, err)
				continue
			}
			if err := database.SaveNewsSentiment(dbCtx, newsID, &newsItem); err != nil {
				log.Printf("Failed to save sentiment for news %s: %v", newsID, err)
			}
		}

		if err := database.SaveAggregatedSentiment(dbCtx, symbol, aggregate); err != nil {
			log.Printf("Failed to save aggregate sentiment for %s: %v", symbol, err)
		}

		// Publish sentiment to Kafka
		if kafkaProducer != nil {
			kafkaProducer.PublishSentiment(dbCtx, symbol, aggregate)
		}
	}()

	c.JSON(http.StatusOK, gin.H{
		"symbol":    symbol,
		"sentiment": aggregate,
	})
}

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
	ctx := c.Request.Context()
	symbol := c.Param("symbol")

	newsItems, err := sentiment.FetchAndAnalyzeNews(ctx, symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("failed to fetch/analyze news: %v", err),
		})
		return
	}

	aggregate := sentiment.FetchStockSentiment(ctx, newsItems)

	// Persist news items and sentiment to database asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		// Save each news item
		for _, newsItem := range newsItems {
			newsID, err := database.SaveNewsWithSentiment(dbCtx, symbol, &newsItem)
			if err != nil {
				log.Printf("Failed to save news item for %s: %v", symbol, err)
				continue
			}

			// Save sentiment analysis for this news item
			if err := database.SaveNewsSentiment(dbCtx, newsID, &newsItem); err != nil {
				log.Printf("Failed to save sentiment analysis for news %s: %v", newsID, err)
			}
		}

		// Save aggregate sentiment
		if err := database.SaveAggregatedSentiment(dbCtx, symbol, aggregate); err != nil {
			log.Printf("Failed to save aggregate sentiment for %s: %v", symbol, err)
		}

		// Publish to WebSocket and Kafka
		ws.PublishNewsEvent(wsHub, symbol, newsItems)
		if kafkaProducer != nil {
			kafkaProducer.PublishSentiment(dbCtx, symbol, aggregate)
			kafkaProducer.PublishNews(dbCtx, symbol, newsItems)
		}
	}()

	c.JSON(http.StatusOK, gin.H{
		"symbol":           symbol,
		"aggregate_result": aggregate,
		"news_items":       newsItems,
	})
}

// InferenceRequest represents the request body for FinBERT inference
type InferenceRequest struct {
	Text string `json:"text" binding:"required"`
}

// RunFinBertInference godoc
// @Summary      Run FinBERT inference on custom text
// @Description  Analyzes sentiment of provided text using DoggoFinBERT model
// @Tags         sentiment
// @Accept       json
// @Produce      json
// @Param        request  body      InferenceRequest  true  "Text to analyze"
// @Success      200      {object}  BertInference.BERTSentiment
// @Failure      400      {object}  ErrorResponse
// @Failure      500      {object}  ErrorResponse
// @Router       /finbert/inference [post]
func RunFinBertInference(c *gin.Context) {
	var req InferenceRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request: text field is required",
		})
		return
	}

	if len(req.Text) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Text cannot be empty",
		})
		return
	}

	modelPath := "./assets/sentiment/DoggoFinBERT.onnx"
	sentimentResult, err := sentiment.RunBERTInferenceONNX(req.Text, modelPath, "")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("Failed to run BERT inference: %v", err),
		})
		return
	}

	c.JSON(http.StatusOK, sentimentResult)
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
	ctx := c.Request.Context()
	symbol := c.Param("symbol")
	StockDetail, err := dogonomicsFetchingClient.BuildStockDetailData(ctx, symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"BuildStockDetailData error": err.Error()})
		return
	}

	// Persist chart data and quote asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if len(StockDetail.ChartData) > 0 {
			if err := database.SaveChartData(dbCtx, symbol, StockDetail.ChartData, "polygon"); err != nil {
				log.Printf("Failed to save chart data for %s: %v", symbol, err)
			}
		}
	}()

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
	ctx := c.Request.Context()
	symbol := c.Param("symbol")
	profile, err := dogonomicsFetchingClient.GetCompanyProfile(ctx, symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"GetCompanyProfile error": err.Error()})
		return
	}

	// Persist company profile asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := database.SaveCompanyProfile(dbCtx, symbol, profile); err != nil {
			log.Printf("Failed to save company profile for %s: %v", symbol, err)
		}
	}()

	c.JSON(http.StatusOK, profile)
}

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

	if days > 365 {
		days = 365
	}

	data, err := PolygonClient.RequestHistoricalData(c.Request.Context(), symbol, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Persist chart data asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := database.SaveChartData(dbCtx, symbol, data, "polygon"); err != nil {
			log.Printf("Failed to save chart data for %s: %v", symbol, err)
		}
	}()

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
		"version": "2.1.0-with-treasury-commodities",
		"data_sources": gin.H{
			"finnhub":       "active (quotes, profiles, limited news)",
			"yahoo_finance": "active (historical data)",
			"treasury_gov":  "active (bonds, rates, debt data - FREE)",
			"alpha_vantage": fmt.Sprintf("commodities (%s)", func() string {
				if commoditiesClient.IsAPIKeyConfigured() {
					return "configured"
				}
				return "API key required"
			}()),
		},
		"features": gin.H{
			"stocks":      "real-time quotes, profiles, charts",
			"news":        "financial news with sentiment analysis",
			"bert":        "FinBERT sentiment analysis",
			"treasury":    "bond rates, yield curve, public debt",
			"commodities": "oil, gas, metals, agriculture prices",
			"database":    "persistent storage with PostgreSQL",
		},
	}

	c.JSON(http.StatusOK, status)
}

// GetTreasuryYieldCurve godoc
// @Summary      Get latest treasury yield curve
// @Description  Returns the most recent treasury yield rates for all maturities
// @Tags         treasury
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /treasury/yield-curve [get]
func GetTreasuryYieldCurve(c *gin.Context) {
	data, err := treasuryClient.GetLatestYieldCurve(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Persist treasury data asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := database.SaveTreasuryData(dbCtx, "yield_curve", data); err != nil {
			log.Printf("Failed to save treasury yield curve: %v", err)
		}
	}()

	c.JSON(http.StatusOK, data)
}

// GetTreasuryRates godoc
// @Summary      Get treasury rates history
// @Description  Returns daily treasury yield rates for specified number of days
// @Tags         treasury
// @Param        days   query  int  false  "Days of history (default: 30)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /treasury/rates [get]
func GetTreasuryRates(c *gin.Context) {
	daysStr := c.DefaultQuery("days", "30")
	days, err := strconv.Atoi(daysStr)
	if err != nil {
		days = 30
	}

	if days > 365 {
		days = 365
	}

	data, err := treasuryClient.GetDailyTreasuryYieldRates(c.Request.Context(), days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Persist treasury rates asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := database.SaveTreasuryData(dbCtx, "daily_rates", data); err != nil {
			log.Printf("Failed to save treasury rates: %v", err)
		}
	}()

	c.JSON(http.StatusOK, data)
}

// GetPublicDebt godoc
// @Summary      Get public debt data
// @Description  Returns US public debt to the penny over specified time period
// @Tags         treasury
// @Param        days   query  int  false  "Days of history (default: 90)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /treasury/debt [get]
func GetPublicDebt(c *gin.Context) {
	daysStr := c.DefaultQuery("days", "90")
	days, err := strconv.Atoi(daysStr)
	if err != nil {
		days = 90
	}

	if days > 365 {
		days = 365
	}

	data, err := treasuryClient.GetDebtToThePenny(c.Request.Context(), days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Persist public debt data asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := database.SaveTreasuryData(dbCtx, "public_debt", data); err != nil {
			log.Printf("Failed to save public debt data: %v", err)
		}
	}()

	c.JSON(http.StatusOK, data)
}

// GetCommodityOil godoc
// @Summary      Get crude oil prices
// @Description  Returns WTI and Brent crude oil price data
// @Tags         commodities
// @Param        type   query  string  false  "Oil type: wti or brent (default: wti)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /commodities/oil [get]
func GetCommodityOil(c *gin.Context) {
	ctx := c.Request.Context()
	oilType := c.DefaultQuery("type", "wti")

	var data *CommoditiesClient.CommodityData
	var err error

	switch oilType {
	case "brent":
		data, err = commoditiesClient.GetCrudeOilBrent(ctx)
	default:
		data, err = commoditiesClient.GetCrudeOilWTI(ctx)
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Persist commodity data asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := database.SaveCommodityData(dbCtx, data); err != nil {
			log.Printf("Failed to save commodity oil data: %v", err)
		}
	}()

	c.JSON(http.StatusOK, data)
}

// GetCommodityGas godoc
// @Summary      Get natural gas prices
// @Description  Returns natural gas price data
// @Tags         commodities
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /commodities/gas [get]
func GetCommodityGas(c *gin.Context) {
	data, err := commoditiesClient.GetNaturalGas(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Persist commodity data asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := database.SaveCommodityData(dbCtx, data); err != nil {
			log.Printf("Failed to save commodity gas data: %v", err)
		}
	}()

	c.JSON(http.StatusOK, data)
}

// GetCommodityMetals godoc
// @Summary      Get metals prices
// @Description  Returns price data for metals (copper, aluminum)
// @Tags         commodities
// @Param        metal   query  string  false  "Metal: copper or aluminum (default: copper)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /commodities/metals [get]
func GetCommodityMetals(c *gin.Context) {
	ctx := c.Request.Context()
	metal := c.DefaultQuery("metal", "copper")

	var data *CommoditiesClient.CommodityData
	var err error

	switch metal {
	case "aluminum", "aluminium":
		data, err = commoditiesClient.GetAluminum(ctx)
	default:
		data, err = commoditiesClient.GetCopper(ctx)
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Persist commodity data asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := database.SaveCommodityData(dbCtx, data); err != nil {
			log.Printf("Failed to save commodity metals data: %v", err)
		}
	}()

	c.JSON(http.StatusOK, data)
}

// GetCommodityAgriculture godoc
// @Summary      Get agriculture commodity prices
// @Description  Returns price data for agricultural commodities
// @Tags         commodities
// @Param        commodity   query  string  false  "Commodity: wheat, corn, cotton, sugar, coffee (default: wheat)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /commodities/agriculture [get]
func GetCommodityAgriculture(c *gin.Context) {
	ctx := c.Request.Context()
	commodity := c.DefaultQuery("commodity", "wheat")

	var data *CommoditiesClient.CommodityData
	var err error

	switch commodity {
	case "corn":
		data, err = commoditiesClient.GetCorn(ctx)
	case "cotton":
		data, err = commoditiesClient.GetCotton(ctx)
	case "sugar":
		data, err = commoditiesClient.GetSugar(ctx)
	case "coffee":
		data, err = commoditiesClient.GetCoffee(ctx)
	default:
		data, err = commoditiesClient.GetWheat(ctx)
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Persist commodity data asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := database.SaveCommodityData(dbCtx, data); err != nil {
			log.Printf("Failed to save commodity agriculture data: %v", err)
		}
	}()

	c.JSON(http.StatusOK, data)
}

// GetGeneralFinanceNews godoc
// @Summary      Get general market news
// @Description  Returns general finance and market news (not symbol-specific)
// @Tags         news
// @Param        category   query  string  false  "News category: general, forex, crypto, merger (default: general)"
// @Param        limit      query  int     false  "Number of articles to return (default: 10)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /news/general [get]
func GetGeneralFinanceNews(c *gin.Context) {
	ctx := c.Request.Context()
	category := c.DefaultQuery("category", "general")
	limitStr := c.DefaultQuery("limit", "10")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 {
		limit = 10
	}
	if limit > 50 {
		limit = 50
	}

	articles, err := newsClient.GetGeneralMarketNews(ctx, category, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Persist news articles asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		for _, article := range articles {
			if err := database.SaveNewsArticle(dbCtx, "MARKET", &article); err != nil {
				log.Printf("Failed to save general news article: %v", err)
			}
		}
	}()

	c.JSON(http.StatusOK, gin.H{
		"category": category,
		"count":    len(articles),
		"articles": articles,
	})
}

// GetNewsBySymbolMultiSource godoc
// @Summary      Get news for a symbol from multiple sources
// @Description  Returns news for a specific stock symbol aggregated from multiple sources
// @Tags         news
// @Param        symbol   path   string  true   "Stock symbol (e.g., AAPL)"
// @Param        limit    query  int     false  "Number of articles to return (default: 10)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /news/symbol/{symbol} [get]
func GetNewsBySymbolMultiSource(c *gin.Context) {
	ctx := c.Request.Context()
	symbol := c.Param("symbol")
	limitStr := c.DefaultQuery("limit", "10")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 {
		limit = 10
	}
	if limit > 50 {
		limit = 50
	}

	articles, err := newsClient.GetNewsBySymbol(ctx, symbol, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Persist news articles asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		for _, article := range articles {
			if err := database.SaveNewsArticle(dbCtx, symbol, &article); err != nil {
				log.Printf("Failed to save news article for %s: %v", symbol, err)
			}
		}
	}()

	c.JSON(http.StatusOK, gin.H{
		"symbol":   symbol,
		"count":    len(articles),
		"articles": articles,
	})
}

// SearchNews godoc
// @Summary      Search news by keyword
// @Description  Returns news articles matching the search keyword
// @Tags         news
// @Param        q      query  string  true   "Search keyword"
// @Param        limit  query  int     false  "Number of articles to return (default: 10)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      400  {object}  ErrorResponse
// @Failure      500  {object}  ErrorResponse
// @Router       /news/search [get]
func SearchNews(c *gin.Context) {
	keyword := c.Query("q")
	if keyword == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "query parameter 'q' is required"})
		return
	}

	limitStr := c.DefaultQuery("limit", "10")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 {
		limit = 10
	}
	if limit > 50 {
		limit = 50
	}

	articles, err := newsClient.GetNewsByKeyword(c.Request.Context(), keyword, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Persist search result articles asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		for _, article := range articles {
			if err := database.SaveNewsArticle(dbCtx, "SEARCH", &article); err != nil {
				log.Printf("Failed to save search news article: %v", err)
			}
		}
	}()

	c.JSON(http.StatusOK, gin.H{
		"keyword":  keyword,
		"count":    len(articles),
		"articles": articles,
	})
}

// GetGeneralNewsWithSentiment godoc
// @Summary      Get general market news with FinBERT sentiment analysis
// @Description  Returns general market news with sentiment analysis applied to each article
// @Tags         news
// @Param        category   query  string  false  "News category: general, forex, crypto, merger (default: general)"
// @Param        limit      query  int     false  "Number of articles to analyze (default: 5, max: 10)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /news/general/sentiment [get]
func GetGeneralNewsWithSentiment(c *gin.Context) {
	ctx := c.Request.Context()
	category := c.DefaultQuery("category", "general")
	limitStr := c.DefaultQuery("limit", "5")

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 {
		limit = 5
	}
	if limit > 10 {
		limit = 10
	}

	articles, err := newsClient.GetGeneralMarketNews(ctx, category, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Apply FinBERT sentiment via worker pool
	type ArticleWithSentiment struct {
		NewsClient.NewsArticle
		Sentiment *BertInference.BERTSentiment `json:"sentiment"`
	}

	articlesWithSentiment := make([]ArticleWithSentiment, len(articles))
	for i, article := range articles {
		articlesWithSentiment[i] = ArticleWithSentiment{NewsArticle: article}
	}

	tasks := make([]workerpool.Task, len(articles))
	for i, article := range articles {
		idx := i
		title := article.Title
		desc := article.Description
		tasks[i] = func(_ context.Context) error {
			sentiment, err := sentiment.AnalyzeNews(title, desc)
			if err != nil {
				log.Printf("Failed to analyze sentiment for article: %v", err)
				return nil // non-fatal
			}
			articlesWithSentiment[idx].Sentiment = sentiment
			return nil
		}
	}

	workerpool.Run(ctx, 3, tasks)

	// Calculate aggregate sentiment
	var totalScore float64
	var totalConfidence float64
	sentimentCounts := make(map[string]int)

	for _, article := range articlesWithSentiment {
		if article.Sentiment != nil {
			totalScore += article.Sentiment.Score
			totalConfidence += article.Sentiment.Confidence
			sentimentCounts[article.Sentiment.Label]++
		}
	}

	avgScore := 0.0
	avgConfidence := 0.0
	if len(articlesWithSentiment) > 0 {
		avgScore = totalScore / float64(len(articlesWithSentiment))
		avgConfidence = totalConfidence / float64(len(articlesWithSentiment))
	}

	c.JSON(http.StatusOK, gin.H{
		"category": category,
		"count":    len(articlesWithSentiment),
		"aggregate_sentiment": gin.H{
			"average_score":      avgScore,
			"average_confidence": avgConfidence,
			"sentiment_counts":   sentimentCounts,
		},
		"articles": articlesWithSentiment,
	})

	// Persist news articles asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		for _, article := range articles {
			if err := database.SaveNewsArticle(dbCtx, "MARKET", &article); err != nil {
				log.Printf("Failed to save general news sentiment article: %v", err)
			}
		}
	}()
}

// ============================================================
// Financial Indicators & Dogonomics Advice
// ============================================================

// GetFinancialIndicators godoc
// @Summary      Get comprehensive financial indicators for a symbol
// @Description  Returns technical indicators, key metrics, and financial health metrics computed from Finnhub data
// @Tags         indicators
// @Param        symbol  path  string  true  "Ticker symbol (e.g., AAPL)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /indicators/{symbol} [get]
func GetFinancialIndicators(c *gin.Context) {
	symbol := c.Param("symbol")
	ctx := c.Request.Context()

	// Fetch financials, quote, and chart data concurrently
	type fetchResult struct {
		financials *DogonomicsProcessing.BasicFinancials
		quote      *DogonomicsFetching.Quote
		chart      []DogonomicsProcessing.ChartDataPoint
		err        string
	}

	var financials *DogonomicsProcessing.BasicFinancials
	var quote *DogonomicsFetching.Quote
	var chart []DogonomicsProcessing.ChartDataPoint
	var financialsErr, quoteErr, chartErr error

	done := make(chan struct{}, 3)

	go func() {
		financials, financialsErr = dogonomicsFetchingClient.GetBasicFinancials(ctx, symbol)
		done <- struct{}{}
	}()
	go func() {
		quote, quoteErr = dogonomicsFetchingClient.GetQuote(ctx, symbol)
		done <- struct{}{}
	}()
	go func() {
		chart, chartErr = PolygonClient.RequestHistoricalData(ctx, symbol, 60)
		done <- struct{}{}
	}()
	for i := 0; i < 3; i++ {
		<-done
	}

	if quoteErr != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch quote: " + quoteErr.Error()})
		return
	}

	// Extract key financial metrics from Finnhub BasicFinancials
	keyMetrics := map[string]interface{}{}
	if financials != nil && financialsErr == nil {
		metricKeys := []string{
			"peBasicExclExtraTTM", "epsBasicExclExtraTTM", "psTTM", "pbQuarterly",
			"currentRatioQuarterly", "quickRatioQuarterly", "debtEquityQuarterly",
			"roeTTM", "roaTTM", "grossMarginTTM", "operatingMarginTTM", "netProfitMarginTTM",
			"revenueGrowthTTM5Y", "epsGrowthTTM5Y", "dividendYieldIndicatedAnnual",
			"payoutRatioTTM", "52WeekHigh", "52WeekLow", "52WeekHighDate", "52WeekLowDate",
			"beta", "10DayAverageTradingVolume", "3MonthAverageTradingVolume",
			"marketCapitalization", "revenuePerShareTTM", "bookValuePerShareQuarterly",
		}
		for _, key := range metricKeys {
			if val, exists := financials.Metric[key]; exists && val != nil {
				keyMetrics[key] = val
			}
		}
	}

	// Compute technical indicators from chart data
	type TechIndicator struct {
		Name   string  `json:"name"`
		Value  float64 `json:"value"`
		Signal string  `json:"signal"` // BUY, SELL, HOLD
	}

	var technicals []TechIndicator

	if chart != nil && chartErr == nil && len(chart) > 0 {
		closes := make([]float64, len(chart))
		for i, pt := range chart {
			closes[i] = pt.Close
		}
		currentPrice := quote.CurrentPrice

		// SMA 20
		if len(closes) >= 20 {
			sum := 0.0
			for _, v := range closes[len(closes)-20:] {
				sum += v
			}
			sma20 := sum / 20.0
			signal := "HOLD"
			if currentPrice > sma20*1.02 {
				signal = "BUY"
			} else if currentPrice < sma20*0.98 {
				signal = "SELL"
			}
			technicals = append(technicals, TechIndicator{Name: "SMA_20", Value: sma20, Signal: signal})
		}

		// SMA 50
		if len(closes) >= 50 {
			sum := 0.0
			for _, v := range closes[len(closes)-50:] {
				sum += v
			}
			sma50 := sum / 50.0
			signal := "HOLD"
			if currentPrice > sma50*1.02 {
				signal = "BUY"
			} else if currentPrice < sma50*0.98 {
				signal = "SELL"
			}
			technicals = append(technicals, TechIndicator{Name: "SMA_50", Value: sma50, Signal: signal})
		}

		// RSI 14
		if len(closes) >= 15 {
			gains := 0.0
			losses := 0.0
			start := len(closes) - 15
			for i := start + 1; i < len(closes); i++ {
				diff := closes[i] - closes[i-1]
				if diff > 0 {
					gains += diff
				} else {
					losses -= diff
				}
			}
			avgGain := gains / 14.0
			avgLoss := losses / 14.0
			rsi := 50.0
			if avgLoss > 0 {
				rs := avgGain / avgLoss
				rsi = 100.0 - (100.0 / (1.0 + rs))
			} else if avgGain > 0 {
				rsi = 100.0
			}
			signal := "HOLD"
			if rsi < 30 {
				signal = "BUY" // Oversold
			} else if rsi > 70 {
				signal = "SELL" // Overbought
			}
			technicals = append(technicals, TechIndicator{Name: "RSI_14", Value: rsi, Signal: signal})
		}

		// Price vs 52-week range
		if financials != nil {
			if high52, ok := financials.Metric["52WeekHigh"].(float64); ok {
				if low52, ok := financials.Metric["52WeekLow"].(float64); ok {
					if high52 > low52 {
						position := (currentPrice - low52) / (high52 - low52) * 100.0
						signal := "HOLD"
						if position < 20 {
							signal = "BUY" // Near 52w low
						} else if position > 80 {
							signal = "SELL" // Near 52w high
						}
						technicals = append(technicals, TechIndicator{Name: "52W_POSITION", Value: position, Signal: signal})
					}
				}
			}
		}

		// Volatility (standard deviation of daily returns)
		if len(closes) >= 20 {
			returns := make([]float64, len(closes)-1)
			for i := 1; i < len(closes); i++ {
				if closes[i-1] > 0 {
					returns[i-1] = (closes[i] - closes[i-1]) / closes[i-1]
				}
			}
			mean := 0.0
			for _, r := range returns {
				mean += r
			}
			mean /= float64(len(returns))
			variance := 0.0
			for _, r := range returns {
				variance += (r - mean) * (r - mean)
			}
			variance /= float64(len(returns))
			// Annualized volatility
			annVol := math.Sqrt(variance) * math.Sqrt(252.0)
			signal := "HOLD"
			if annVol > 0.4 {
				signal = "SELL" // High volatility
			} else if annVol < 0.15 {
				signal = "BUY" // Low volatility
			}
			technicals = append(technicals, TechIndicator{Name: "VOLATILITY", Value: annVol * 100, Signal: signal})
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"symbol":               symbol,
		"current_price":        quote.CurrentPrice,
		"change":               quote.Change,
		"change_percent":       quote.PercentChange,
		"key_metrics":          keyMetrics,
		"technical_indicators": technicals,
	})
}

// GetDogonomicsAdvice godoc
// @Summary      Get Dogonomics aggregate advice for a symbol
// @Description  Combines sentiment analysis, technical indicators, and financial metrics into an aggregate BUY/SELL/HOLD recommendation
// @Tags         advice
// @Param        symbol  path  string  true  "Ticker symbol (e.g., AAPL)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /advice/{symbol} [get]
func GetDogonomicsAdvice(c *gin.Context) {
	symbol := c.Param("symbol")
	ctx := c.Request.Context()

	// Fetch everything concurrently: financials, quote, chart, news sentiment
	var financials *DogonomicsProcessing.BasicFinancials
	var quote *DogonomicsFetching.Quote
	var chart []DogonomicsProcessing.ChartDataPoint
	var financialsErr, quoteErr, chartErr error

	type sentimentResult struct {
		label      string
		score      float64
		confidence float64
		err        error
	}
	sentCh := make(chan sentimentResult, 1)
	done := make(chan struct{}, 3)

	go func() {
		financials, financialsErr = dogonomicsFetchingClient.GetBasicFinancials(ctx, symbol)
		done <- struct{}{}
	}()
	go func() {
		quote, quoteErr = dogonomicsFetchingClient.GetQuote(ctx, symbol)
		done <- struct{}{}
	}()
	go func() {
		chart, chartErr = PolygonClient.RequestHistoricalData(ctx, symbol, 60)
		done <- struct{}{}
	}()
	go func() {
		// Get news and run sentiment
		articles, err := newsClient.GetNewsBySymbol(ctx, symbol, 8)
		if err != nil {
			articles, err = newsClient.GetNewsByKeyword(ctx, symbol, 8)
		}
		if err != nil || len(articles) == 0 {
			sentCh <- sentimentResult{label: "neutral", score: 0, confidence: 0, err: err}
			return
		}
		// Analyze sentiment
		var totalScore, totalConf float64
		counts := map[string]int{"positive": 0, "neutral": 0, "negative": 0}
		analyzed := 0
		for _, a := range articles {
			sent, err := sentiment.AnalyzeNews(a.Title, a.Description)
			if err == nil && sent != nil {
				totalScore += sent.Score
				totalConf += sent.Confidence
				counts[sent.Label]++
				analyzed++
			}
		}
		if analyzed == 0 {
			sentCh <- sentimentResult{label: "neutral", score: 0, confidence: 0}
			return
		}
		avgScore := totalScore / float64(analyzed)
		avgConf := totalConf / float64(analyzed)
		label := "neutral"
		if counts["positive"] > counts["negative"] && counts["positive"] > counts["neutral"] {
			label = "positive"
		} else if counts["negative"] > counts["positive"] && counts["negative"] > counts["neutral"] {
			label = "negative"
		}
		sentCh <- sentimentResult{label: label, score: avgScore, confidence: avgConf}
	}()

	for i := 0; i < 3; i++ {
		<-done
	}
	sentResult := <-sentCh

	if quoteErr != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch quote: " + quoteErr.Error()})
		return
	}

	// ---- Score Components ----
	// Each component contributes to a -100 to +100 scale
	// Positive = bullish/buy, Negative = bearish/sell

	type ScoreComponent struct {
		Name    string  `json:"name"`
		Score   float64 `json:"score"` // -100 to +100
		Weight  float64 `json:"weight"`
		Signal  string  `json:"signal"`
		Details string  `json:"details"`
	}
	var components []ScoreComponent

	// 1. Sentiment Score (weight: 25%)
	sentScore := 0.0
	if sentResult.err == nil {
		switch sentResult.label {
		case "positive":
			sentScore = sentResult.score * 100
		case "negative":
			sentScore = sentResult.score * -100
		}
	}
	sentSignal := "HOLD"
	if sentScore > 20 {
		sentSignal = "BUY"
	} else if sentScore < -20 {
		sentSignal = "SELL"
	}
	components = append(components, ScoreComponent{
		Name: "News Sentiment", Score: sentScore, Weight: 0.25, Signal: sentSignal,
		Details: fmt.Sprintf("FinBERT analysis: %s (%.1f%% confidence)", sentResult.label, sentResult.confidence*100),
	})

	// 2. Technical Score (weight: 30%)
	techScore := 0.0
	techCount := 0
	if chart != nil && chartErr == nil && len(chart) > 0 {
		closes := make([]float64, len(chart))
		for i, pt := range chart {
			closes[i] = pt.Close
		}
		currentPrice := quote.CurrentPrice

		// SMA trend
		if len(closes) >= 20 {
			sum := 0.0
			for _, v := range closes[len(closes)-20:] {
				sum += v
			}
			sma20 := sum / 20.0
			if currentPrice > sma20 {
				techScore += 30
			} else {
				techScore -= 30
			}
			techCount++
		}

		// RSI
		if len(closes) >= 15 {
			gains, losses := 0.0, 0.0
			start := len(closes) - 15
			for i := start + 1; i < len(closes); i++ {
				diff := closes[i] - closes[i-1]
				if diff > 0 {
					gains += diff
				} else {
					losses -= diff
				}
			}
			avgGain := gains / 14.0
			avgLoss := losses / 14.0
			rsi := 50.0
			if avgLoss > 0 {
				rsi = 100.0 - (100.0 / (1.0 + avgGain/avgLoss))
			}
			if rsi < 30 {
				techScore += 40 // Oversold = buy signal
			} else if rsi > 70 {
				techScore -= 40 // Overbought = sell signal
			}
			techCount++
		}

		// Price momentum (5-day)
		if len(closes) >= 5 {
			fiveDayReturn := (closes[len(closes)-1] - closes[len(closes)-5]) / closes[len(closes)-5] * 100
			if fiveDayReturn > 2 {
				techScore += 20
			} else if fiveDayReturn < -2 {
				techScore -= 20
			}
			techCount++
		}
	}
	if techCount > 0 {
		techScore = techScore / float64(techCount) * (100.0 / 40.0)
		if techScore > 100 {
			techScore = 100
		} else if techScore < -100 {
			techScore = -100
		}
	}
	techSignal := "HOLD"
	if techScore > 20 {
		techSignal = "BUY"
	} else if techScore < -20 {
		techSignal = "SELL"
	}
	components = append(components, ScoreComponent{
		Name: "Technical Analysis", Score: techScore, Weight: 0.30, Signal: techSignal,
		Details: fmt.Sprintf("Based on SMA, RSI, and momentum from %d-day chart", len(chart)),
	})

	// 3. Valuation Score (weight: 25%)
	valScore := 0.0
	valDetails := ""
	if financials != nil && financialsErr == nil {
		valFactors := 0

		// PE Ratio
		if pe, ok := financials.Metric["peBasicExclExtraTTM"].(float64); ok && pe > 0 {
			if pe < 15 {
				valScore += 40 // Undervalued
			} else if pe > 30 {
				valScore -= 30 // Expensive
			} else if pe < 20 {
				valScore += 15 // Fair
			}
			valFactors++
			valDetails += fmt.Sprintf("P/E: %.1f, ", pe)
		}

		// ROE
		if roe, ok := financials.Metric["roeTTM"].(float64); ok {
			if roe > 15 {
				valScore += 30
			} else if roe < 5 {
				valScore -= 20
			}
			valFactors++
		}

		// Profit Margin
		if margin, ok := financials.Metric["netProfitMarginTTM"].(float64); ok {
			if margin > 15 {
				valScore += 25
			} else if margin < 0 {
				valScore -= 30
			}
			valFactors++
		}

		// Debt/Equity
		if de, ok := financials.Metric["debtEquityQuarterly"].(float64); ok {
			if de < 50 {
				valScore += 20
			} else if de > 150 {
				valScore -= 25
			}
			valFactors++
		}

		if valFactors > 0 {
			valScore = valScore / float64(valFactors) * (100.0 / 40.0)
			if valScore > 100 {
				valScore = 100
			} else if valScore < -100 {
				valScore = -100
			}
		}
	}
	valSignal := "HOLD"
	if valScore > 20 {
		valSignal = "BUY"
	} else if valScore < -20 {
		valSignal = "SELL"
	}
	components = append(components, ScoreComponent{
		Name: "Fundamental Valuation", Score: valScore, Weight: 0.25, Signal: valSignal,
		Details: valDetails + "ROE, margins, debt analysis",
	})

	// 4. Price Action Score (weight: 20%)
	priceScore := 0.0
	if quote != nil {
		if quote.PercentChange > 2.0 {
			priceScore = 30
		} else if quote.PercentChange > 0 {
			priceScore = 10
		} else if quote.PercentChange < -2.0 {
			priceScore = -30
		} else if quote.PercentChange < 0 {
			priceScore = -10
		}

		// 52-week position
		if financials != nil {
			if high52, ok := financials.Metric["52WeekHigh"].(float64); ok {
				if low52, ok := financials.Metric["52WeekLow"].(float64); ok {
					if high52 > low52 {
						pos := (quote.CurrentPrice - low52) / (high52 - low52)
						if pos < 0.25 {
							priceScore += 40 // Near yearly low - potential value
						} else if pos > 0.9 {
							priceScore -= 20 // Near yearly high - potential risk
						}
					}
				}
			}
		}

		if priceScore > 100 {
			priceScore = 100
		} else if priceScore < -100 {
			priceScore = -100
		}
	}
	priceSignal := "HOLD"
	if priceScore > 20 {
		priceSignal = "BUY"
	} else if priceScore < -20 {
		priceSignal = "SELL"
	}
	components = append(components, ScoreComponent{
		Name: "Price Action", Score: priceScore, Weight: 0.20, Signal: priceSignal,
		Details: fmt.Sprintf("Today: %+.2f%%, 52-week analysis", quote.PercentChange),
	})

	// ---- Aggregate ----
	totalWeightedScore := 0.0
	for _, comp := range components {
		totalWeightedScore += comp.Score * comp.Weight
	}

	recommendation := "HOLD"
	if totalWeightedScore > 30 {
		recommendation = "STRONG BUY"
	} else if totalWeightedScore > 10 {
		recommendation = "BUY"
	} else if totalWeightedScore < -30 {
		recommendation = "STRONG SELL"
	} else if totalWeightedScore < -10 {
		recommendation = "SELL"
	}

	// Confidence level based on data availability
	confidence := 0.0
	dataPoints := 0
	if financials != nil && financialsErr == nil {
		confidence += 0.3
		dataPoints++
	}
	if chart != nil && chartErr == nil && len(chart) > 10 {
		confidence += 0.3
		dataPoints++
	}
	if sentResult.err == nil && sentResult.confidence > 0 {
		confidence += 0.2
		dataPoints++
	}
	if quote != nil {
		confidence += 0.2
		dataPoints++
	}

	c.JSON(http.StatusOK, gin.H{
		"symbol":         symbol,
		"recommendation": recommendation,
		"score":          totalWeightedScore,
		"confidence":     confidence,
		"current_price":  quote.CurrentPrice,
		"change_percent": quote.PercentChange,
		"components":     components,
		"data_points":    dataPoints,
	})
}

// ============================================================
// Forex & Crypto Endpoints
// ============================================================

// GetForexRates godoc
// @Summary      Get forex exchange rates
// @Description  Returns live forex exchange rates for the given base currency
// @Tags         forex
// @Param        base  query  string  false  "Base currency (default: USD)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /forex/rates [get]
func GetForexRates(c *gin.Context) {
	base := c.DefaultQuery("base", "USD")

	rates, err := forexClient.GetLatestRates(base)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Filter to major currencies for a cleaner response
	majorPairs := []string{"EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY", "NZD", "SEK", "NOK", "MXN", "SGD", "HKD", "KRW", "INR", "BRL", "ZAR", "TRY", "RUB", "PLN"}
	majorSet := make(map[string]bool)
	for _, p := range majorPairs {
		majorSet[p] = true
	}

	type ForexPair struct {
		Symbol string  `json:"symbol"`
		Rate   float64 `json:"rate"`
		Pair   string  `json:"pair"`
	}

	var pairs []ForexPair
	for symbol, rate := range rates.Rates {
		if majorSet[symbol] {
			pairs = append(pairs, ForexPair{
				Symbol: symbol,
				Rate:   rate,
				Pair:   base + "/" + symbol,
			})
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"base":  base,
		"count": len(pairs),
		"rates": pairs,
	})
}

// GetForexSymbols godoc
// @Summary      Get available forex symbols
// @Description  Returns list of available forex symbols on the given exchange
// @Tags         forex
// @Param        exchange  query  string  false  "Exchange name (default: oanda)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /forex/symbols [get]
func GetForexSymbols(c *gin.Context) {
	exchange := c.DefaultQuery("exchange", "oanda")
	ctx := c.Request.Context()

	symbols, err := dogonomicsFetchingClient.GetForexSymbols(ctx, exchange)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"exchange": exchange,
		"count":    len(symbols),
		"symbols":  symbols,
	})
}

// GetCryptoQuotes godoc
// @Summary      Get crypto quotes for popular pairs
// @Description  Returns latest candle data for popular cryptocurrency pairs
// @Tags         crypto
// @Param        exchange  query  string  false  "Exchange name (default: binance)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /crypto/quotes [get]
func GetCryptoQuotes(c *gin.Context) {
	// Map common tickers to CoinGecko IDs
	symbolToID := map[string]string{
		"BTC":   "bitcoin",
		"ETH":   "ethereum",
		"BNB":   "binancecoin",
		"SOL":   "solana",
		"XRP":   "ripple",
		"DOGE":  "dogecoin",
		"ADA":   "cardano",
		"DOT":   "polkadot",
		"AVAX":  "avalanche-2",
		"MATIC": "matic-network",
	}

	var ids []string
	for _, id := range symbolToID {
		ids = append(ids, id)
	}

	markets, err := coinGeckoClient.GetCoinsMarkets("usd", ids)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	type CryptoQuote struct {
		Symbol        string  `json:"symbol"`
		DisplaySymbol string  `json:"display_symbol"`
		Name          string  `json:"name"`
		Price         float64 `json:"price"`
		High24h       float64 `json:"high_24h"`
		Low24h        float64 `json:"low_24h"`
		Open          float64 `json:"open"`
		Volume        float64 `json:"volume"`
		Change        float64 `json:"change"`
		ChangePercent float64 `json:"change_percent"`
	}

	var quotes []CryptoQuote
	for _, m := range markets {
		// Calculate open approx
		open := m.CurrentPrice - m.PriceChange24h

		quotes = append(quotes, CryptoQuote{
			Symbol:        strings.ToUpper(m.Symbol),
			DisplaySymbol: strings.ToUpper(m.Symbol) + "/USDT", // Keep format expected by frontend
			Name:          m.Name,
			Price:         m.CurrentPrice,
			High24h:       m.High24h,
			Low24h:        m.Low24h,
			Open:          open,
			Volume:        m.TotalVolume,
			Change:        m.PriceChange24h,
			ChangePercent: m.PriceChangePercentage24h,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"exchange": "coingecko",
		"count":    len(quotes),
		"quotes":   quotes,
	})
}

// GetEconomicIndicators godoc
// @Summary      Get major economic indicators
// @Description  Returns key economic data from FRED (GDP, CPI, Unemployment, Fed Funds)
// @Tags         economy
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /economy/indicators [get]
func GetEconomicIndicators(c *gin.Context) {
	indicators := map[string]string{
		"GDP":      "Gross Domestic Product",
		"CPIAUCSL": "Consumer Price Index (CPI)",
		"UNRATE":   "Unemployment Rate",
		"FEDFUNDS": "Federal Funds Rate",
	}

	type IndicatorData struct {
		ID          string                   `json:"id"`
		Name        string                   `json:"name"`
		LatestValue string                   `json:"latest_value"`
		LatestDate  string                   `json:"latest_date"`
		History     []FredClient.Observation `json:"history"`
	}

	results := make([]IndicatorData, 0)

	// Fetch sequentially to be simple, could be parallel
	for id, name := range indicators {
		data, err := fredClient.GetSeriesObservations(id)
		if err != nil {
			log.Printf("Failed to fetch FRED series %s: %v", id, err)
			continue
		}

		var latestVal, latestDate string
		var history []FredClient.Observation

		count := len(data.Observations)
		if count > 0 {
			latest := data.Observations[count-1]
			latestVal = latest.Value
			latestDate = latest.Date

			// Get last year of data approx
			startIdx := 0
			if count > 12 {
				startIdx = count - 12
			}
			history = data.Observations[startIdx:]
		}

		results = append(results, IndicatorData{
			ID:          id,
			Name:        name,
			LatestValue: latestVal,
			LatestDate:  latestDate,
			History:     history,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"source":     "FRED",
		"count":      len(results),
		"indicators": results,
	})
}

// GetCryptoCandle godoc
// @Summary      Get crypto candle data
// @Description  Returns OHLCV candle data for a specific crypto symbol
// @Tags         crypto
// @Param        symbol      query  string  true   "Crypto symbol (e.g., BINANCE:BTCUSDT)"
// @Param        resolution  query  string  false  "Candle resolution: 1, 5, 15, 30, 60, D, W, M (default: D)"
// @Param        days        query  int     false  "Days of history (default: 30)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      400  {object}  ErrorResponse
// @Failure      500  {object}  ErrorResponse
// @Router       /crypto/candle [get]
func GetCryptoCandle(c *gin.Context) {
	symbol := c.Query("symbol")
	if symbol == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "query parameter 'symbol' is required"})
		return
	}
	resolution := c.DefaultQuery("resolution", "D")
	daysStr := c.DefaultQuery("days", "30")
	days, err := strconv.Atoi(daysStr)
	if err != nil || days < 1 {
		days = 30
	}
	if days > 365 {
		days = 365
	}

	now := time.Now().Unix()
	from := now - int64(days*86400)

	candle, err := dogonomicsFetchingClient.GetCryptoCandle(c.Request.Context(), symbol, resolution, from, now)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"symbol":     symbol,
		"resolution": resolution,
		"count":      len(candle.Close),
		"candle":     candle,
	})
}

// ============================================================
// Social Sentiment Endpoint
// ============================================================

// GetSocialSentiment godoc
// @Summary      Get social sentiment analysis for a symbol
// @Description  Aggregates news articles and runs FinBERT sentiment analysis, returning per-article and aggregate sentiment
// @Tags         sentiment
// @Param        symbol  path   string  true  "Ticker symbol (e.g., AAPL)"
// @Param        limit   query  int     false "Number of articles to analyze (default: 10, max: 20)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /social/sentiment/{symbol} [get]
func GetSocialSentiment(c *gin.Context) {
	symbol := c.Param("symbol")
	ctx := c.Request.Context()
	limitStr := c.DefaultQuery("limit", "10")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 {
		limit = 10
	}
	if limit > 20 {
		limit = 20
	}

	// Fetch news for the symbol from multiple sources
	articles, err := newsClient.GetNewsBySymbol(ctx, symbol, limit)
	if err != nil {
		// Fallback: try keyword search
		articles, err = newsClient.GetNewsByKeyword(ctx, symbol, limit)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch news: " + err.Error()})
			return
		}
	}

	// Apply FinBERT sentiment via worker pool
	type ArticleWithSentiment struct {
		Title       string                       `json:"title"`
		Description string                       `json:"description"`
		Source      string                       `json:"source"`
		URL         string                       `json:"url"`
		PublishedAt time.Time                    `json:"published_at"`
		ImageURL    string                       `json:"image_url,omitempty"`
		Sentiment   *BertInference.BERTSentiment `json:"sentiment"`
	}

	analysed := make([]ArticleWithSentiment, len(articles))
	for i, a := range articles {
		analysed[i] = ArticleWithSentiment{
			Title:       a.Title,
			Description: a.Description,
			Source:      a.Source,
			URL:         a.URL,
			PublishedAt: a.PublishedAt,
			ImageURL:    a.ImageURL,
		}
	}

	tasks := make([]workerpool.Task, len(articles))
	for i, article := range articles {
		idx := i
		title := article.Title
		desc := article.Description
		tasks[i] = func(_ context.Context) error {
			sent, err := sentiment.AnalyzeNews(title, desc)
			if err != nil {
				log.Printf("Sentiment analysis failed for article %d: %v", idx, err)
				return nil // non-fatal
			}
			analysed[idx].Sentiment = sent
			return nil
		}
	}

	workerpool.Run(ctx, 3, tasks)

	// Compute aggregate
	var totalScore, totalConf float64
	counts := map[string]int{"positive": 0, "neutral": 0, "negative": 0}
	analysedCount := 0

	for _, a := range analysed {
		if a.Sentiment != nil {
			totalScore += a.Sentiment.Score
			totalConf += a.Sentiment.Confidence
			counts[a.Sentiment.Label]++
			analysedCount++
		}
	}

	avgScore := 0.0
	avgConf := 0.0
	overallLabel := "neutral"
	if analysedCount > 0 {
		avgScore = totalScore / float64(analysedCount)
		avgConf = totalConf / float64(analysedCount)
		if counts["positive"] > counts["negative"] && counts["positive"] > counts["neutral"] {
			overallLabel = "positive"
		} else if counts["negative"] > counts["positive"] && counts["negative"] > counts["neutral"] {
			overallLabel = "negative"
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"symbol":         symbol,
		"articles_count": len(analysed),
		"aggregate": gin.H{
			"label":              overallLabel,
			"average_score":      avgScore,
			"average_confidence": avgConf,
			"sentiment_counts":   counts,
		},
		"articles": analysed,
	})
}

// ============================================================
// Database Query Endpoints
// ============================================================

// GetSentimentHistoryHandler godoc
// @Summary      Get sentiment analysis history
// @Description  Returns sentiment analysis history for a symbol over specified days
// @Tags         database
// @Param        symbol   path   string  true  "Ticker symbol (e.g., AAPL)"
// @Param        days     query  int     false "Days of history (default: 7)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /db/sentiment/history/{symbol} [get]
func GetSentimentHistoryHandler(c *gin.Context) {
	symbol := c.Param("symbol")
	daysStr := c.DefaultQuery("days", "7")
	days, err := strconv.Atoi(daysStr)
	if err != nil || days < 1 {
		days = 7
	}
	if days > 90 {
		days = 90
	}

	ctx := c.Request.Context()
	results, err := database.GetSentimentHistory(ctx, symbol, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"symbol":  symbol,
		"days":    days,
		"count":   len(results),
		"history": results,
	})
}

// GetSentimentTrendHandler godoc
// @Summary      Get sentiment trend
// @Description  Returns daily sentiment trend for a symbol using time_bucket aggregation
// @Tags         database
// @Param        symbol   path   string  true  "Ticker symbol (e.g., AAPL)"
// @Param        days     query  int     false "Days of history (default: 7)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /db/sentiment/trend/{symbol} [get]
func GetSentimentTrendHandler(c *gin.Context) {
	symbol := c.Param("symbol")
	daysStr := c.DefaultQuery("days", "7")
	days, err := strconv.Atoi(daysStr)
	if err != nil || days < 1 {
		days = 7
	}
	if days > 90 {
		days = 90
	}

	ctx := c.Request.Context()
	results, err := database.GetSymbolSentimentTrend(ctx, symbol, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"symbol": symbol,
		"days":   days,
		"trend":  results,
	})
}

// GetRecentRequestsHandler godoc
// @Summary      Get recent API requests
// @Description  Returns the most recent API request logs
// @Tags         database
// @Param        limit   query  int  false  "Number of results (default: 50)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /db/requests/recent [get]
func GetRecentRequestsHandler(c *gin.Context) {
	limitStr := c.DefaultQuery("limit", "50")
	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 {
		limit = 50
	}
	if limit > 500 {
		limit = 500
	}

	ctx := c.Request.Context()
	results, err := database.GetRecentAPIRequests(ctx, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"count":    len(results),
		"requests": results,
	})
}

// GetRequestsBySymbolHandler godoc
// @Summary      Get request counts by symbol
// @Description  Returns API request counts grouped by symbol for specified period
// @Tags         database
// @Param        days   query  int  false  "Days to look back (default: 7)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /db/requests/by-symbol [get]
func GetRequestsBySymbolHandler(c *gin.Context) {
	daysStr := c.DefaultQuery("days", "7")
	days, err := strconv.Atoi(daysStr)
	if err != nil || days < 1 {
		days = 7
	}

	since := time.Now().AddDate(0, 0, -days)
	ctx := c.Request.Context()
	results, err := database.GetRequestCountBySymbol(ctx, since)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"days":    days,
		"symbols": results,
	})
}

// GetDailySentimentSummaryHandler godoc
// @Summary      Get daily sentiment summary
// @Description  Returns daily sentiment summary from the continuous aggregate view
// @Tags         database
// @Param        symbol   path   string  true  "Ticker symbol (e.g., AAPL)"
// @Param        days     query  int     false "Days of history (default: 7)"
// @Produce      json
// @Success      200  {object}  interface{}
// @Failure      500  {object}  ErrorResponse
// @Router       /db/sentiment/daily/{symbol} [get]
func GetDailySentimentSummaryHandler(c *gin.Context) {
	symbol := c.Param("symbol")
	daysStr := c.DefaultQuery("days", "7")
	days, err := strconv.Atoi(daysStr)
	if err != nil || days < 1 {
		days = 7
	}
	if days > 90 {
		days = 90
	}

	ctx := c.Request.Context()

	if database.DB == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database not connected"})
		return
	}

	query := `
		SELECT symbol, bucket, total_analyses, avg_sentiment_score,
		       avg_confidence, positive_count, neutral_count, negative_count
		FROM daily_sentiment_summary
		WHERE symbol = $1
		  AND bucket >= NOW() - ($2 || ' days')::INTERVAL
		ORDER BY bucket DESC
	`

	rows, err := database.DB.Query(ctx, query, symbol, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var sym string
		var bucket time.Time
		var totalAnalyses, posCount, neuCount, negCount int
		var avgScore, avgConf *float64

		if err := rows.Scan(&sym, &bucket, &totalAnalyses, &avgScore, &avgConf, &posCount, &neuCount, &negCount); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		results = append(results, map[string]interface{}{
			"symbol":              sym,
			"date":                bucket,
			"total_analyses":      totalAnalyses,
			"avg_sentiment_score": avgScore,
			"avg_confidence":      avgConf,
			"positive_count":      posCount,
			"neutral_count":       neuCount,
			"negative_count":      negCount,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"symbol":  symbol,
		"days":    days,
		"count":   len(results),
		"summary": results,
	})
}

type CacheInvalidateRequest struct {
	Pattern string `json:"pattern"`
	DryRun  bool   `json:"dryRun"`
}

// InvalidateCacheByPattern godoc
// @Summary      Invalidate cached API responses by Redis key pattern
// @Description  Deletes cache keys matching a pattern. Pattern must start with "cache:".
// @Tags         admin
// @Accept       json
// @Produce      json
// @Param        request body CacheInvalidateRequest true "Invalidation request"
// @Success      200  {object}  interface{}
// @Failure      400  {object}  ErrorResponse
// @Failure      500  {object}  ErrorResponse
// @Router       /admin/cache/invalidate [post]
func InvalidateCacheByPattern(c *gin.Context) {
	var req CacheInvalidateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid JSON body"})
		return
	}

	pattern := strings.TrimSpace(req.Pattern)
	if pattern == "" {
		pattern = "cache:*"
	}

	if !strings.HasPrefix(pattern, "cache:") {
		c.JSON(http.StatusBadRequest, gin.H{"error": "pattern must start with cache:"})
		return
	}

	if req.DryRun {
		c.JSON(http.StatusOK, gin.H{
			"message": "dry run complete",
			"pattern": pattern,
			"deleted": 0,
		})
		return
	}

	deleted, err := cache.DeleteByPattern(c.Request.Context(), pattern, 2000)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "cache invalidation complete",
		"pattern": pattern,
		"deleted": deleted,
	})
}
