package middleware

import (
	"crypto/sha256"
	"encoding/hex"
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
	{"/sentiment/", 15},
	{"/news/general/sentiment", 20},
	{"/finnewsBert/", 20},
	{"/social/sentiment/", 15},
}

type rateLimitConfig struct {
	ipRPM   int
	keyRPM  int
	userRPM int
}

// loadRateLimitConfig reads layered rate-limits from env.
// Fallback order:
// - RATE_LIMIT_RPM_IP / RATE_LIMIT_RPM_KEY / RATE_LIMIT_RPM_USER
// - RATE_LIMIT_RPM
// - hardcoded default
func loadRateLimitConfig() rateLimitConfig {
	baseDefault := readPositiveIntFromEnv("RATE_LIMIT_RPM", 100)
	return rateLimitConfig{
		ipRPM:   readPositiveIntFromEnv("RATE_LIMIT_RPM_IP", baseDefault),
		keyRPM:  readPositiveIntFromEnv("RATE_LIMIT_RPM_KEY", baseDefault),
		userRPM: readPositiveIntFromEnv("RATE_LIMIT_RPM_USER", baseDefault),
	}
}

func readPositiveIntFromEnv(name string, fallback int) int {
	v := strings.TrimSpace(os.Getenv(name))
	if v == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(v)
	if err != nil || parsed <= 0 {
		return fallback
	}
	return parsed
}

// RateLimitMiddleware enforces per-IP sliding window rate limiting backed by Redis.
// Default limit is read from RATE_LIMIT_RPM env (default 100 req/min).
// Expensive endpoints have stricter limits.
// If Redis is unavailable the middleware is a no-op.
func RateLimitMiddleware() gin.HandlerFunc {
	config := loadRateLimitConfig()

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

		ipLimit := resolvePathLimit(path, config.ipRPM)
		ipAllowed, ipRemaining, err := enforceLimit(c, "ip", c.ClientIP(), ipLimit)
		if err != nil {
			log.Printf("Rate limiter Redis error (ip): %v", err)
			c.Next()
			return
		}
		c.Header("X-RateLimit-Limit-IP", strconv.Itoa(ipLimit))
		c.Header("X-RateLimit-Remaining-IP", strconv.FormatInt(ipRemaining, 10))
		if !ipAllowed {
			abortRateLimited(c, "ip")
			return
		}

		apiKey := APIKeyFromRequest(c)
		if apiKey != "" {
			keyLimit := resolvePathLimit(path, config.keyRPM)
			keyAllowed, keyRemaining, err := enforceLimit(c, "key", apiKey, keyLimit)
			if err != nil {
				log.Printf("Rate limiter Redis error (key): %v", err)
				c.Next()
				return
			}
			c.Header("X-RateLimit-Limit-Key", strconv.Itoa(keyLimit))
			c.Header("X-RateLimit-Remaining-Key", strconv.FormatInt(keyRemaining, 10))
			if !keyAllowed {
				abortRateLimited(c, "key")
				return
			}
		}

		c.Next()
	}
}

// UserRateLimitMiddleware enforces per-authenticated-user limits.
// Register this after AuthMiddleware so the "uid" context value is available.
func UserRateLimitMiddleware() gin.HandlerFunc {
	config := loadRateLimitConfig()

	return func(c *gin.Context) {
		if cache.Client == nil {
			c.Next()
			return
		}

		path := c.Request.URL.Path
		for _, prefix := range skipAuthPrefixes {
			if strings.HasPrefix(path, prefix) {
				c.Next()
				return
			}
		}

		uidValue, exists := c.Get("uid")
		uid, ok := uidValue.(string)
		if !exists || !ok || strings.TrimSpace(uid) == "" {
			c.Next()
			return
		}

		userLimit := resolvePathLimit(path, config.userRPM)
		userAllowed, userRemaining, err := enforceLimit(c, "user", uid, userLimit)
		if err != nil {
			log.Printf("Rate limiter Redis error (user): %v", err)
			c.Next()
			return
		}

		c.Header("X-RateLimit-Limit-User", strconv.Itoa(userLimit))
		c.Header("X-RateLimit-Remaining-User", strconv.FormatInt(userRemaining, 10))
		if !userAllowed {
			abortRateLimited(c, "user")
			return
		}

		c.Next()
	}
}

func resolvePathLimit(path string, defaultLimit int) int {
	for _, s := range strictLimitPrefixes {
		if strings.HasPrefix(path, s.prefix) {
			return s.rpm
		}
	}
	return defaultLimit
}

func enforceLimit(c *gin.Context, subjectType, subjectID string, limit int) (bool, int64, error) {
	ctx := c.Request.Context()
	window := time.Minute
	bucket := bucketKey(c.Request.URL.Path, limit)

	redisKey := fmt.Sprintf("ratelimit:%s:%s:%s", subjectType, normalizedSubjectID(subjectID), bucket)
	count, err := cache.Client.Incr(ctx, redisKey).Result()
	if err != nil {
		return true, int64(limit), err
	}

	if count == 1 {
		cache.Client.Expire(ctx, redisKey, window)
	}

	remaining := int64(limit) - count
	if remaining < 0 {
		remaining = 0
	}

	if count > int64(limit) {
		return false, remaining, nil
	}

	return true, remaining, nil
}

func normalizedSubjectID(value string) string {
	hash := sha256.Sum256([]byte(value))
	// 16 hex chars is enough for compact redis keys while avoiding raw IDs.
	return hex.EncodeToString(hash[:8])
}

func abortRateLimited(c *gin.Context, subject string) {
	retryAfter := 60
	c.Header("Retry-After", strconv.Itoa(retryAfter))
	c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
		"error":       "Rate limit exceeded",
		"subject":     subject,
		"retry_after": retryAfter,
	})
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
