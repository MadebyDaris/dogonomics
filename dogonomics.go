package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/MadebyDaris/dogonomics/BertInference"
	"github.com/MadebyDaris/dogonomics/controller"
	"github.com/MadebyDaris/dogonomics/internal/DogonomicsFetching"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	err := godotenv.Load()
	if err != nil {
		fmt.Println("Error loading .env file")
	}
	fmt.Println("API KEY:", os.Getenv("FINNHUB_API_KEY"))
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
