package PolygonClient

import (
	"context"
	"fmt"
	"os"
	"time"

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

func RequestQuote(symbol string) (Stock, error) {
	// Init client
	c := polygon.New(os.Getenv("POLYGON_API_KEY"))
	// Set params
	params := models.GetPreviousCloseAggParams{
		Ticker: symbol,
	}
	// Make request
	res, err := c.GetPreviousCloseAgg(context.Background(), &params)
	if err != nil {
		return Stock{}, err
	}
	// Check if results exist
	if len(res.Results) == 0 {
		return Stock{}, fmt.Errorf("no results for %s", symbol)
	}
	data := res.Results[0] // First (and usually only) item
	// Construct and return Stock
	stock := Stock{
		Symbol:             symbol,
		Current:            data.Close,
		High:               data.High,
		Low:                data.Low,
		OpenPrice:          data.Open,
		PreviousClosePrice: data.Close, // since it's previous close
	}
	return stock, nil
}
