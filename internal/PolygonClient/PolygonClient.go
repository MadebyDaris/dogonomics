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

func RequestTicker(ctx context.Context, symbol string, date time.Time) (Stock, error) {
	c := polygon.New(os.Getenv("POLYGON_API_KEY"))

	params := models.GetDailyOpenCloseAggParams{
		Ticker: symbol,
		Date:   models.Date(date),
	}

	res, err := c.GetDailyOpenCloseAgg(ctx, &params)
	if err != nil {
		return Stock{}, err
	}

	return Stock{
		Symbol:             symbol,
		Current:            res.Close,
		High:               res.High,
		Low:                res.Low,
		OpenPrice:          res.Open,
		PreviousClosePrice: 0,
	}, nil
}

// RequestHistoricalData fetches daily OHLCV data from Polygon.
func RequestHistoricalData(ctx context.Context, symbol string, days int) ([]DogonomicsProcessing.ChartDataPoint, error) {
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

	res, err := c.GetAggs(ctx, &params)
	if err != nil {
		return []DogonomicsProcessing.ChartDataPoint{}, err
	}

	chartData := []DogonomicsProcessing.ChartDataPoint{}
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
