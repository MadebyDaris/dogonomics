package database

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// APIRequest represents a logged API request
type APIRequest struct {
	ID             uuid.UUID
	Timestamp      time.Time
	Endpoint       string
	Method         string
	Symbol         *string
	StatusCode     int
	ResponseTimeMS int
	UserAgent      *string
	IPAddress      *string
	ErrorMessage   *string
}

// LogAPIRequest saves an API request to the database
func LogAPIRequest(ctx context.Context, req *APIRequest) error {
	if DB == nil {
		return nil // Silently skip if DB not configured
	}

	query := `
		INSERT INTO api_requests (
			endpoint, method, symbol, status_code, response_time_ms,
			user_agent, ip_address, error_message
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`

	_, err := DB.Exec(ctx, query,
		req.Endpoint,
		req.Method,
		req.Symbol,
		req.StatusCode,
		req.ResponseTimeMS,
		req.UserAgent,
		req.IPAddress,
		req.ErrorMessage,
	)

	return err
}

// GetRecentAPIRequests retrieves recent API requests
func GetRecentAPIRequests(ctx context.Context, limit int) ([]APIRequest, error) {
	if DB == nil {
		return nil, nil
	}

	query := `
		SELECT id, timestamp, endpoint, method, symbol, status_code,
		       response_time_ms, user_agent, ip_address, error_message
		FROM api_requests
		ORDER BY timestamp DESC
		LIMIT $1
	`

	rows, err := DB.Query(ctx, query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var requests []APIRequest
	for rows.Next() {
		var req APIRequest
		err := rows.Scan(
			&req.ID,
			&req.Timestamp,
			&req.Endpoint,
			&req.Method,
			&req.Symbol,
			&req.StatusCode,
			&req.ResponseTimeMS,
			&req.UserAgent,
			&req.IPAddress,
			&req.ErrorMessage,
		)
		if err != nil {
			return nil, err
		}
		requests = append(requests, req)
	}

	return requests, rows.Err()
}

// GetRequestCountBySymbol returns request counts grouped by symbol
func GetRequestCountBySymbol(ctx context.Context, since time.Time) (map[string]int, error) {
	if DB == nil {
		return make(map[string]int), nil
	}

	query := `
		SELECT symbol, COUNT(*) as count
		FROM api_requests
		WHERE symbol IS NOT NULL
		  AND timestamp >= $1
		GROUP BY symbol
		ORDER BY count DESC
	`

	rows, err := DB.Query(ctx, query, since)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	counts := make(map[string]int)
	for rows.Next() {
		var symbol string
		var count int
		if err := rows.Scan(&symbol, &count); err != nil {
			return nil, err
		}
		counts[symbol] = count
	}

	return counts, rows.Err()
}
