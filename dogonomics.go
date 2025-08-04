package main

import (
	"fmt"
	"os"

	_ "github.com/MadebyDaris/dogonomics/DogonomicsProcessing"
	"github.com/MadebyDaris/dogonomics/controller"
	"github.com/MadebyDaris/dogonomics/internal/PolygonClient"
	_ "github.com/MadebyDaris/dogonomics/internal/dataFetcher"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	err := godotenv.Load()
	if err != nil {
		fmt.Println("Error loading .env file")
	}
	fmt.Println("API KEY:", os.Getenv("POLYGON_API_KEY"))

	r := gin.Default()

	r.GET("/ticker/:symbol", controller.GetTicker)
	r.GET("/quote/:symbol", controller.GetQuote)
	r.GET("/finnews/:symbol", controller.GetNews)
	r.GET("/test", func(c *gin.Context) {
		stock, err := PolygonClient.RequestQuote("AAPL")
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		c.JSON(200, stock)
	})
	r.Run()
}
