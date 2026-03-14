package middleware

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/cache"
	"github.com/gin-gonic/gin"
)

// strictLimitPrefixes maps expensive endpoint prefixes to their per-minute limit.
var strictLimitPrefixes = []struct {
	prefix string
	rpm    int
}{
	{"/finbert/inference", 10},
	{"/news/general/sentiment", 20},
	{"/finnewsBert/", 20},
}

// RateLimitMiddleware enforces per-IP sliding window rate limiting backed by Redis.
// Default limit is read from RATE_LIMIT_RPM env (default 100 req/min).
// Expensive endpoints have stricter limits.
// If Redis is unavailable the middleware is a no-op.
func RateLimitMiddleware() gin.HandlerFunc {
	defaultRPM := 100
	if v := os.Getenv("RATE_LIMIT_RPM"); v != "" {
		if parsed, err := strconv.Atoi(v); err == nil && parsed > 0 {
			defaultRPM = parsed
		}
	}

	return func(c *gin.Context) {
		// Skip if Redis is not available
		if cache.Client == nil {
			c.Next()
			return
		}

		// Skip health / metrics / swagger
		path := c.Request.URL.Path
		for _, prefix := range skipAuthPrefixes {
			if strings.HasPrefix(path, prefix) {
				c.Next()
				return
			}
		}

		ip := c.ClientIP()
		limit := defaultRPM

		// Check for stricter limits on expensive endpoints
		for _, s := range strictLimitPrefixes {
			if strings.HasPrefix(path, s.prefix) {
				limit = s.rpm
				break
			}
		}

		key := fmt.Sprintf("ratelimit:%s:%s", ip, bucketKey(path, limit))
		window := time.Minute

		ctx := c.Request.Context()

		// Increment counter
		count, err := cache.Client.Incr(ctx, key).Result()
		if err != nil {
			log.Printf("Rate limiter Redis INCR error: %v", err)
			c.Next()
			return
		}

		// Set expiry on first request in the window
		if count == 1 {
			cache.Client.Expire(ctx, key, window)
		}

		// Set rate-limit headers
		remaining := int64(limit) - count
		if remaining < 0 {
			remaining = 0
		}
		c.Header("X-RateLimit-Limit", strconv.Itoa(limit))
		c.Header("X-RateLimit-Remaining", strconv.FormatInt(remaining, 10))

		if count > int64(limit) {
			retryAfter := 60 // seconds until window resets
			c.Header("Retry-After", strconv.Itoa(retryAfter))
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error":       "Rate limit exceeded",
				"retry_after": retryAfter,
			})
			return
		}

		c.Next()
	}
}

// bucketKey groups rate-limit counters.
// Expensive endpoints get their own counter; everything else shares one.
func bucketKey(path string, limit int) string {
	for _, s := range strictLimitPrefixes {
		if strings.HasPrefix(path, s.prefix) {
			return fmt.Sprintf("strict:%s", s.prefix)
		}
	}
	return "default"
}
