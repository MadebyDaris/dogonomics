package database

import (
	"context"
	"encoding/json"

	"github.com/MadebyDaris/dogonomics/internal/api/commodities"
	"github.com/MadebyDaris/dogonomics/internal/api/treasury"
)

// SaveTreasuryData saves treasury API response data to the database
func SaveTreasuryData(ctx context.Context, dataType string, response *TreasuryClient.TreasuryResponse) error {
	if DB == nil {
		return ErrDatabaseNotConnected
	}

	rawData, err := json.Marshal(response)
	if err != nil {
		return err
	}

	query := `
		INSERT INTO treasury_data (data_type, record_count, raw_data)
		VALUES ($1, $2, $3)
	`

	_, err = DB.Exec(ctx, query, dataType, len(response.Data), rawData)
	return err
}

// SaveCommodityData saves commodity price data to the database
func SaveCommodityData(ctx context.Context, commodity *CommoditiesClient.CommodityData) error {
	if DB == nil {
		return ErrDatabaseNotConnected
	}

	rawData, err := json.Marshal(commodity)
	if err != nil {
		return err
	}

	query := `
		INSERT INTO commodity_data (commodity_name, unit, interval, data_points, raw_data)
		VALUES ($1, $2, $3, $4, $5)
	`

	_, err = DB.Exec(ctx, query,
		commodity.Name,
		commodity.Unit,
		commodity.Interval,
		len(commodity.Data),
		rawData,
	)
	return err
}

// GetLatestTreasuryData retrieves the most recent treasury data by type
func GetLatestTreasuryData(ctx context.Context, dataType string) (json.RawMessage, error) {
	if DB == nil {
		return nil, ErrDatabaseNotConnected
	}

	query := `
		SELECT raw_data FROM treasury_data
		WHERE data_type = $1
		ORDER BY fetched_at DESC
		LIMIT 1
	`

	var rawData json.RawMessage
	err := DB.QueryRow(ctx, query, dataType).Scan(&rawData)
	return rawData, err
}

// GetLatestCommodityData retrieves the most recent commodity data by name
func GetLatestCommodityData(ctx context.Context, name string) (json.RawMessage, error) {
	if DB == nil {
		return nil, ErrDatabaseNotConnected
	}

	query := `
		SELECT raw_data FROM commodity_data
		WHERE commodity_name = $1
		ORDER BY fetched_at DESC
		LIMIT 1
	`

	var rawData json.RawMessage
	err := DB.QueryRow(ctx, query, name).Scan(&rawData)
	return rawData, err
}

