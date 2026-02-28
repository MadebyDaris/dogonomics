package cache

import (
	"context"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
)

// Client is the package-level Redis client
var Client *redis.Client

// Config holds Redis connection configuration
type Config struct {
	Host     string
	Port     string
	Password string
	DB       int
}

// LoadConfigFromEnv loads Redis configuration from environment variables
func LoadConfigFromEnv() *Config {
	db, _ := strconv.Atoi(getEnv("REDIS_DB", "0"))
	return &Config{
		Host:     getEnv("REDIS_HOST", "localhost"),
		Port:     getEnv("REDIS_PORT", "6379"),
		Password: getEnv("REDIS_PASSWORD", ""),
		DB:       db,
	}
}

func getEnv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

// Connect initialises the Redis client and pings to verify connectivity.
// Returns nil on success; the caller should log and continue without cache on error.
func Connect(cfg *Config) error {
	Client = redis.NewClient(&redis.Options{
		Addr:         fmt.Sprintf("%s:%s", cfg.Host, cfg.Port),
		Password:     cfg.Password,
		DB:           cfg.DB,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
		PoolSize:     10,
		MinIdleConns: 2,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := Client.Ping(ctx).Err(); err != nil {
		Client = nil
		return fmt.Errorf("unable to ping Redis at %s:%s: %w", cfg.Host, cfg.Port, err)
	}

	log.Printf("Connected to Redis at %s:%s (db %d)", cfg.Host, cfg.Port, cfg.DB)
	return nil
}

// Close shuts down the Redis client connection
func Close() {
	if Client != nil {
		if err := Client.Close(); err != nil {
			log.Printf("Error closing Redis connection: %v", err)
		} else {
			log.Println("Redis connection closed")
		}
	}
}

// Get retrieves a cached value by key. Returns ("", nil) on cache miss.
func Get(ctx context.Context, key string) (string, error) {
	if Client == nil {
		return "", nil
	}
	val, err := Client.Get(ctx, key).Result()
	if err == redis.Nil {
		return "", nil
	}
	return val, err
}

// Set stores a value with the given TTL
func Set(ctx context.Context, key string, value string, ttl time.Duration) error {
	if Client == nil {
		return nil
	}
	return Client.Set(ctx, key, value, ttl).Err()
}

// Delete removes a cached entry
func Delete(ctx context.Context, key string) error {
	if Client == nil {
		return nil
	}
	return Client.Del(ctx, key).Err()
}

// HealthCheck verifies the Redis connection is alive
func HealthCheck(ctx context.Context) error {
	if Client == nil {
		return fmt.Errorf("redis not initialised")
	}
	return Client.Ping(ctx).Err()
}
