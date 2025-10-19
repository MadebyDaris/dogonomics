package main

// @title       Dogonomics API
// @version     1.0
// @description Dogonomics API for stock data, news, and sentiment. Swagger UI is available at /swagger/index.html
// @host        localhost:8080
// @BasePath    /
// @schemes     http

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/MadebyDaris/dogonomics/BertInference"
	"github.com/MadebyDaris/dogonomics/controller"
	"github.com/MadebyDaris/dogonomics/docs"
	"github.com/MadebyDaris/dogonomics/internal/DogonomicsFetching"
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

	// Initialize clients
	finnhubClient := DogonomicsFetching.NewClient()
	controller.Init(finnhubClient)

	fmt.Println("Initializing BERT model...")
	modelPath := "./sentAnalysis/DoggoFinBERT.onnx"
	vocabPath := "./sentAnalysis/finbert/vocab.txt"

	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-c
		fmt.Println("\nShutting down server...")
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
		// include service and handler labels to make dashboards clearer while
		// keeping cardinality low by normalizing paths and grouping status codes
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

	// Metrics middleware
	r.Use(func(c *gin.Context) {
		start := time.Now()
		c.Next()

		// Normalize status code to class (2xx, 3xx, 4xx, 5xx)
		statusCode := c.Writer.Status()
		statusClass := fmt.Sprintf("%dxx", statusCode/100)

		// Determine handler (use full route path if available)
		handler := c.FullPath()
		if handler == "" {
			// fallback: strip variable segments (simple heuristic)
			handler = c.Request.URL.Path
			// replace sequences of digits or all-caps segments like symbols with :param
			// e.g. /stock/IBM -> /stock/:param
			// keep it simple to avoid importing regex package
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

		serviceName := "dogonomics"
		httpRequestsTotal.WithLabelValues(serviceName, c.Request.Method, handler, statusClass).Inc()
		httpRequestDuration.WithLabelValues(serviceName, c.Request.Method, handler).Observe(duration)
	})

	// Expose Prometheus metrics
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// Swagger docs
	docs.SwaggerInfo.Title = "Dogonomics API"
	docs.SwaggerInfo.Description = "Dogonomics API for stock data, news and sentiment"
	docs.SwaggerInfo.Version = "1.0"
	docs.SwaggerInfo.Host = "localhost:8080"
	docs.SwaggerInfo.BasePath = "/"

	r.GET("/swagger/*any", gin.WrapH(httpSwagger.Handler(httpSwagger.URL("http://localhost:8080/swagger/doc.json"))))

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

	r.GET("/test", func(c *gin.Context) {
		stock, err := DogonomicsFetching.NewClient().BuildStockDetailData("APPL")
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		c.JSON(200, gin.H{"message": "Test successful", "data": stock})
	})
	r.GET("/test-bert", func(c *gin.Context) {
		text := "Apple Inc. reported strong quarterly earnings, beating analyst expectations."
		sentiment, err := BertInference.RunBERTInference(text, modelPath)
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		c.JSON(200, gin.H{
			"message": "BERT test completed",
			"text":    text,
			"result":  sentiment,
		})
	})

	fmt.Println("Starting Dogonomics API server...")
	fmt.Println("Server will be available at: http://localhost:8080")
	fmt.Println("Available endpoints:")
	fmt.Println("  GET /stock/:symbol - Complete stock data")
	fmt.Println("  GET /quote/:symbol - Current quote")
	fmt.Println("  GET /profile/:symbol - Company profile")
	fmt.Println("  GET /chart/:symbol - Chart data")
	fmt.Println("  GET /news/:symbol - Company news")
	fmt.Println("  GET /sentiment/:symbol - News sentiment")
	fmt.Println("  GET /health - Health check")

	if err := r.Run(); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

// Helper to split a URL path into segments, trimming leading/trailing slashes
func splitPath(p string) []string {
	if p == "" {
		return []string{}
	}
	// trim leading/trailing
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

// looksLikeParam uses a simple heuristic to identify variable segments
func looksLikeParam(s string) bool {
	if s == "" {
		return false
	}
	// If segment is all digits or contains dots (like timestamps) or is uppercase (ticker), treat as param
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

// joinPath joins path segments with '/'
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

// split is a minimal strings.Split replacement to avoid extra imports
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
