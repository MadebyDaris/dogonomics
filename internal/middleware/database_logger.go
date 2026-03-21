package middleware

import (
	"context"
	"strings"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/database"
	"github.com/gin-gonic/gin"
)

// DatabaseLogger middleware logs all API requests to the database
func DatabaseLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()

		// Process request
		c.Next()

		// Calculate response time
		duration := time.Since(start)
		responseTimeMS := int(duration.Milliseconds())

		// Extract symbol from path if present
		var symbol *string
		if sym := c.Param("symbol"); sym != "" {
			symbol = &sym
		}

		// Get user agent and IP
		userAgent := c.Request.UserAgent()
		ipAddress := c.ClientIP()

		// Get error message if any
		var errorMsg *string
		if len(c.Errors) > 0 {
			msg := c.Errors.String()
			errorMsg = &msg
		}

		// Log to database asynchronously
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()

			req := &database.APIRequest{
				Endpoint:       c.FullPath(),
				Method:         c.Request.Method,
				Symbol:         symbol,
				StatusCode:     c.Writer.Status(),
				ResponseTimeMS: responseTimeMS,
				UserAgent:      &userAgent,
				IPAddress:      &ipAddress,
				ErrorMessage:   errorMsg,
			}

			if err := database.LogAPIRequest(ctx, req); err != nil {
				// Log error but don't fail the request
				c.Error(err)
			}
		}()
	}
}

// extractSymbolFromPath extracts the symbol parameter from various endpoint patterns
func extractSymbolFromPath(path string) string {
	// Common patterns: /stock/:symbol, /quote/:symbol, etc.
	parts := strings.Split(path, "/")
	for i, part := range parts {
		if part == "stock" || part == "quote" || part == "news" ||
			part == "sentiment" || part == "chart" || part == "profile" || part == "ticker" {
			if i+1 < len(parts) {
				return parts[i+1]
			}
		}
	}
	return ""
}
