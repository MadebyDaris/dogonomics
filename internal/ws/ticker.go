package ws

import (
	"context"
	"encoding/json"
	"log"
	"strings"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/api/finnhub"
)

// QuoteTicker periodically fetches quotes for symbols that have active WS
// subscribers and broadcasts updates. Call as a goroutine.
func QuoteTicker(ctx context.Context, hub *Hub, client *DogonomicsFetching.Client, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	log.Printf("WS quote ticker started (interval: %s)", interval)

	for {
		select {
		case <-ctx.Done():
			log.Println("WS quote ticker stopped")
			return
		case <-ticker.C:
			topics := hub.ActiveTopics()
			for _, topic := range topics {
				if !strings.HasPrefix(topic, "quotes:") {
					continue
				}
				symbol := strings.TrimPrefix(topic, "quotes:")
				if symbol == "" {
					continue
				}

				fetchCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
				quote, err := client.GetQuote(fetchCtx, symbol)
				cancel()

				if err != nil {
					log.Printf("WS ticker: failed to fetch quote for %s: %v", symbol, err)
					continue
				}

				payload, err := json.Marshal(map[string]interface{}{
					"type":      "quote",
					"symbol":    symbol,
					"data":      quote,
					"timestamp": time.Now().UTC(),
				})
				if err != nil {
					continue
				}

				hub.Broadcast <- &BroadcastMessage{
					Topic:   topic,
					Payload: payload,
				}
			}
		}
	}
}

// NewsTicker periodically sends a heartbeat/status to news subscribers.
// Actual news events are published by handlers via PublishNewsEvent.
func NewsTicker(ctx context.Context, hub *Hub, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if hub.TopicCount("news") == 0 {
				continue
			}

			payload, _ := json.Marshal(map[string]interface{}{
				"type":      "heartbeat",
				"topic":     "news",
				"timestamp": time.Now().UTC(),
			})

			hub.Broadcast <- &BroadcastMessage{
				Topic:   "news",
				Payload: payload,
			}
		}
	}
}

// PublishQuoteEvent sends a real-time quote event to WebSocket subscribers.
func PublishQuoteEvent(hub *Hub, symbol string, data interface{}) {
	if hub == nil {
		return
	}

	topic := "quotes:" + symbol
	if hub.TopicCount(topic) == 0 {
		return
	}

	payload, err := json.Marshal(map[string]interface{}{
		"type":      "quote",
		"symbol":    symbol,
		"data":      data,
		"timestamp": time.Now().UTC(),
	})
	if err != nil {
		return
	}

	hub.Broadcast <- &BroadcastMessage{
		Topic:   topic,
		Payload: payload,
	}
}

// PublishNewsEvent sends a news event to WebSocket subscribers.
func PublishNewsEvent(hub *Hub, symbol string, data interface{}) {
	if hub == nil {
		return
	}

	if hub.TopicCount("news") == 0 {
		return
	}

	payload, err := json.Marshal(map[string]interface{}{
		"type":      "news",
		"symbol":    symbol,
		"data":      data,
		"timestamp": time.Now().UTC(),
	})
	if err != nil {
		return
	}

	hub.Broadcast <- &BroadcastMessage{
		Topic:   "news",
		Payload: payload,
	}
}

