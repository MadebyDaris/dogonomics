package middleware

import (
	"log"
	"net/http"
	"os"
	"strings"
	"sync"

	"github.com/gin-gonic/gin"
)

var (
	apiKeyOnce        sync.Once
	apiKeyRequired    bool
	allowedAPIKeysMap map[string]struct{}
)

// initAPIKeyConfig reads API-key middleware settings from environment variables.
// Supported variables:
// - API_KEY_REQUIRED=true|false
// - API_ALLOWED_KEYS=key1,key2,key3
// - API_KEY=single_key (legacy/convenience)
func initAPIKeyConfig() {
	apiKeyOnce.Do(func() {
		apiKeyRequired = strings.EqualFold(os.Getenv("API_KEY_REQUIRED"), "true")
		allowedAPIKeysMap = make(map[string]struct{})

		rawKeys := []string{
			os.Getenv("API_ALLOWED_KEYS"),
			os.Getenv("API_KEY"),
		}

		for _, raw := range rawKeys {
			for _, key := range strings.Split(raw, ",") {
				trimmed := strings.TrimSpace(key)
				if trimmed == "" {
					continue
				}
				allowedAPIKeysMap[trimmed] = struct{}{}
			}
		}

		if len(allowedAPIKeysMap) == 0 {
			if apiKeyRequired {
				log.Println("WARNING: API_KEY_REQUIRED=true but no keys configured in API_ALLOWED_KEYS/API_KEY")
			} else {
				log.Println("WARNING: API key enforcement disabled (no keys configured and API_KEY_REQUIRED!=true)")
			}
		}
	})
}

// IsAPIKeyAuthorized checks if a supplied API key is in the configured allowlist.
func IsAPIKeyAuthorized(key string) bool {
	initAPIKeyConfig()
	if len(allowedAPIKeysMap) == 0 {
		return !apiKeyRequired
	}
	_, ok := allowedAPIKeysMap[key]
	return ok
}

// APIKeyFromRequest extracts API key from request header or query param.
// Header is preferred: X-API-Key.
// Query fallback supports WebSocket clients: ?api_key=...
func APIKeyFromRequest(c *gin.Context) string {
	if key := strings.TrimSpace(c.GetHeader("X-API-Key")); key != "" {
		return key
	}
	return strings.TrimSpace(c.Query("api_key"))
}

// APIKeyMiddleware enforces an allow-listed API key for REST endpoints.
func APIKeyMiddleware() gin.HandlerFunc {
	initAPIKeyConfig()

	return func(c *gin.Context) {
		path := c.Request.URL.Path

		// Skip infra and docs paths.
		for _, prefix := range skipAuthPrefixes {
			if strings.HasPrefix(path, prefix) {
				c.Next()
				return
			}
		}

		// WebSocket endpoints validate api_key in the route handler.
		if strings.HasPrefix(path, "/ws/") {
			c.Next()
			return
		}

		if len(allowedAPIKeysMap) == 0 && !apiKeyRequired {
			c.Next()
			return
		}

		key := APIKeyFromRequest(c)
		if !IsAPIKeyAuthorized(key) {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Invalid or missing API key",
			})
			return
		}

		c.Next()
	}
}
