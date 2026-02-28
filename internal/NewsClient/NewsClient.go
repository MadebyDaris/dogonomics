package NewsClient

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

// NewsArticle represents a standardized news article from any source
type NewsArticle struct {
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Content     string    `json:"content"`
	Source      string    `json:"source"`
	URL         string    `json:"url"`
	PublishedAt time.Time `json:"published_at"`
	Author      string    `json:"author,omitempty"`
	ImageURL    string    `json:"image_url,omitempty"`
	Category    string    `json:"category,omitempty"`
}

// NewsClient handles fetching news from multiple sources
type NewsClient struct {
	finnhubKey string
	eodhKey    string
	alphaKey   string
}

// NewNewsClient creates a new multi-source news client
func NewNewsClient() *NewsClient {
	return &NewsClient{
		finnhubKey: os.Getenv("FINNHUB_API_KEY"),
		eodhKey:    os.Getenv("EODHD_API_KEY"),
		alphaKey:   os.Getenv("ALPHA_VANTAGE_API_KEY"),
	}
}

// GetGeneralMarketNews fetches general market news from multiple sources concurrently.
func (nc *NewsClient) GetGeneralMarketNews(ctx context.Context, category string, limit int) ([]NewsArticle, error) {
	var (
		mu      sync.Mutex
		allNews []NewsArticle
		wg      sync.WaitGroup
	)

	// Fetch from Finnhub
	if nc.finnhubKey != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			finnhubNews, err := nc.fetchFinnhubGeneralNews(ctx, category, limit)
			if err == nil {
				mu.Lock()
				allNews = append(allNews, finnhubNews...)
				mu.Unlock()
			}
		}()
	}

	// Fetch from Alpha Vantage
	if nc.alphaKey != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			alphaNews, err := nc.fetchAlphaVantageNews(ctx, "", limit)
			if err == nil {
				mu.Lock()
				allNews = append(allNews, alphaNews...)
				mu.Unlock()
			}
		}()
	}

	wg.Wait()

	if ctx.Err() != nil {
		return nil, fmt.Errorf("request cancelled: %w", ctx.Err())
	}

	if len(allNews) == 0 {
		return nil, fmt.Errorf("no news sources available or all sources failed")
	}

	// Limit results
	if len(allNews) > limit {
		allNews = allNews[:limit]
	}

	return allNews, nil
}

// GetNewsBySymbol fetches news for a specific stock symbol from multiple sources concurrently.
func (nc *NewsClient) GetNewsBySymbol(ctx context.Context, symbol string, limit int) ([]NewsArticle, error) {
	var (
		mu      sync.Mutex
		allNews []NewsArticle
		wg      sync.WaitGroup
	)

	// Fetch from all available sources concurrently
	if nc.finnhubKey != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			finnhubNews, err := nc.fetchFinnhubCompanyNews(ctx, symbol, limit)
			if err == nil {
				mu.Lock()
				allNews = append(allNews, finnhubNews...)
				mu.Unlock()
			}
		}()
	}

	if nc.eodhKey != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			eodhNews, err := nc.fetchEODHDNews(ctx, symbol, limit)
			if err == nil {
				mu.Lock()
				allNews = append(allNews, eodhNews...)
				mu.Unlock()
			}
		}()
	}

	if nc.alphaKey != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			alphaNews, err := nc.fetchAlphaVantageNews(ctx, symbol, limit)
			if err == nil {
				mu.Lock()
				allNews = append(allNews, alphaNews...)
				mu.Unlock()
			}
		}()
	}

	wg.Wait()

	if ctx.Err() != nil {
		return nil, fmt.Errorf("request cancelled: %w", ctx.Err())
	}

	if len(allNews) == 0 {
		return nil, fmt.Errorf("no news found for symbol %s from any source", symbol)
	}

	if len(allNews) > limit {
		allNews = allNews[:limit]
	}

	return allNews, nil
}

// GetNewsByKeyword searches for news by keyword across sources concurrently.
func (nc *NewsClient) GetNewsByKeyword(ctx context.Context, keyword string, limit int) ([]NewsArticle, error) {
	var (
		mu      sync.Mutex
		allNews []NewsArticle
		wg      sync.WaitGroup
	)

	// Alpha Vantage supports topic search
	if nc.alphaKey != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			alphaNews, err := nc.fetchAlphaVantageNewsByTopic(ctx, keyword, limit)
			if err == nil {
				mu.Lock()
				allNews = append(allNews, alphaNews...)
				mu.Unlock()
			}
		}()
	}

	// Finnhub - filter general news by keyword
	if nc.finnhubKey != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			finnhubNews, err := nc.fetchFinnhubGeneralNews(ctx, "general", limit*2)
			if err == nil {
				var filtered []NewsArticle
				for _, article := range finnhubNews {
					if strings.Contains(strings.ToLower(article.Title), strings.ToLower(keyword)) ||
						strings.Contains(strings.ToLower(article.Description), strings.ToLower(keyword)) {
						filtered = append(filtered, article)
					}
				}
				mu.Lock()
				allNews = append(allNews, filtered...)
				mu.Unlock()
			}
		}()
	}

	wg.Wait()

	if ctx.Err() != nil {
		return nil, fmt.Errorf("request cancelled: %w", ctx.Err())
	}

	if len(allNews) == 0 {
		return nil, fmt.Errorf("no news found for keyword: %s", keyword)
	}

	if len(allNews) > limit {
		allNews = allNews[:limit]
	}

	return allNews, nil
}

// fetchFinnhubGeneralNews fetches general market news from Finnhub
func (nc *NewsClient) fetchFinnhubGeneralNews(ctx context.Context, category string, limit int) ([]NewsArticle, error) {
	if nc.finnhubKey == "" {
		return nil, fmt.Errorf("Finnhub API key not configured")
	}

	if category == "" {
		category = "general"
	}

	reqURL := fmt.Sprintf("https://finnhub.io/api/v1/news?category=%s&token=%s", category, nc.finnhubKey)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch Finnhub news: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("Finnhub API error: %s - %s", resp.Status, string(body))
	}

	var finnhubResp []struct {
		Category string `json:"category"`
		Datetime int64  `json:"datetime"`
		Headline string `json:"headline"`
		ID       int64  `json:"id"`
		Image    string `json:"image"`
		Related  string `json:"related"`
		Source   string `json:"source"`
		Summary  string `json:"summary"`
		URL      string `json:"url"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&finnhubResp); err != nil {
		return nil, fmt.Errorf("failed to decode Finnhub response: %v", err)
	}

	var articles []NewsArticle
	for i, item := range finnhubResp {
		if i >= limit {
			break
		}
		articles = append(articles, NewsArticle{
			Title:       item.Headline,
			Description: item.Summary,
			Content:     item.Summary,
			Source:      fmt.Sprintf("Finnhub (%s)", item.Source),
			URL:         item.URL,
			PublishedAt: time.Unix(item.Datetime, 0),
			ImageURL:    item.Image,
			Category:    item.Category,
		})
	}

	return articles, nil
}

// fetchFinnhubCompanyNews fetches company-specific news from Finnhub
func (nc *NewsClient) fetchFinnhubCompanyNews(ctx context.Context, symbol string, limit int) ([]NewsArticle, error) {
	if nc.finnhubKey == "" {
		return nil, fmt.Errorf("Finnhub API key not configured")
	}

	// Get news from past 7 days
	to := time.Now().Format("2006-01-02")
	from := time.Now().AddDate(0, 0, -7).Format("2006-01-02")

	reqURL := fmt.Sprintf("https://finnhub.io/api/v1/company-news?symbol=%s&from=%s&to=%s&token=%s",
		symbol, from, to, nc.finnhubKey)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch Finnhub company news: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("Finnhub API error: %s - %s", resp.Status, string(body))
	}

	var finnhubResp []struct {
		Category string `json:"category"`
		Datetime int64  `json:"datetime"`
		Headline string `json:"headline"`
		ID       int64  `json:"id"`
		Image    string `json:"image"`
		Related  string `json:"related"`
		Source   string `json:"source"`
		Summary  string `json:"summary"`
		URL      string `json:"url"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&finnhubResp); err != nil {
		return nil, fmt.Errorf("failed to decode Finnhub response: %v", err)
	}

	var articles []NewsArticle
	for i, item := range finnhubResp {
		if i >= limit {
			break
		}
		articles = append(articles, NewsArticle{
			Title:       item.Headline,
			Description: item.Summary,
			Content:     item.Summary,
			Source:      fmt.Sprintf("Finnhub (%s)", item.Source),
			URL:         item.URL,
			PublishedAt: time.Unix(item.Datetime, 0),
			ImageURL:    item.Image,
			Category:    item.Category,
		})
	}

	return articles, nil
}

// fetchEODHDNews fetches news from EODHD (existing source)
func (nc *NewsClient) fetchEODHDNews(ctx context.Context, symbol string, limit int) ([]NewsArticle, error) {
	if nc.eodhKey == "" {
		return nil, fmt.Errorf("EODHD API key not configured")
	}

	reqURL := fmt.Sprintf("https://eodhd.com/api/news?s=%s&limit=%d&api_token=%s&fmt=json",
		symbol, limit, nc.eodhKey)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch EODHD news: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("EODHD API error: %s - %s", resp.Status, string(body))
	}

	var eodhResp []struct {
		Date    string `json:"date"`
		Title   string `json:"title"`
		Content string `json:"content"`
		Link    string `json:"link"`
		Symbols string `json:"symbols"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&eodhResp); err != nil {
		return nil, fmt.Errorf("failed to decode EODHD response: %v", err)
	}

	var articles []NewsArticle
	for _, item := range eodhResp {
		publishedAt, _ := time.Parse("2006-01-02 15:04:05", item.Date)
		articles = append(articles, NewsArticle{
			Title:       item.Title,
			Description: item.Content[:min(200, len(item.Content))], // First 200 chars as description
			Content:     item.Content,
			Source:      "EODHD",
			URL:         item.Link,
			PublishedAt: publishedAt,
		})
	}

	return articles, nil
}

// fetchAlphaVantageNews fetches news from Alpha Vantage
func (nc *NewsClient) fetchAlphaVantageNews(ctx context.Context, symbol string, limit int) ([]NewsArticle, error) {
	if nc.alphaKey == "" {
		return nil, fmt.Errorf("Alpha Vantage API key not configured")
	}

	// Alpha Vantage News & Sentiment API
	baseURL := "https://www.alphavantage.co/query"
	params := url.Values{}
	params.Add("function", "NEWS_SENTIMENT")
	params.Add("apikey", nc.alphaKey)
	params.Add("limit", fmt.Sprintf("%d", min(limit, 50))) // Max 50 per request

	if symbol != "" {
		params.Add("tickers", symbol)
	}

	reqURL := fmt.Sprintf("%s?%s", baseURL, params.Encode())

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch Alpha Vantage news: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("Alpha Vantage API error: %s - %s", resp.Status, string(body))
	}

	var alphaResp struct {
		Items string `json:"items"`
		Feed  []struct {
			Title                string   `json:"title"`
			URL                  string   `json:"url"`
			TimePublished        string   `json:"time_published"`
			Authors              []string `json:"authors"`
			Summary              string   `json:"summary"`
			BannerImage          string   `json:"banner_image"`
			Source               string   `json:"source"`
			CategoryWithinSource string   `json:"category_within_source"`
		} `json:"feed"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&alphaResp); err != nil {
		return nil, fmt.Errorf("failed to decode Alpha Vantage response: %v", err)
	}

	var articles []NewsArticle
	for i, item := range alphaResp.Feed {
		if i >= limit {
			break
		}

		// Parse time: format is "20241231T120000"
		publishedAt, _ := time.Parse("20060102T150405", item.TimePublished)

		author := ""
		if len(item.Authors) > 0 {
			author = item.Authors[0]
		}

		articles = append(articles, NewsArticle{
			Title:       item.Title,
			Description: item.Summary,
			Content:     item.Summary,
			Source:      fmt.Sprintf("Alpha Vantage (%s)", item.Source),
			URL:         item.URL,
			PublishedAt: publishedAt,
			Author:      author,
			ImageURL:    item.BannerImage,
			Category:    item.CategoryWithinSource,
		})
	}

	return articles, nil
}

// fetchAlphaVantageNewsByTopic fetches news filtered by topic/keyword
func (nc *NewsClient) fetchAlphaVantageNewsByTopic(ctx context.Context, topic string, limit int) ([]NewsArticle, error) {
	if nc.alphaKey == "" {
		return nil, fmt.Errorf("Alpha Vantage API key not configured")
	}

	// Alpha Vantage supports topic filtering
	baseURL := "https://www.alphavantage.co/query"
	params := url.Values{}
	params.Add("function", "NEWS_SENTIMENT")
	params.Add("apikey", nc.alphaKey)
	params.Add("topics", topic)
	params.Add("limit", fmt.Sprintf("%d", min(limit, 50)))

	reqURL := fmt.Sprintf("%s?%s", baseURL, params.Encode())

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %v", err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch Alpha Vantage news: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("Alpha Vantage API error: %s - %s", resp.Status, string(body))
	}

	var alphaResp struct {
		Items string `json:"items"`
		Feed  []struct {
			Title                string   `json:"title"`
			URL                  string   `json:"url"`
			TimePublished        string   `json:"time_published"`
			Authors              []string `json:"authors"`
			Summary              string   `json:"summary"`
			BannerImage          string   `json:"banner_image"`
			Source               string   `json:"source"`
			CategoryWithinSource string   `json:"category_within_source"`
		} `json:"feed"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&alphaResp); err != nil {
		return nil, fmt.Errorf("failed to decode Alpha Vantage response: %v", err)
	}

	var articles []NewsArticle
	for i, item := range alphaResp.Feed {
		if i >= limit {
			break
		}

		publishedAt, _ := time.Parse("20060102T150405", item.TimePublished)

		author := ""
		if len(item.Authors) > 0 {
			author = item.Authors[0]
		}

		articles = append(articles, NewsArticle{
			Title:       item.Title,
			Description: item.Summary,
			Content:     item.Summary,
			Source:      fmt.Sprintf("Alpha Vantage (%s)", item.Source),
			URL:         item.URL,
			PublishedAt: publishedAt,
			Author:      author,
			ImageURL:    item.BannerImage,
			Category:    item.CategoryWithinSource,
		})
	}

	return articles, nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
