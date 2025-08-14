package PolygonClient

import (
	"context"
	"os"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/DogonomicsProcessing"
	polygon "github.com/polygon-io/client-go/rest"
	"github.com/polygon-io/client-go/rest/models"
)

type Stock struct {
	Symbol             string  `json:"symbol"`
	Current            float64 `json:"c"`
	High               float64 `json:"h"`
	Low                float64 `json:"l"`
	OpenPrice          float64 `json:"o"`
	PreviousClosePrice float64 `json:"pc"`
}

func RequestTicker(symbol string, date time.Time) (Stock, error) {
	// init client
	c := polygon.New(os.Getenv("POLYGON_API_KEY"))
	// set params
	params := models.GetDailyOpenCloseAggParams{
		Ticker: symbol,
		Date:   models.Date(date),
	}
	// make request
	res, err := c.GetDailyOpenCloseAgg(context.Background(), &params)
	if err != nil {
		return Stock{}, err
	}
	// do something with the result
	// Build and return the Stock struct
	stock := Stock{
		Symbol:             symbol,
		Current:            res.Close,
		High:               res.High,
		Low:                res.Low,
		OpenPrice:          res.Open,
		PreviousClosePrice: 0, // Not provided by this endpoint
	}
	return stock, nil
}

// TODO SERVER SYSTEM TO STORE DATA AND REQUEST FROM SERVER
func RequestHistoricalData(symbol string, days int) ([]DogonomicsProcessing.ChartDataPoint, error) {
	// init client
	c := polygon.New(os.Getenv("POLYGON_API_KEY"))

	now := time.Now().UTC()
	from := now.AddDate(0, 0, -days)
	limit := 1000 // max limit for Polygon API

	params := models.GetAggsParams{
		Ticker:     symbol,
		Timespan:   "day",
		From:       models.Millis(from),
		To:         models.Millis(now),
		Multiplier: 1,
		Limit:      &limit,
	}
	// make request
	res, err := c.GetAggs(context.Background(), &params)
	if err != nil {
		return []DogonomicsProcessing.ChartDataPoint{}, err
	}
	// Build and return the ChartDataPoint slice
<<<<<<< HEAD
	var chartData = []DogonomicsProcessing.ChartDataPoint{}
=======
	var chartData []DogonomicsProcessing.ChartDataPoint
>>>>>>> 971fefbb4210a659c21f0046baee98ad84b3276f
	for _, agg := range res.Results {
		chartData = append(chartData, DogonomicsProcessing.ChartDataPoint{
			Close:     agg.Close,
			Open:      agg.Open,
			Low:       agg.Low,
			High:      agg.High,
			Volume:    int64(agg.Volume),
			Timestamp: time.Time(agg.Timestamp),
		})
	}
	return chartData, nil
}
