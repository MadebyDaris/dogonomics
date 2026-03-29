package main

// @title       Dogonomics API
// @version     1.0
// @description Dogonomics API for stock data, news, and sentiment. Swagger UI is available at /swagger/index.html
// @host        localhost:${PORT}
// @BasePath    /
// @schemes     http

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/MadebyDaris/dogonomics/BertInference"
	"github.com/MadebyDaris/dogonomics/controller"
	"github.com/MadebyDaris/dogonomics/docs"
	"github.com/MadebyDaris/dogonomics/internal/CommoditiesClient"
	"github.com/MadebyDaris/dogonomics/internal/DogonomicsFetching"
	"github.com/MadebyDaris/dogonomics/internal/TreasuryClient"
	"github.com/MadebyDaris/dogonomics/internal/cache"
	"github.com/MadebyDaris/dogonomics/internal/database"
	"github.com/MadebyDaris/dogonomics/internal/dogohub"
	"github.com/MadebyDaris/dogonomics/internal/events"
	"github.com/MadebyDaris/dogonomics/internal/mcpgateway"
	"github.com/MadebyDaris/dogonomics/internal/ws"
	"github.com/MadebyDaris/dogonomics/middleware"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	httpSwagger "github.com/swaggo/http-swagger"
)

func main() {
	hubMode := flag.Bool("hub", false, "Start the DogoHub TUI Boot Menu")
	flag.Parse()

	if *hubMode {
		dogohub.Run(StartServer)
		return
	}

	StartServer()
}

func StartServer() {
	err := godotenv.Load()
	if err != nil {
		fmt.Println("Error loading .env file")
	}
	if os.Getenv("FINNHUB_API_KEY") == "" {
		fmt.Println("FINNHUB_API_KEY is not set in .env file")
		fmt.Println("Please set your FINNHUB_API_KEY in the .env file.")
		return
	}

	// Initialize Firebase Admin SDK for authentication
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

	// Initialize WebSocket hub
	wsHub := ws.NewHub()
	go wsHub.Run()
	controller.SetWSHub(wsHub)
	log.Println("WebSocket hub started")

	// Initialize Kafka producer (graceful degradation if KAFKA_BROKER not set)
	kafkaProducer := events.NewProducer()
	controller.SetKafkaProducer(kafkaProducer)

	var mcpServer *mcpgateway.Server
	if mcpgateway.EnabledFromEnv() {
		// Initialize additional clients for MCP
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
	modelPath, vocabPath, resolveErr := resolveBertAssets()
	if resolveErr != nil {
		log.Printf("WARNING: BERT assets resolution failed: %v", resolveErr)
	}

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

	// Prometheus metrics
	var (
		httpRequestsTotal = prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "http_requests_total",
				Help: "Total number of HTTP requests",
			},
			[]string{"service", "method", "handler", "status"},
		)

		httpRequestDuration = prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "http_request_duration_seconds",
				Help:    "Histogram of HTTP request durations (seconds)",
				Buckets: prometheus.DefBuckets,
			},
			[]string{"service", "method", "handler"},
		)
	)

	prometheus.MustRegister(httpRequestsTotal, httpRequestDuration)
	// Middleware — order matters:
	// 1. CORS must be first to handle preflight OPTIONS requests
	// 2. Rate limiting before auth to block floods early
	// 3. Auth validates Firebase ID tokens
	// 4. Database logger & cache are last
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

	// Stock & market data
	r.GET("/ticker/:symbol", controller.GetTicker)
	r.GET("/quote/:symbol", controller.GetQuote)
	r.GET("/finnews/:symbol", controller.GetNews)
	r.GET("/finnewsBert/:symbol", controller.GetNewsSentimentBERT)
	r.GET("/sentiment/:symbol", controller.GetSentimentOnly)
	r.GET("/stock/:symbol", controller.GetStockDetail)
	r.GET("/profile/:symbol", controller.GetCompanyProfile)
	r.GET("/chart/:symbol", controller.GetChartData)
	r.GET("/health", controller.GetHealthStatus)

	// Sentiment
	r.POST("/finbert/inference", controller.RunFinBertInference)

	// News
	r.GET("/news/general", controller.GetGeneralFinanceNews)
	r.GET("/news/general/sentiment", controller.GetGeneralNewsWithSentiment)
	r.GET("/news/symbol/:symbol", controller.GetNewsBySymbolMultiSource)
	r.GET("/news/search", controller.SearchNews)

	// Treasury
	r.GET("/treasury/yield-curve", controller.GetTreasuryYieldCurve)
	r.GET("/treasury/rates", controller.GetTreasuryRates)
	r.GET("/treasury/debt", controller.GetPublicDebt)

	// Commodities
	r.GET("/commodities/oil", controller.GetCommodityOil)
	r.GET("/commodities/gas", controller.GetCommodityGas)
	r.GET("/commodities/metals", controller.GetCommodityMetals)
	r.GET("/commodities/agriculture", controller.GetCommodityAgriculture)

	// Economy (New)
	r.GET("/economy/indicators", controller.GetEconomicIndicators)

	// Financial Indicators & Advice
	r.GET("/indicators/:symbol", controller.GetFinancialIndicators)
	r.GET("/advice/:symbol", controller.GetDogonomicsAdvice)

	// Forex
	r.GET("/forex/rates", controller.GetForexRates)
	r.GET("/forex/symbols", controller.GetForexSymbols)

	// Crypto
	r.GET("/crypto/quotes", controller.GetCryptoQuotes)
	r.GET("/crypto/candle", controller.GetCryptoCandle)

	// Social Sentiment
	r.GET("/social/sentiment/:symbol", controller.GetSocialSentiment)

	// Reddit Scraper
	r.GET("/social/reddit/financial", controller.GetRedditFinancialNews)
	r.GET("/social/reddit/:subreddit", controller.GetSubredditPosts)

	// Database query endpoints
	r.GET("/db/sentiment/history/:symbol", controller.GetSentimentHistoryHandler)
	r.GET("/db/sentiment/trend/:symbol", controller.GetSentimentTrendHandler)
	r.GET("/db/sentiment/daily/:symbol", controller.GetDailySentimentSummaryHandler)
	r.GET("/db/requests/recent", controller.GetRecentRequestsHandler)
	r.GET("/db/requests/by-symbol", controller.GetRequestsBySymbolHandler)

	// WebSocket endpoints (token verified via query param)
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

	// Start WebSocket quote ticker (polls every 15 seconds for active subscribers)
	wsCtx, wsCancel := context.WithCancel(context.Background())
	defer wsCancel()
	go ws.QuoteTicker(wsCtx, wsHub, finnhubClient, 15*time.Second)
	go ws.NewsTicker(wsCtx, wsHub, 30*time.Second)

	fmt.Printf("Starting Dogonomics API server on :%s\n", port)
	fmt.Printf("Swagger UI: http://localhost:%s/swagger/index.html\n", port)

	// TLS support: if cert + key files are provided, serve HTTPS
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

func resolveBertAssets() (string, string, error) {
	modelPath := strings.TrimSpace(os.Getenv("BERT_MODEL_PATH"))
	if modelPath == "" {
		modelPath = "./sentAnalysis/DoggoFinBERT.onnx"
	}

	vocabPath := strings.TrimSpace(os.Getenv("BERT_VOCAB_PATH"))
	if vocabPath == "" {
		vocabPath = "./sentAnalysis/finbert/vocab.txt"
	}

	autoDownload := !strings.EqualFold(strings.TrimSpace(os.Getenv("BERT_AUTO_DOWNLOAD")), "false")
	modelURL := strings.TrimSpace(os.Getenv("BERT_MODEL_URL"))
	vocabURL := strings.TrimSpace(os.Getenv("BERT_VOCAB_URL"))

	var errs []string

	if !fileExists(modelPath) {
		if autoDownload && modelURL != "" {
			if err := downloadToPath(modelURL, modelPath, 3*time.Minute); err != nil {
				errs = append(errs, fmt.Sprintf("model download failed: %v", err))
			} else {
				log.Printf("BERT model downloaded to %s", modelPath)
			}
		} else {
			errs = append(errs, "model file missing and auto-download is disabled or BERT_MODEL_URL is empty")
		}
	}

	if !fileExists(vocabPath) {
		if autoDownload && vocabURL != "" {
			if err := downloadToPath(vocabURL, vocabPath, 2*time.Minute); err != nil {
				errs = append(errs, fmt.Sprintf("vocab download failed: %v", err))
			} else {
				log.Printf("BERT vocab downloaded to %s", vocabPath)
			}
		} else {
			errs = append(errs, "vocab file missing and auto-download is disabled or BERT_VOCAB_URL is empty")
		}
	}

	if len(errs) > 0 {
		return modelPath, vocabPath, errors.New(strings.Join(errs, "; "))
	}

	return modelPath, vocabPath, nil
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return !info.IsDir()
}

func downloadToPath(srcURL string, dstPath string, timeout time.Duration) error {
	if strings.Contains(strings.ToLower(srcURL), "drive.google.com") {
		return fmt.Errorf("google drive links are not supported for automated startup downloads; use a direct file URL (e.g. DigitalOcean Spaces/S3/R2 public object URL)")
	}

	if err := os.MkdirAll(filepath.Dir(dstPath), 0o755); err != nil {
		return fmt.Errorf("failed creating destination directory: %w", err)
	}

	client := &http.Client{Timeout: timeout}
	resp, err := client.Get(srcURL)
	if err != nil {
		return fmt.Errorf("download request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("download failed with status: %s", resp.Status)
	}

	tmpPath := dstPath + ".tmp"
	out, err := os.Create(tmpPath)
	if err != nil {
		return fmt.Errorf("failed creating temp file: %w", err)
	}

	if _, err := io.Copy(out, resp.Body); err != nil {
		out.Close()
		_ = os.Remove(tmpPath)
		return fmt.Errorf("failed writing downloaded file: %w", err)
	}

	if err := out.Close(); err != nil {
		_ = os.Remove(tmpPath)
		return fmt.Errorf("failed closing temp file: %w", err)
	}

	if err := os.Rename(tmpPath, dstPath); err != nil {
		_ = os.Remove(tmpPath)
		return fmt.Errorf("failed moving downloaded file into place: %w", err)
	}

	return nil
}

// splitPath splits a URL path into segments, trimming leading/trailing slashes.
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

// looksLikeParam identifies variable path segments (digits, uppercase tickers, etc.).
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

// joinPath joins path segments with '/'.
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

// split is a minimal strings.Split replacement.
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
