package middleware

import (
	"bytes"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/cache"
	"github.com/gin-gonic/gin"
)

// responseRecorder wraps gin.ResponseWriter so we can capture the response body
type responseRecorder struct {
	gin.ResponseWriter
	body *bytes.Buffer
}

func (r *responseRecorder) Write(b []byte) (int, error) {
	r.body.Write(b)
	return r.ResponseWriter.Write(b)
}

// ttlOverrides maps path prefixes to cache durations.
// More specific prefixes are checked first.
var ttlOverrides = []struct {
	prefix string
	ttl    time.Duration
}{
	{"/quote/", 2 * time.Minute},
	{"/ticker/", 5 * time.Minute},
	{"/stock/", 5 * time.Minute},
	{"/news/search", 5 * time.Minute},
	{"/finnews/", 10 * time.Minute},
	{"/news/general", 10 * time.Minute},
	{"/news/symbol/", 10 * time.Minute},
	{"/finnewsBert/", 15 * time.Minute},
	{"/sentiment/", 15 * time.Minute},
	{"/news/general/sentiment", 15 * time.Minute},
	{"/chart/", 30 * time.Minute},
	{"/commodities/", 30 * time.Minute},
	{"/profile/", 1 * time.Hour},
	{"/treasury/", 1 * time.Hour},
}

// skipPrefixes are paths that should never be cached
var skipPrefixes = []string{
	"/health",
	"/metrics",
	"/swagger/",
	"/finbert/",
}

// CacheMiddleware returns Gin middleware that caches GET responses in Redis.
// If Redis is unavailable, requests pass through un-cached.
func CacheMiddleware(defaultTTL time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Only cache GET requests
		if c.Request.Method != http.MethodGet {
			c.Next()
			return
		}

		path := c.Request.URL.Path

		// Skip non-cacheable endpoints
		for _, prefix := range skipPrefixes {
			if strings.HasPrefix(path, prefix) {
				c.Next()
				return
			}
		}

		// Skip if Redis is not connected
		if cache.Client == nil {
			c.Next()
			return
		}

		// Build cache key from full request URI (path + query params)
		cacheKey := "cache:" + c.Request.URL.RequestURI()

		// Try to serve from cache
		cached, err := cache.Get(c.Request.Context(), cacheKey)
		if err != nil {
			log.Printf("Redis GET error for %s: %v", cacheKey, err)
		}
		if cached != "" {
			c.Header("X-Cache", "HIT")
			c.Header("Content-Type", "application/json; charset=utf-8")
			c.String(http.StatusOK, cached)
			c.Abort()
			return
		}

		// Cache miss — record the response
		rec := &responseRecorder{
			ResponseWriter: c.Writer,
			body:           &bytes.Buffer{},
		}
		c.Writer = rec

		c.Next()

		// Only cache successful JSON responses
		if c.Writer.Status() != http.StatusOK {
			return
		}

		body := rec.body.String()
		if body == "" {
			return
		}

		ttl := resolveTTL(path, defaultTTL)

		if err := cache.Set(c.Request.Context(), cacheKey, body, ttl); err != nil {
			log.Printf("Redis SET error for %s: %v", cacheKey, err)
		}

		c.Header("X-Cache", "MISS")
	}
}

// resolveTTL picks the appropriate cache TTL for the given path
func resolveTTL(path string, defaultTTL time.Duration) time.Duration {
	for _, o := range ttlOverrides {
		if strings.HasPrefix(path, o.prefix) {
			return o.ttl
		}
	}
	return defaultTTL
}
