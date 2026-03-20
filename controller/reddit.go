package controller

import (
	"net/http"
	"strconv"

	"github.com/MadebyDaris/dogonomics/internal/RedditScraper"
	"github.com/gin-gonic/gin"
)

// GetRedditFinancialNews retrieves aggregated financial news from Reddit
// @Summary Get aggregated financial news from Reddit
// @Description Fetches posts from multiple financial subreddits (finance, investing, stocks, etc.)
// @Tags social
// @Accept json
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Failure 500 {object} map[string]string
// @Router /social/reddit/financial [get]
func GetRedditFinancialNews(c *gin.Context) {
	scraper := RedditScraper.NewScraper()
	
	// Default limit per subreddit
	limit := 10
	limitStr := c.Query("limit")
	if limitStr != "" {
		if val, err := strconv.Atoi(limitStr); err == nil && val > 0 && val <= 100 {
			limit = val
		}
	}

	posts, errs := scraper.GetFinancialNews(limit)
	
	errorMsgs := make([]string, 0)
	for _, err := range errs {
		errorMsgs = append(errorMsgs, err.Error())
	}

	c.JSON(http.StatusOK, gin.H{
		"posts": posts,
		"errors": errorMsgs,
	})
}

// GetSubredditPosts retrieves posts from a specific subreddit
// @Summary Get posts from a specific subreddit
// @Description Fetches hot posts from the specified subreddit
// @Tags social
// @Accept json
// @Produce json
// @Param subreddit path string true "Subreddit name"
// @Param limit query int false "Number of posts to fetch (default 10, max 100)"
// @Success 200 {object} []RedditScraper.RedditPost
// @Failure 400 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /social/reddit/{subreddit} [get]
func GetSubredditPosts(c *gin.Context) {
	subreddit := c.Param("subreddit")
	if subreddit == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Subreddit is required"})
		return
	}

	limit := 10
	limitStr := c.Query("limit")
	if limitStr != "" {
		if val, err := strconv.Atoi(limitStr); err == nil && val > 0 && val <= 100 {
			limit = val
		}
	}

	scraper := RedditScraper.NewScraper()
	posts, err := scraper.ScrapeSubreddit(subreddit, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, posts)
}
