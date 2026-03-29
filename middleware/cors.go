package middleware

import (
	"net/http"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
)

// CORSMiddleware handles Cross-Origin Resource Sharing.
// Allowed origins are read from the ALLOWED_ORIGINS environment variable
// (comma-separated). If not set, defaults to "*" for local development.
func CORSMiddleware() gin.HandlerFunc {
	allowedOrigins := parseAllowedOrigins()

	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")

		// Determine if origin is allowed
		allowed := false
		responseOrigin := ""
		for _, ao := range allowedOrigins {
			if ao == "*" {
				allowed = true
				responseOrigin = "*"
				break
			}
			if strings.EqualFold(ao, origin) {
				allowed = true
				responseOrigin = origin
				break
			}
		}

		if allowed {
			c.Header("Access-Control-Allow-Origin", responseOrigin)
		}

		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Requested-With, X-Request-Timeout, X-API-Key")
		c.Header("Access-Control-Expose-Headers", "X-Cache, X-Request-ID, X-RateLimit-Remaining")
		c.Header("Access-Control-Max-Age", "43200") // 12 hours
		c.Header("Access-Control-Allow-Credentials", "true")

		// Handle preflight
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}

func parseAllowedOrigins() []string {
	raw := os.Getenv("ALLOWED_ORIGINS")
	if raw == "" {
		return []string{"*"}
	}

	origins := strings.Split(raw, ",")
	cleaned := make([]string, 0, len(origins))
	for _, o := range origins {
		o = strings.TrimSpace(o)
		if o != "" {
			cleaned = append(cleaned, o)
		}
	}
	if len(cleaned) == 0 {
		return []string{"*"}
	}
	return cleaned
}
