package ws

import (
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

const (
	// Time allowed to write a message to the client.
	writeWait = 10 * time.Second

	// Time allowed to read the next pong message from the client.
	pongWait = 60 * time.Second

	// Send pings to client with this period (must be < pongWait).
	pingPeriod = (pongWait * 9) / 10

	// Maximum message size allowed from client.
	maxMessageSize = 512
)

// Client represents a single WebSocket connection.
type Client struct {
	Hub   *Hub
	Conn  *websocket.Conn
	Send  chan []byte
	Topic string
}

// readPump pumps messages from the WebSocket to the hub.
// Only used for pong/close handling — clients don't send data.
func (c *Client) readPump() {
	defer func() {
		c.Hub.Unregister <- c
		c.Conn.Close()
	}()

	c.Conn.SetReadLimit(maxMessageSize)
	c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error {
		c.Conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, _, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure) {
				log.Printf("WS read error: %v", err)
			}
			break
		}
	}
}

// writePump pumps messages from the hub to the WebSocket connection.
func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.Send:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// Hub closed the channel
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.Conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Drain queued messages into current write
			n := len(c.Send)
			for i := 0; i < n; i++ {
				w.Write([]byte("\n"))
				w.Write(<-c.Send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// Upgrader for WebSocket connections
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		raw := os.Getenv("ALLOWED_ORIGINS")
		if raw == "" || raw == "*" {
			return true // Allow all in dev
		}
		origin := r.Header.Get("Origin")
		for _, allowed := range strings.Split(raw, ",") {
			if strings.TrimSpace(allowed) == origin {
				return true
			}
		}
		log.Printf("WS origin rejected: %s", origin)
		return false
	},
}

// ServeWS upgrades an HTTP connection to WebSocket and registers the client.
func ServeWS(hub *Hub, topic string, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WS upgrade error: %v", err)
		return
	}

	client := &Client{
		Hub:   hub,
		Conn:  conn,
		Send:  make(chan []byte, 256),
		Topic: topic,
	}

	hub.Register <- client

	go client.writePump()
	go client.readPump()
}
