package mcpgateway

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/CommoditiesClient"
	"github.com/MadebyDaris/dogonomics/internal/DogonomicsFetching"
	"github.com/MadebyDaris/dogonomics/internal/NewsClient"
	"github.com/MadebyDaris/dogonomics/internal/PolygonClient"
	"github.com/MadebyDaris/dogonomics/internal/TreasuryClient"
	"github.com/MadebyDaris/dogonomics/internal/cache"
	"github.com/MadebyDaris/dogonomics/internal/database"
	"github.com/MadebyDaris/dogonomics/sentAnalysis"
	"github.com/mark3labs/mcp-go/mcp"
	"github.com/mark3labs/mcp-go/server"
	"github.com/redis/go-redis/v9"
	"github.com/segmentio/kafka-go"
)

const (
	defaultMCPAddr    = ":8081"
	defaultMCPBaseURL = "http://localhost:8081"
)

type Server struct {
	mcp     *server.MCPServer
	sse     *server.SSEServer // receive automatic events
	addr    string
	baseURL string
	deps    Dependencies
}

type Dependencies struct {
	Finnhub     *DogonomicsFetching.Client
	News        *NewsClient.NewsClient
	Redis       *redis.Client
	Kafka       *kafka.Writer
	Treasury    *TreasuryClient.Client
	Commodities *CommoditiesClient.Client
}

func EnabledFromEnv() bool {
	value := strings.TrimSpace(strings.ToLower(os.Getenv("MCP_ENABLED")))
	return value != "false" && value != "0" && value != "off"
}

func New(deps Dependencies) (*Server, error) {
	if deps.Finnhub == nil {
		return nil, errors.New("mcpgateway requires a Finnhub client")
	}
	if deps.News == nil {
		deps.News = NewsClient.NewNewsClient()
	}
	if deps.Redis == nil {
		deps.Redis = cache.Client
	}
	if deps.Treasury == nil {
		deps.Treasury = TreasuryClient.NewClient()
	}
	if deps.Commodities == nil {
		deps.Commodities = CommoditiesClient.NewClient()
	}

	addr := envOrDefault("MCP_ADDR", defaultMCPAddr)
	baseURL := envOrDefault("MCP_BASE_URL", defaultMCPBaseURL)

	mcpServer := server.NewMCPServer(
		"dogonomics-mcp",
		"0.1.0",
		server.WithResourceCapabilities(true, true),
		server.WithPromptCapabilities(true),
		server.WithToolCapabilities(true),
		server.WithInstructions("Dogonomics MCP exposes read-only financial context, finance-specific prompts, and synchronous market analysis tools backed by the Dogonomics Go backend."),
	)

	result := &Server{
		mcp:     mcpServer,
		addr:    addr,
		baseURL: baseURL,
		deps:    deps,
	}

	result.registerResources()
	result.registerTools()
	result.registerPrompts()

	result.sse = server.NewSSEServer(
		mcpServer,
		server.WithStaticBasePath("/mcp"),
		server.WithBaseURL(baseURL),
		server.WithKeepAliveInterval(30*time.Second),
		server.WithSSEContextFunc(result.enrichContext),
	)

	return result, nil
}

func (s *Server) Start() {
	go func() {
		log.Printf("MCP SSE server listening on %s/mcp/sse via %s", s.baseURL, s.addr)
		if err := s.sse.Start(s.addr); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Printf("WARNING: MCP server stopped with error: %v", err)
		}
	}()
}

func (s *Server) Shutdown(ctx context.Context) error {
	if s == nil || s.sse == nil {
		return nil
	}
	return s.sse.Shutdown(ctx)
}

func (s *Server) enrichContext(ctx context.Context, r *http.Request) context.Context {
	ctx = context.WithValue(ctx, contextKey("authorization"), r.Header.Get("Authorization"))
	ctx = context.WithValue(ctx, contextKey("request_id"), r.Header.Get("X-Request-ID"))
	ctx = context.WithValue(ctx, contextKey("user_agent"), r.Header.Get("User-Agent"))
	return ctx
}

func (s *Server) registerResources() {
	s.mcp.AddResource(
		mcp.NewResource(
			"dogonomics://health",
			"Dogonomics Health",
			mcp.WithResourceDescription("Current Dogonomics backend health and dependency availability."),
			mcp.WithMIMEType("application/json"),
		),
		s.handleHealthResource,
	)

	s.mcp.AddResourceTemplate(
		mcp.NewResourceTemplate(
			"dogonomics://market/ohlcv/{ticker}",
			"Historical OHLCV",
			mcp.WithTemplateDescription("Historical OHLCV data for a ticker symbol."),
			mcp.WithTemplateMIMEType("application/json"),
		),
		s.handleOHLCVResource,
	)

	s.mcp.AddResourceTemplate(
		mcp.NewResourceTemplate(
			"dogonomics://sentiment/trend/{ticker}",
			"Sentiment Trend",
			mcp.WithTemplateDescription("Stored sentiment trend data for a symbol from the database."),
			mcp.WithTemplateMIMEType("application/json"),
		),
		s.handleSentimentTrendResource,
	)
}

func (s *Server) registerTools() {
	s.mcp.AddTool(
		mcp.NewTool(
			"get_quote",
			mcp.WithDescription("Fetch the latest quote for a stock ticker."),
			mcp.WithString("ticker", mcp.Required(), mcp.Description("Stock ticker, for example AAPL")),
		),
		s.handleGetQuoteTool,
	)

	s.mcp.AddTool(
		mcp.NewTool(
			"fetch_latest_news",
			mcp.WithDescription("Fetch recent news articles for a ticker from the multi-source news layer."),
			mcp.WithString("ticker", mcp.Required(), mcp.Description("Ticker symbol, for example NVDA")),
			mcp.WithNumber("limit", mcp.Description("Maximum articles to return"), mcp.DefaultNumber(5)),
		),
		s.handleFetchLatestNewsTool,
	)

	s.mcp.AddTool(
		mcp.NewTool(
			"analyze_live_sentiment",
			mcp.WithDescription("Fetch recent news and run FinBERT sentiment analysis for a ticker."),
			mcp.WithString("ticker", mcp.Required(), mcp.Description("Ticker symbol, for example TSLA")),
			mcp.WithNumber("limit", mcp.Description("Maximum articles to analyze"), mcp.DefaultNumber(5)),
		),
		s.handleAnalyzeLiveSentimentTool,
	)

	s.mcp.AddTool(
		mcp.NewTool(
			"get_company_profile",
			mcp.WithDescription("Fetch the latest company profile for a ticker."),
			mcp.WithString("ticker", mcp.Required(), mcp.Description("Ticker symbol, for example MSFT")),
		),
		s.handleGetCompanyProfileTool,
	)

	s.mcp.AddTool(
		mcp.NewTool(
			"get_treasury_yield_curve",
			mcp.WithDescription("Fetch the latest US Treasury yield curve rates."),
		),
		s.handleGetTreasuryYieldCurveTool,
	)

	s.mcp.AddTool(
		mcp.NewTool(
			"get_commodity_oil",
			mcp.WithDescription("Fetch the latest oil prices (WTI or Brent)."),
			mcp.WithString("type", mcp.Description("Oil type: 'wti' (default) or 'brent'")),
		),
		s.handleGetCommodityOilTool,
	)

	s.mcp.AddTool(
		mcp.NewTool(
			"get_crypto_candle",
			mcp.WithDescription("Fetch crypto candle data (OHLCV) for a symbol."),
			mcp.WithString("symbol", mcp.Required(), mcp.Description("Crypto symbol, e.g. BINANCE:BTCUSDT")),
			mcp.WithString("resolution", mcp.Description("Resolution: '1', '5', '15', '30', '60', 'D', 'W', 'M'")),
			mcp.WithNumber("days", mcp.Description("Number of days to fetch (default 30)"), mcp.DefaultNumber(30)),
		),
		s.handleGetCryptoCandleTool,
	)

	s.mcp.AddTool(
		mcp.NewTool(
			"get_forex_rates",
			mcp.WithDescription("Fetch forex rates for a base currency."),
			mcp.WithString("base", mcp.Description("Base currency, e.g. USD (default)")),
		),
		s.handleGetForexRatesTool,
	)
}

func (s *Server) registerPrompts() {
	s.mcp.AddPrompt(
		mcp.NewPrompt(
			"explain_sentiment_shift",
			mcp.WithPromptDescription("Explain why sentiment for a ticker may have shifted based on live sentiment data and recent news."),
			mcp.WithArgument("ticker", mcp.ArgumentDescription("Ticker symbol to analyze"), mcp.RequiredArgument()),
		),
		s.handleExplainSentimentShiftPrompt,
	)

	s.mcp.AddPrompt(
		mcp.NewPrompt(
			"summarize_symbol_state",
			mcp.WithPromptDescription("Summarize the current state of a ticker using quote, profile, and recent news context."),
			mcp.WithArgument("ticker", mcp.ArgumentDescription("Ticker symbol to summarize"), mcp.RequiredArgument()),
		),
		s.handleSummarizeSymbolStatePrompt,
	)
}

func (s *Server) handleHealthResource(ctx context.Context, req mcp.ReadResourceRequest) ([]mcp.ResourceContents, error) {
	payload := map[string]any{
		"service":   "dogonomics-mcp",
		"status":    "healthy",
		"timestamp": time.Now().UTC(),
		"dependencies": map[string]any{
			"database": database.DB != nil,
			"redis":    s.deps.Redis != nil,
			"finnhub":  s.deps.Finnhub != nil && s.deps.Finnhub.APIKey != "",
		},
	}
	return marshalResource(req.Params.URI, payload)
}

func (s *Server) handleOHLCVResource(ctx context.Context, req mcp.ReadResourceRequest) ([]mcp.ResourceContents, error) {
	ticker := firstTemplateValue(req.Params.Arguments, "ticker")
	if ticker == "" {
		return nil, fmt.Errorf("ticker is required")
	}

	days := 100
	if parsed, err := strconv.Atoi(req.Header.Get("X-Dogonomics-Days")); err == nil && parsed > 0 && parsed <= 365 {
		days = parsed
	}

	data, err := PolygonClient.RequestHistoricalData(ctx, strings.ToUpper(ticker), days)
	if err != nil {
		return nil, err
	}

	payload := map[string]any{
		"ticker": strings.ToUpper(ticker),
		"days":   days,
		"count":  len(data),
		"data":   data,
	}
	return marshalResource(req.Params.URI, payload)
}

func (s *Server) handleSentimentTrendResource(ctx context.Context, req mcp.ReadResourceRequest) ([]mcp.ResourceContents, error) {
	ticker := firstTemplateValue(req.Params.Arguments, "ticker")
	if ticker == "" {
		return nil, fmt.Errorf("ticker is required")
	}

	days := 14
	if parsed, err := strconv.Atoi(req.Header.Get("X-Dogonomics-Days")); err == nil && parsed > 0 && parsed <= 90 {
		days = parsed
	}

	trend, err := database.GetSymbolSentimentTrend(ctx, strings.ToUpper(ticker), days)
	if err != nil {
		return nil, err
	}

	payload := map[string]any{
		"ticker": strings.ToUpper(ticker),
		"days":   days,
		"trend":  trend,
		"count":  len(trend),
	}
	return marshalResource(req.Params.URI, payload)
}

func (s *Server) handleGetQuoteTool(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	ticker, err := req.RequireString("ticker")
	if err != nil {
		return nil, err
	}

	quote, err := s.deps.Finnhub.GetQuote(ctx, strings.ToUpper(ticker))
	if err != nil {
		return nil, err
	}

	return jsonToolResult(map[string]any{
		"ticker": strings.ToUpper(ticker),
		"quote":  quote,
	})
}

func (s *Server) handleGetCompanyProfileTool(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	ticker, err := req.RequireString("ticker")
	if err != nil {
		return nil, err
	}

	profile, err := s.deps.Finnhub.GetCompanyProfile(ctx, strings.ToUpper(ticker))
	if err != nil {
		return nil, err
	}

	return jsonToolResult(map[string]any{
		"ticker":  strings.ToUpper(ticker),
		"profile": profile,
	})
}

func (s *Server) handleFetchLatestNewsTool(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	ticker, err := req.RequireString("ticker")
	if err != nil {
		return nil, err
	}

	limit := maxInt(1, minInt(20, int(req.GetFloat("limit", 5))))
	articles, err := s.deps.News.GetNewsBySymbol(ctx, strings.ToUpper(ticker), limit)
	if err != nil {
		return nil, err
	}

	return jsonToolResult(map[string]any{
		"ticker":   strings.ToUpper(ticker),
		"count":    len(articles),
		"articles": articles,
	})
}

func (s *Server) handleAnalyzeLiveSentimentTool(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	ticker, err := req.RequireString("ticker")
	if err != nil {
		return nil, err
	}

	limit := maxInt(1, minInt(10, int(req.GetFloat("limit", 5))))
	articles, err := s.deps.News.GetNewsBySymbol(ctx, strings.ToUpper(ticker), limit)
	if err != nil {
		articles, err = s.deps.News.GetNewsByKeyword(ctx, strings.ToUpper(ticker), limit)
		if err != nil {
			return nil, err
		}
	}

	newsItems := make([]sentAnalysis.NewsItem, 0, len(articles))
	for _, article := range articles {
		newsItems = append(newsItems, sentAnalysis.NewsItem{
			Title:   article.Title,
			Content: article.Description,
			Link:    article.URL,
		})
	}

	aggregate := sentAnalysis.FetchStockSentiment(ctx, newsItems)
	return jsonToolResult(map[string]any{
		"ticker":     strings.ToUpper(ticker),
		"aggregate":  aggregate,
		"news_count": len(newsItems),
	})
}

func (s *Server) handleExplainSentimentShiftPrompt(ctx context.Context, req mcp.GetPromptRequest) (*mcp.GetPromptResult, error) {
	ticker := strings.ToUpper(strings.TrimSpace(req.Params.Arguments["ticker"]))
	if ticker == "" {
		return nil, fmt.Errorf("ticker is required")
	}

	return mcp.NewGetPromptResult(
		"Explain sentiment shift for a symbol",
		[]mcp.PromptMessage{
			mcp.NewPromptMessage(
				mcp.RoleUser,
				mcp.NewTextContent(fmt.Sprintf("Analyze sentiment divergence for %s. Use resource dogonomics://sentiment/trend/%s for stored trend context and tool analyze_live_sentiment with ticker=%s for live FinBERT-backed context. Explain what changed, what may be driving the shift, and what confidence caveats apply.", ticker, ticker, ticker)),
			),
		},
	), nil
}

func (s *Server) handleSummarizeSymbolStatePrompt(ctx context.Context, req mcp.GetPromptRequest) (*mcp.GetPromptResult, error) {
	ticker := strings.ToUpper(strings.TrimSpace(req.Params.Arguments["ticker"]))
	if ticker == "" {
		return nil, fmt.Errorf("ticker is required")
	}

	return mcp.NewGetPromptResult(
		"Summarize current symbol state",
		[]mcp.PromptMessage{
			mcp.NewPromptMessage(
				mcp.RoleUser,
				mcp.NewTextContent(fmt.Sprintf("Summarize the current state of %s for an investor. Use tool get_quote for the latest market snapshot, get_company_profile for business context, fetch_latest_news for catalysts, and resource dogonomics://market/ohlcv/%s for historical price context. Return a concise state summary, major risks, and near-term watch items.", ticker, ticker)),
			),
		},
	), nil
}

func (s *Server) handleGetTreasuryYieldCurveTool(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	data, err := s.deps.Treasury.GetLatestYieldCurve(ctx)
	if err != nil {
		return nil, err
	}
	return jsonToolResult(data)
}

func (s *Server) handleGetCommodityOilTool(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	oilType := ""
	if args, ok := req.Params.Arguments.(map[string]any); ok {
		oilType, _ = args["type"].(string)
	}
	var data *CommoditiesClient.CommodityData
	var err error

	if oilType == "brent" {
		data, err = s.deps.Commodities.GetCrudeOilBrent(ctx)
	} else {
		data, err = s.deps.Commodities.GetCrudeOilWTI(ctx)
	}

	if err != nil {
		return nil, err
	}
	return jsonToolResult(data)
}

func (s *Server) handleGetCryptoCandleTool(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	symbol, err := req.RequireString("symbol")
	if err != nil {
		return nil, err
	}
	resolution := "D"
	if args, ok := req.Params.Arguments.(map[string]any); ok {
		if res, ok := args["resolution"].(string); ok && res != "" {
			resolution = res
		}
	}

	days := 30
	if args, ok := req.Params.Arguments.(map[string]any); ok {
		if d, ok := args["days"].(float64); ok {
			days = int(d)
		}
	}

	now := time.Now().Unix()
	from := now - int64(days*86400)

	candle, err := s.deps.Finnhub.GetCryptoCandle(ctx, symbol, resolution, from, now)
	if err != nil {
		return nil, err
	}
	return jsonToolResult(candle)
}

func (s *Server) handleGetForexRatesTool(ctx context.Context, req mcp.CallToolRequest) (*mcp.CallToolResult, error) {
	base := "USD"
	if args, ok := req.Params.Arguments.(map[string]any); ok {
		if b, ok := args["base"].(string); ok && b != "" {
			base = b
		}
	}

	rates, err := s.deps.Finnhub.GetForexRates(ctx, base)
	if err != nil {
		return nil, err
	}
	return jsonToolResult(rates)
}

type contextKey string

func marshalResource(uri string, payload any) ([]mcp.ResourceContents, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	return []mcp.ResourceContents{
		mcp.TextResourceContents{
			URI:      uri,
			MIMEType: "application/json",
			Text:     string(body),
		},
	}, nil
}

func jsonToolResult(payload any) (*mcp.CallToolResult, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	return mcp.NewToolResultText(string(body)), nil
}

func firstTemplateValue(arguments map[string]any, key string) string {
	value, ok := arguments[key]
	if !ok {
		return ""
	}
	items, ok := value.([]string)
	if !ok || len(items) == 0 {
		return ""
	}
	return items[0]
}

func envOrDefault(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}
