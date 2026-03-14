package ws

import (
	"log"
	"sync"
)

// Hub manages WebSocket client connections and message broadcasting.
type Hub struct {
	// Registered clients grouped by topic (e.g., "quotes:AAPL", "news")
	clients map[string]map[*Client]bool
	mu      sync.RWMutex

	// Register requests from clients
	Register chan *Client

	// Unregister requests from clients
	Unregister chan *Client

	// Broadcast sends a message to all clients on a given topic
	Broadcast chan *BroadcastMessage
}

// BroadcastMessage is a message to send to all clients on a topic.
type BroadcastMessage struct {
	Topic   string
	Payload []byte
}

// NewHub creates a new WebSocket Hub.
func NewHub() *Hub {
	return &Hub{
		clients:    make(map[string]map[*Client]bool),
		Register:   make(chan *Client),
		Unregister: make(chan *Client),
		Broadcast:  make(chan *BroadcastMessage, 256),
	}
}

// Run starts the hub's event loop. Call as a goroutine.
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.Register:
			h.mu.Lock()
			if h.clients[client.Topic] == nil {
				h.clients[client.Topic] = make(map[*Client]bool)
			}
			h.clients[client.Topic][client] = true
			h.mu.Unlock()
			log.Printf("WS client registered on topic %s (total: %d)", client.Topic, h.TopicCount(client.Topic))

		case client := <-h.Unregister:
			h.mu.Lock()
			if clients, ok := h.clients[client.Topic]; ok {
				if _, exists := clients[client]; exists {
					delete(clients, client)
					close(client.Send)
					if len(clients) == 0 {
						delete(h.clients, client.Topic)
					}
				}
			}
			h.mu.Unlock()
			log.Printf("WS client unregistered from topic %s", client.Topic)

		case msg := <-h.Broadcast:
			h.mu.RLock()
			clients := h.clients[msg.Topic]
			h.mu.RUnlock()

			for client := range clients {
				select {
				case client.Send <- msg.Payload:
				default:
					// Client buffer full — disconnect
					h.mu.Lock()
					delete(h.clients[msg.Topic], client)
					close(client.Send)
					h.mu.Unlock()
				}
			}
		}
	}
}

// TopicCount returns the number of clients on a topic.
func (h *Hub) TopicCount(topic string) int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients[topic])
}

// ActiveTopics returns all topics that have at least one client.
func (h *Hub) ActiveTopics() []string {
	h.mu.RLock()
	defer h.mu.RUnlock()

	topics := make([]string, 0, len(h.clients))
	for topic, clients := range h.clients {
		if len(clients) > 0 {
			topics = append(topics, topic)
		}
	}
	return topics
}
