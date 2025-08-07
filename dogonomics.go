package main

import (
	"fmt"
	"os"

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
	r := gin.Default()

	r.GET("/ticker/:symbol", controller.GetTicker)
	r.GET("/quote/:symbol", controller.GetQuote)
	r.GET("/finnews/:symbol", controller.GetNews)

	r.GET("/stock/:symbol", controller.GetStockDetail)      // Main endpoint with all data
	r.GET("/profile/:symbol", controller.GetCompanyProfile) // Company profile
	r.GET("/chart/:symbol", controller.GetChartData)        // Historical chart data
	r.GET("/health", controller.GetHealthStatus)            // Historical chart data

	// Test endpoint
	r.GET("/test", func(c *gin.Context) {
		// Test with Apple
		stock, err := DogonomicsFetching.NewClient().BuildStockDetailData("APPL")
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		c.JSON(200, gin.H{"message": "Test successful", "data": stock})
	})

	fmt.Println("Starting Dogonomics API server...")
	fmt.Println("Available endpoints:")
	fmt.Println("  GET /stock/:symbol - Complete stock data")
	fmt.Println("  GET /quote/:symbol - Current quote")
	fmt.Println("  GET /profile/:symbol - Company profile")
	fmt.Println("  GET /chart/:symbol - Chart data")
	fmt.Println("  GET /news/:symbol - Company news")
	fmt.Println("  GET /sentiment/:symbol - News sentiment")
	fmt.Println("  GET /health - Health check")

	r.Run()
}
