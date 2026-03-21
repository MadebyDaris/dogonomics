package main

// @title       Dogonomics API
// @version     1.0
// @description Dogonomics API for stock data, news, and sentiment. Swagger UI is available at /swagger/index.html
// @host        localhost:${PORT}
// @BasePath    /
// @schemes     http

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/MadebyDaris/dogonomics/docs"
	CommoditiesClient "github.com/MadebyDaris/dogonomics/internal/api/commodities"
	DogonomicsFetching "github.com/MadebyDaris/dogonomics/internal/api/finnhub"
	TreasuryClient "github.com/MadebyDaris/dogonomics/internal/api/treasury"
	"github.com/MadebyDaris/dogonomics/internal/cache"
	"github.com/MadebyDaris/dogonomics/internal/database"
	"github.com/MadebyDaris/dogonomics/internal/events"
	"github.com/MadebyDaris/dogonomics/internal/handler/controller"
	"github.com/MadebyDaris/dogonomics/internal/mcpgateway"
	"github.com/MadebyDaris/dogonomics/internal/middleware"
	BertInference "github.com/MadebyDaris/dogonomics/internal/service/bertinference"
	"github.com/MadebyDaris/dogonomics/internal/ws"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	httpSwagger "github.com/swaggo/http-swagger"
)

func main() {
	err := godotenv.Load()
	if err != nil {
		fmt.Println("Error loading .env file")
	}
	if os.Getenv("FINNHUB_API_KEY") == "" {
		fmt.Println("FINNHUB_API_KEY is not set in .env file")
		fmt.Println("Please set your FINNHUB_API_KEY in the .env file.")
		return
	}

	if err := middleware.InitFirebase(); err != nil {
		log.Printf("WARNING: Firebase init failed: %v", err)
		log.Printf("API will continue without authentication (dev mode)")
	} else {
		log.Println("Firebase authentication initialized")
	}

	finnhubClient := DogonomicsFetching.NewClient()
	controller.Init(finnhubClient)

	if err := database.Connect(database.LoadConfigFromEnv()); err != nil {
		log.Printf("WARNING: Database connection failed: %v", err)
		log.Printf("API will continue without database logging")
	} else {
		log.Println("Database connected successfully")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := database.HealthCheck(ctx); err != nil {
			log.Printf("WARNING: Database health check failed: %v", err)
		}
	}

	if err := cache.Connect(cache.LoadConfigFromEnv()); err != nil {
		log.Printf("WARNING: Redis connection failed: %v", err)
		log.Printf("API will continue without caching")
	}

	wsHub := ws.NewHub()
	go wsHub.Run()
	controller.SetWSHub(wsHub)
	log.Println("WebSocket hub started")

	kafkaProducer := events.NewProducer()
	controller.SetKafkaProducer(kafkaProducer)

	var mcpServer *mcpgateway.Server
	if mcpgateway.EnabledFromEnv() {
		treasuryClient := TreasuryClient.NewClient()
		commoditiesClient := CommoditiesClient.NewClient()

		mcpServer, err = mcpgateway.New(mcpgateway.Dependencies{
			Finnhub:     finnhubClient,
			Redis:       cache.Client,
			Treasury:    treasuryClient,
			Commodities: commoditiesClient,
		})
		if err != nil {
			log.Printf("WARNING: MCP server init failed: %v", err)
		} else {
			mcpServer.Start()
		}
	}

	fmt.Println("Initializing BERT model...")
	modelPath := "./assets/sentiment/DoggoFinBERT.onnx"
	vocabPath := "./assets/sentiment/finbert/vocab.txt"

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-c
		fmt.Println("\nShutting down server...")
		if mcpServer != nil {
			shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			if err := mcpServer.Shutdown(shutdownCtx); err != nil {
				log.Printf("WARNING: MCP shutdown failed: %v", err)
			}
			cancel()
		}
		kafkaProducer.Close()
		cache.Close()
		database.Close()
		BertInference.CleanupBERT()
		fmt.Println("Cleanup completed")
		os.Exit(0)
	}()

	if err := BertInference.InitializeBERT(modelPath, vocabPath); err != nil {
		log.Printf("ERROR: Failed to initialize BERT model: %v", err)
		log.Printf("Sentiment analysis features will be disabled")
		log.Printf("Server will continue without sentiment analysis")
	} else {
		fmt.Println("BERT model initialized successfully")
	}

	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	var (
		httpRequestsTotal = prometheus.NewCounterVec(
			prometheus.CounterOpts{Name: "http_requests_total", Help: "Total number of HTTP requests"},
			[]string{"service", "method", "handler", "status"},
		)
		httpRequestDuration = prometheus.NewHistogramVec(
			prometheus.HistogramOpts{Name: "http_request_duration_seconds", Help: "Histogram of HTTP request durations (seconds)", Buckets: prometheus.DefBuckets},
			[]string{"service", "method", "handler"},
		)
	)

	prometheus.MustRegister(httpRequestsTotal, httpRequestDuration)
	r.Use(middleware.CORSMiddleware())
	r.Use(middleware.RateLimitMiddleware())
	r.Use(middleware.APIKeyMiddleware())
	r.Use(middleware.AuthMiddleware())
	r.Use(middleware.UserRateLimitMiddleware())
	r.Use(middleware.DatabaseLogger())
	r.Use(middleware.CacheMiddleware(5 * time.Minute))

	r.Use(func(c *gin.Context) {
		start := time.Now()
		c.Next()
		statusCode := c.Writer.Status()
		statusClass := fmt.Sprintf("%dxx", statusCode/100)
		handler := c.FullPath()
		if handler == "" {
			handler = c.Request.URL.Path
			segs := make([]string, 0)
			for _, s := range splitPath(handler) {
				if looksLikeParam(s) {
					segs = append(segs, ":param")
				} else {
					segs = append(segs, s)
				}
			}
			handler = "/" + joinPath(segs)
		}
		duration := time.Since(start).Seconds()
		httpRequestsTotal.WithLabelValues("dogonomics", c.Request.Method, handler, statusClass).Inc()
		httpRequestDuration.WithLabelValues("dogonomics", c.Request.Method, handler).Observe(duration)
	})

	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	docs.SwaggerInfo.Title = "Dogonomics API"
	docs.SwaggerInfo.Description = "Dogonomics API for stock data, news and sentiment"
	docs.SwaggerInfo.Version = "1.0"
	docs.SwaggerInfo.Host = "localhost:" + port
	docs.SwaggerInfo.BasePath = "/"

	r.GET("/swagger/*any", gin.WrapH(httpSwagger.Handler(httpSwagger.URL("http://localhost:"+port+"/swagger/doc.json"))))

	r.Use(func(c *gin.Context) {
		path := c.Request.URL.Path
		if path == "/finnewsBert/"+c.Param("symbol") || path == "/sentiment/"+c.Param("symbol") {
			c.Header("X-Request-Timeout", "60s")
		}
		c.Next()
	})

	r.GET("/ticker/:symbol", controller.GetTicker)
	r.GET("/quote/:symbol", controller.GetQuote)
	r.GET("/finnews/:symbol", controller.GetNews)
	r.GET("/finnewsBert/:symbol", controller.GetNewsSentimentBERT)
	r.GET("/sentiment/:symbol", controller.GetSentimentOnly)
	r.GET("/stock/:symbol", controller.GetStockDetail)
	r.GET("/profile/:symbol", controller.GetCompanyProfile)
	r.GET("/chart/:symbol", controller.GetChartData)
	r.GET("/health", controller.GetHealthStatus)
	r.POST("/finbert/inference", controller.RunFinBertInference)
	r.GET("/news/general", controller.GetGeneralFinanceNews)
	r.GET("/news/general/sentiment", controller.GetGeneralNewsWithSentiment)
	r.GET("/news/symbol/:symbol", controller.GetNewsBySymbolMultiSource)
	r.GET("/news/search", controller.SearchNews)
	r.GET("/treasury/yield-curve", controller.GetTreasuryYieldCurve)
	r.GET("/treasury/rates", controller.GetTreasuryRates)
	r.GET("/treasury/debt", controller.GetPublicDebt)
	r.GET("/commodities/oil", controller.GetCommodityOil)
	r.GET("/commodities/gas", controller.GetCommodityGas)
	r.GET("/commodities/metals", controller.GetCommodityMetals)
	r.GET("/commodities/agriculture", controller.GetCommodityAgriculture)
	r.GET("/economy/indicators", controller.GetEconomicIndicators)
	r.GET("/indicators/:symbol", controller.GetFinancialIndicators)
	r.GET("/advice/:symbol", controller.GetDogonomicsAdvice)
	r.GET("/forex/rates", controller.GetForexRates)
	r.GET("/forex/symbols", controller.GetForexSymbols)
	r.GET("/crypto/quotes", controller.GetCryptoQuotes)
	r.GET("/crypto/candle", controller.GetCryptoCandle)
	r.GET("/social/sentiment/:symbol", controller.GetSocialSentiment)
	r.GET("/social/reddit/financial", controller.GetRedditFinancialNews)
	r.GET("/social/reddit/:subreddit", controller.GetSubredditPosts)
	r.GET("/db/sentiment/history/:symbol", controller.GetSentimentHistoryHandler)
	r.GET("/db/sentiment/trend/:symbol", controller.GetSentimentTrendHandler)
	r.GET("/db/sentiment/daily/:symbol", controller.GetDailySentimentSummaryHandler)
	r.GET("/db/requests/recent", controller.GetRecentRequestsHandler)
	r.GET("/db/requests/by-symbol", controller.GetRequestsBySymbolHandler)

	r.GET("/ws/quotes/:symbol", func(c *gin.Context) {
		if !middleware.IsAPIKeyAuthorized(middleware.APIKeyFromRequest(c)) {
			c.JSON(401, gin.H{"error": "Invalid or missing API key"})
			return
		}
		token := c.Query("token")
		if token != "" {
			if _, err := middleware.VerifyWSToken(token); err != nil {
				c.JSON(401, gin.H{"error": "Invalid WebSocket token"})
				return
			}
		}
		symbol := c.Param("symbol")
		ws.ServeWS(wsHub, "quotes:"+symbol, c.Writer, c.Request)
	})
	r.GET("/ws/news", func(c *gin.Context) {
		if !middleware.IsAPIKeyAuthorized(middleware.APIKeyFromRequest(c)) {
			c.JSON(401, gin.H{"error": "Invalid or missing API key"})
			return
		}
		token := c.Query("token")
		if token != "" {
			if _, err := middleware.VerifyWSToken(token); err != nil {
				c.JSON(401, gin.H{"error": "Invalid WebSocket token"})
				return
			}
		}
		ws.ServeWS(wsHub, "news", c.Writer, c.Request)
	})

	wsCtx, wsCancel := context.WithCancel(context.Background())
	defer wsCancel()
	go ws.QuoteTicker(wsCtx, wsHub, finnhubClient, 15*time.Second)
	go ws.NewsTicker(wsCtx, wsHub, 30*time.Second)

	fmt.Printf("Starting Dogonomics API server on :%s\n", port)
	fmt.Printf("Swagger UI: http://localhost:%s/swagger/index.html\n", port)

	certPath := os.Getenv("TLS_CERT_PATH")
	keyPath := os.Getenv("TLS_KEY_PATH")
	if certPath != "" && keyPath != "" {
		fmt.Printf("Starting HTTPS server on :%s\n", port)
		if err := r.RunTLS(":"+port, certPath, keyPath); err != nil {
			log.Fatalf("Failed to start HTTPS server: %v", err)
		}
	} else {
		if err := r.Run(":" + port); err != nil {
			log.Fatalf("Failed to start server: %v", err)
		}
	}
}

func splitPath(p string) []string {
	if p == "" {
		return []string{}
	}
	for len(p) > 0 && p[0] == '/' {
		p = p[1:]
	}
	for len(p) > 0 && p[len(p)-1] == '/' {
		p = p[:len(p)-1]
	}
	if p == "" {
		return []string{}
	}
	return split(p, '/')
}

func looksLikeParam(s string) bool {
	if s == "" {
		return false
	}
	allDigits := true
	allUpper := true
	for i := 0; i < len(s); i++ {
		ch := s[i]
		if ch < '0' || ch > '9' {
			allDigits = false
		}
		if !(ch >= 'A' && ch <= 'Z') {
			allUpper = false
		}
		if ch == '.' || ch == '_' || ch == '-' {
			return true
		}
	}
	return allDigits || allUpper
}

func joinPath(segs []string) string {
	if len(segs) == 0 {
		return ""
	}
	out := segs[0]
	for i := 1; i < len(segs); i++ {
		out += "/" + segs[i]
	}
	return out
}

func split(s string, sep byte) []string {
	var res []string
	last := 0
	for i := 0; i < len(s); i++ {
		if s[i] == sep {
			res = append(res, s[last:i])
			last = i + 1
		}
	}
	res = append(res, s[last:])
	return res
}
