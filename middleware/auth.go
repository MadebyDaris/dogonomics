package middleware

import (
	"context"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"google.golang.org/api/option"
)

var (
	firebaseApp  *firebase.App
	authClient   *auth.Client
	firebaseOnce sync.Once
	firebaseErr  error
)

// InitFirebase initializes the Firebase Admin SDK.
// Call this once at startup before registering the auth middleware.
// It reads the service-account JSON from FIREBASE_SERVICE_ACCOUNT_PATH (file)
// or FIREBASE_SERVICE_ACCOUNT_JSON (raw JSON string).
// Backward compatibility: FIREBASE_CREDENTIALS is also accepted as a file path.
func InitFirebase() error {
	firebaseOnce.Do(func() {
		ctx := context.Background()

		var opts []option.ClientOption

		if path := os.Getenv("FIREBASE_SERVICE_ACCOUNT_PATH"); path != "" {
			opts = append(opts, option.WithCredentialsFile(path))
		} else if legacyPath := os.Getenv("FIREBASE_CREDENTIALS"); legacyPath != "" {
			// Keep supporting older deployments that still use FIREBASE_CREDENTIALS.
			opts = append(opts, option.WithCredentialsFile(legacyPath))
		} else if raw := os.Getenv("FIREBASE_SERVICE_ACCOUNT_JSON"); raw != "" {
			opts = append(opts, option.WithCredentialsJSON([]byte(raw)))
		}
		// If neither is set, firebase.NewApp will try GOOGLE_APPLICATION_CREDENTIALS
		// or the GCE metadata server (when running on GCP).

		firebaseApp, firebaseErr = firebase.NewApp(ctx, nil, opts...)
		if firebaseErr != nil {
			log.Printf("ERROR: Firebase app init failed: %v", firebaseErr)
			return
		}

		authClient, firebaseErr = firebaseApp.Auth(ctx)
		if firebaseErr != nil {
			log.Printf("ERROR: Firebase Auth client init failed: %v", firebaseErr)
			return
		}

		log.Println("Firebase Admin SDK initialized successfully")
	})
	return firebaseErr
}

// skipAuthPrefixes are path prefixes that bypass authentication.
var skipAuthPrefixes = []string{
	"/health",
	"/metrics",
	"/swagger/",
}

// AuthMiddleware validates Firebase ID tokens on incoming requests.
// Requests without a valid Bearer token receive a 401 response.
// Authenticated requests get "uid" and "email" set in the Gin context.
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		path := c.Request.URL.Path

		// Skip auth for exempt paths
		for _, prefix := range skipAuthPrefixes {
			if strings.HasPrefix(path, prefix) {
				c.Next()
				return
			}
		}

		// Skip auth for WebSocket upgrade requests — they authenticate via query param
		if strings.HasPrefix(path, "/ws/") {
			c.Next()
			return
		}

		// If Firebase was not initialized, allow requests through with a warning
		// (graceful degradation for local dev without Firebase credentials)
		if authClient == nil {
			log.Println("WARNING: Firebase Auth not initialized — skipping token verification")
			c.Set("uid", "anonymous")
			c.Set("email", "")
			c.Next()
			return
		}

		// Extract Bearer token from Authorization header
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Missing Authorization header",
			})
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Authorization header must be 'Bearer <token>'",
			})
			return
		}
		idToken := parts[1]

		// Verify the Firebase ID token
		ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
		defer cancel()

		token, err := authClient.VerifyIDToken(ctx, idToken)
		if err != nil {
			log.Printf("Token verification failed: %v", err)
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Invalid or expired token",
			})
			return
		}

		// Inject user info into request context
		c.Set("uid", token.UID)
		if email, ok := token.Claims["email"].(string); ok {
			c.Set("email", email)
		}

		c.Next()
	}
}

// VerifyWSToken validates a Firebase ID token for WebSocket connections.
// Returns the user UID on success or an error.
func VerifyWSToken(tokenString string) (string, error) {
	if authClient == nil {
		// Graceful degradation
		return "anonymous", nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	token, err := authClient.VerifyIDToken(ctx, tokenString)
	if err != nil {
		return "", err
	}
	return token.UID, nil
}
