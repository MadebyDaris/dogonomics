package events

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"time"

	"github.com/segmentio/kafka-go"
)

// Topics for Kafka event publishing
const (
	TopicQuotes     = "dogonomics.quotes"
	TopicNews       = "dogonomics.news"
	TopicSentiment  = "dogonomics.sentiment"
	TopicMarketData = "dogonomics.market-data"
)

// Event represents a published event
type Event struct {
	Type      string      `json:"type"`
	Symbol    string      `json:"symbol,omitempty"`
	Source    string      `json:"source"`
	Data      interface{} `json:"data"`
	Timestamp time.Time   `json:"timestamp"`
}

// Producer wraps Kafka writer with graceful degradation
type Producer struct {
	writer  *kafka.Writer
	enabled bool
}

// NewProducer creates a new Kafka producer.
// Returns a disabled producer if KAFKA_BROKER is not set.
func NewProducer() *Producer {
	broker := os.Getenv("KAFKA_BROKER")
	if broker == "" {
		log.Println("KAFKA_BROKER not set — event publishing disabled")
		return &Producer{enabled: false}
	}

	writer := &kafka.Writer{
		Addr:         kafka.TCP(broker),
		Balancer:     &kafka.LeastBytes{},
		BatchTimeout: 50 * time.Millisecond,
		BatchSize:    100,
		Async:        true, // Non-blocking writes
		RequiredAcks: kafka.RequireOne,
		Logger:       log.New(os.Stdout, "[kafka] ", log.LstdFlags),
		ErrorLogger:  log.New(os.Stderr, "[kafka-err] ", log.LstdFlags),
	}

	log.Printf("Kafka producer connected to %s", broker)
	return &Producer{writer: writer, enabled: true}
}

// Publish sends an event to the specified Kafka topic.
// Silently returns nil if Kafka is disabled or on error (graceful degradation).
func (p *Producer) Publish(ctx context.Context, topic string, event *Event) error {
	if !p.enabled || p.writer == nil {
		return nil
	}

	payload, err := json.Marshal(event)
	if err != nil {
		log.Printf("Kafka: failed to marshal event: %v", err)
		return nil // graceful degradation
	}

	key := []byte(event.Type)
	if event.Symbol != "" {
		key = []byte(event.Symbol)
	}

	err = p.writer.WriteMessages(ctx, kafka.Message{
		Topic: topic,
		Key:   key,
		Value: payload,
	})
	if err != nil {
		log.Printf("Kafka: failed to publish to %s: %v", topic, err)
		return nil // graceful degradation
	}

	return nil
}

// PublishQuote publishes a quote event
func (p *Producer) PublishQuote(ctx context.Context, symbol string, data interface{}) {
	p.Publish(ctx, TopicQuotes, &Event{
		Type:      "quote",
		Symbol:    symbol,
		Source:    "finnhub",
		Data:      data,
		Timestamp: time.Now().UTC(),
	})
}

// PublishNews publishes a news event
func (p *Producer) PublishNews(ctx context.Context, symbol string, data interface{}) {
	p.Publish(ctx, TopicNews, &Event{
		Type:      "news",
		Symbol:    symbol,
		Source:    "multi-source",
		Data:      data,
		Timestamp: time.Now().UTC(),
	})
}

// PublishSentiment publishes a sentiment analysis event
func (p *Producer) PublishSentiment(ctx context.Context, symbol string, data interface{}) {
	p.Publish(ctx, TopicSentiment, &Event{
		Type:      "sentiment",
		Symbol:    symbol,
		Source:    "finbert",
		Data:      data,
		Timestamp: time.Now().UTC(),
	})
}

// PublishMarketData publishes a market data event (treasury, commodity)
func (p *Producer) PublishMarketData(ctx context.Context, dataType string, data interface{}) {
	p.Publish(ctx, TopicMarketData, &Event{
		Type:      dataType,
		Source:    "api",
		Data:      data,
		Timestamp: time.Now().UTC(),
	})
}

// IsEnabled returns whether Kafka publishing is active
func (p *Producer) IsEnabled() bool {
	return p.enabled
}

// Close shuts down the Kafka producer
func (p *Producer) Close() error {
	if p.writer != nil {
		log.Println("Closing Kafka producer...")
		return p.writer.Close()
	}
	return nil
}
