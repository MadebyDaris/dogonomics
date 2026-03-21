package RedditScraper

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"
)

// RedditPost represents a single post on Reddit
type RedditPost struct {
	ID        string  `json:"id"`
	Title     string  `json:"title"`
	SelfText  string  `json:"selftext"`
	Author    string  `json:"author"`
	URL       string  `json:"url"`
	Permalink string  `json:"permalink"`
	Upvotes   int     `json:"ups"`
	Downvotes int     `json:"downs"`
	Comments  int     `json:"num_comments"`
	Created   float64 `json:"created_utc"`
	Subreddit string  `json:"subreddit"`
	IsVideo   bool    `json:"is_video"`
	Stickied  bool    `json:"stickied"`
	Thumbnail string  `json:"thumbnail,omitempty"`
}

// ToNewsArticle converts a RedditPost to a standardized NewsArticle
func (p RedditPost) ToNewsArticle() map[string]interface{} {
	return map[string]interface{}{
		"title":        p.Title,
		"description":  p.SelfText,
		"content":      p.SelfText,
		"source":       "reddit",
		"url":          fmt.Sprintf("https://www.reddit.com%s", p.Permalink),
		"published_at": time.Unix(int64(p.Created), 0),
		"author":       p.Author,
		"image_url":    p.Thumbnail,
		"category":     p.Subreddit,
	}
}

// RedditResponse is the top-level JSON structure returned by Reddit
type RedditResponse struct {
	Kind string `json:"kind"`
	Data struct {
		Children []struct {
			Kind string     `json:"kind"`
			Data RedditPost `json:"data"`
		} `json:"children"`
	} `json:"data"`
}

// Scraper handles reddit scraping operations
type Scraper struct {
	client *http.Client
}

// NewScraper creates a new Reddit scraper instance
func NewScraper() *Scraper {
	return &Scraper{
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// ScrapeSubreddit fetches the latest hot posts from a subreddit
func (s *Scraper) ScrapeSubreddit(subreddit string, limit int) ([]RedditPost, error) {
	url := fmt.Sprintf("https://www.reddit.com/r/%s/hot.json?limit=%d", subreddit, limit)
	
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	// Reddit API requires a custom User-Agent to avoid 429/403 errors
	req.Header.Set("User-Agent", "go:dogonomics:v1.0.0 (by /u/dogonomics_dev)")

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("reddit api returned status: %d for subreddit %s", resp.StatusCode, subreddit)
	}

	var result RedditResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}

	posts := make([]RedditPost, 0, len(result.Data.Children))
	for _, child := range result.Data.Children {
		// Filter out stickied posts if desired, or keep them. 
		// For now, we keep them but could be filtered.
		posts = append(posts, child.Data)
	}

	return posts, nil
}

// GetFinancialNews scrapes multiple financial subreddits and aggregates the results
func (s *Scraper) GetFinancialNews(limitPerSub int) ([]RedditPost, []error) {
	subreddits := []string{"finance", "StockMarket", "investing", "stocks", "wallstreetbets", "Economics"}
	var allPosts []RedditPost
	var errors []error
	var mu sync.Mutex
	var wg sync.WaitGroup

	for _, sub := range subreddits {
		wg.Add(1)
		go func(subreddit string) {
			defer wg.Done()
			posts, err := s.ScrapeSubreddit(subreddit, limitPerSub)
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				errors = append(errors, fmt.Errorf("error scraping r/%s: %w", subreddit, err))
			} else {
				allPosts = append(allPosts, posts...)
			}
		}(sub)
	}

	wg.Wait()
	
	return allPosts, errors
}
