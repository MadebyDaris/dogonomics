package controller

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/MadebyDaris/dogonomics/BertInference"
	"github.com/MadebyDaris/dogonomics/internal/CommoditiesClient"
	"github.com/MadebyDaris/dogonomics/internal/DogonomicsFetching"
	"github.com/MadebyDaris/dogonomics/internal/NewsClient"
	"github.com/MadebyDaris/dogonomics/internal/PolygonClient"
	"github.com/MadebyDaris/dogonomics/internal/TreasuryClient"
	"github.com/MadebyDaris/dogonomics/internal/database"
	"github.com/MadebyDaris/dogonomics/internal/workerpool"
	"github.com/MadebyDaris/dogonomics/sentAnalysis"
	"github.com/gin-gonic/gin"
)

var (
	finnhubClient            *DogonomicsFetching.Client
	dogonomicsFetchingClient *DogonomicsFetching.Client
	treasuryClient           *TreasuryClient.Client
	commoditiesClient        *CommoditiesClient.Client
	newsClient               *NewsClient.NewsClient
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
	treasuryClient = TreasuryClient.NewClient()
	commoditiesClient = CommoditiesClient.NewClient()
	newsClient = NewsClient.NewNewsClient()
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
	news, err := sentAnalysis.FetchData(ctx, symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
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

	newsItems, err := sentAnalysis.FetchAndAnalyzeNews(ctx, symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("failed to fetch/analyze news: %v", err),
		})
		return
	}

	aggregate := sentAnalysis.FetchStockSentiment(ctx, newsItems)

	// Persist aggregate sentiment to database asynchronously
	go func() {
		dbCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if err := database.SaveAggregatedSentiment(dbCtx, symbol, aggregate); err != nil {
			log.Printf("Failed to save aggregate sentiment for %s: %v", symbol, err)
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

	newsItems, err := sentAnalysis.FetchAndAnalyzeNews(ctx, symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("failed to fetch/analyze news: %v", err),
		})
		return
	}

	aggregate := sentAnalysis.FetchStockSentiment(ctx, newsItems)

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

	modelPath := "./sentAnalysis/DoggoFinBERT.onnx"
	sentiment, err := BertInference.RunBERTInference(req.Text, modelPath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("Failed to run BERT inference: %v", err),
		})
		return
	}

	c.JSON(http.StatusOK, sentiment)
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
	ctx := c.Request.Context()
	symbol := c.Param("symbol")
	StockDetail, err := dogonomicsFetchingClient.GetCompanyProfile(ctx, symbol)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"GetCompanyProfile error": err.Error()})
	}
	c.JSON(http.StatusOK, StockDetail)
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
			sentiment, err := sentAnalysis.AnalyzeNews(title, desc)
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
}
