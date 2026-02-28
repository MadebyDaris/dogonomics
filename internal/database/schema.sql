-- Dogonomics Database Schema
-- TimescaleDB (PostgreSQL 14+ with TimescaleDB extension)

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- ============================================================
-- Hypertable: API Request Logs
-- Partitioned by timestamp for efficient time-range queries
-- ============================================================
CREATE TABLE IF NOT EXISTS api_requests (
    id UUID NOT NULL DEFAULT uuid_generate_v4(),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    symbol VARCHAR(20),
    status_code INT NOT NULL,
    response_time_ms INT NOT NULL,
    user_agent TEXT,
    ip_address INET,
    error_message TEXT
);

SELECT create_hypertable('api_requests', 'timestamp', if_not_exists => TRUE);

CREATE INDEX idx_api_requests_symbol ON api_requests(symbol, timestamp DESC) WHERE symbol IS NOT NULL;
CREATE INDEX idx_api_requests_endpoint ON api_requests(endpoint, timestamp DESC);

-- Automatic retention: drop chunks older than 30 days
SELECT add_retention_policy('api_requests', INTERVAL '30 days', if_not_exists => TRUE);

-- ============================================================
-- Hypertable: Stock Quotes
-- ============================================================
CREATE TABLE IF NOT EXISTS stock_quotes (
    id UUID NOT NULL DEFAULT uuid_generate_v4(),
    symbol VARCHAR(20) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    current_price DECIMAL(15, 4),
    open_price DECIMAL(15, 4),
    high_price DECIMAL(15, 4),
    low_price DECIMAL(15, 4),
    previous_close DECIMAL(15, 4),
    change DECIMAL(15, 4),
    percent_change DECIMAL(8, 4),
    volume BIGINT,
    source VARCHAR(50) NOT NULL DEFAULT 'finnhub',
    raw_data JSONB
);

SELECT create_hypertable('stock_quotes', 'timestamp', if_not_exists => TRUE);

CREATE INDEX idx_stock_quotes_symbol_timestamp ON stock_quotes(symbol, timestamp DESC);

-- ============================================================
-- Regular table: Company Profiles (lookup, not time-series)
-- ============================================================
CREATE TABLE IF NOT EXISTS company_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(255),
    country VARCHAR(100),
    currency VARCHAR(10),
    exchange VARCHAR(50),
    industry VARCHAR(100),
    sector VARCHAR(100),
    market_cap BIGINT,
    description TEXT,
    logo_url TEXT,
    website_url TEXT,
    last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    raw_data JSONB
);

CREATE INDEX idx_company_profiles_symbol ON company_profiles(symbol);
CREATE INDEX idx_company_profiles_sector ON company_profiles(sector) WHERE sector IS NOT NULL;

-- ============================================================
-- Hypertable: News Items
-- Partitioned by fetched_at
-- ============================================================
CREATE TABLE IF NOT EXISTS news_items (
    id UUID NOT NULL DEFAULT uuid_generate_v4(),
    symbol VARCHAR(20) NOT NULL,
    title TEXT NOT NULL,
    content TEXT,
    published_date TIMESTAMPTZ,
    source VARCHAR(100),
    link TEXT,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    tags TEXT[],
    UNIQUE(symbol, link, fetched_at)
);

SELECT create_hypertable('news_items', 'fetched_at', if_not_exists => TRUE);

CREATE INDEX idx_news_items_symbol_date ON news_items(symbol, published_date DESC);

-- ============================================================
-- Hypertable: Sentiment Analysis Results
-- Partitioned by analyzed_at; no FK to news_items (hypertable limitation)
-- ============================================================
CREATE TABLE IF NOT EXISTS sentiment_analysis (
    id UUID NOT NULL DEFAULT uuid_generate_v4(),
    news_item_id UUID,
    symbol VARCHAR(20) NOT NULL,
    analyzed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- BERT Sentiment
    bert_label VARCHAR(20),
    bert_confidence DECIMAL(5, 4),
    bert_score DECIMAL(5, 4),
    
    -- Basic Sentiment (if available)
    polarity DECIMAL(5, 4),
    positive_score DECIMAL(5, 4),
    neutral_score DECIMAL(5, 4),
    negative_score DECIMAL(5, 4),
    
    -- Model info
    model_version VARCHAR(50),
    inference_time_ms INT
);

SELECT create_hypertable('sentiment_analysis', 'analyzed_at', if_not_exists => TRUE);

CREATE INDEX idx_sentiment_symbol_date ON sentiment_analysis(symbol, analyzed_at DESC);
CREATE INDEX idx_sentiment_news_item ON sentiment_analysis(news_item_id, analyzed_at DESC);
CREATE INDEX idx_sentiment_bert_label ON sentiment_analysis(bert_label, analyzed_at DESC) WHERE bert_label IS NOT NULL;

-- ============================================================
-- Regular table: Aggregate Sentiment (UPSERT pattern, not time-series)
-- ============================================================
CREATE TABLE IF NOT EXISTS aggregate_sentiment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    symbol VARCHAR(20) NOT NULL,
    analyzed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    period_start TIMESTAMPTZ NOT NULL,
    period_end TIMESTAMPTZ NOT NULL,
    
    overall_sentiment DECIMAL(5, 4),
    confidence DECIMAL(5, 4),
    news_count INT NOT NULL,
    positive_ratio DECIMAL(5, 4),
    neutral_ratio DECIMAL(5, 4),
    negative_ratio DECIMAL(5, 4),
    recommendation VARCHAR(20),
    
    UNIQUE(symbol, period_start, period_end)
);

CREATE INDEX idx_aggregate_sentiment_symbol_date ON aggregate_sentiment(symbol, analyzed_at DESC);
CREATE INDEX idx_aggregate_sentiment_period ON aggregate_sentiment(period_start, period_end);

-- ============================================================
-- Hypertable: Historical Chart Data
-- Partitioned by fetched_at
-- ============================================================
CREATE TABLE IF NOT EXISTS chart_data (
    id UUID NOT NULL DEFAULT uuid_generate_v4(),
    symbol VARCHAR(20) NOT NULL,
    date DATE NOT NULL,
    open_price DECIMAL(15, 4),
    high_price DECIMAL(15, 4),
    low_price DECIMAL(15, 4),
    close_price DECIMAL(15, 4),
    volume BIGINT,
    adjusted_close DECIMAL(15, 4),
    source VARCHAR(50) NOT NULL,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(symbol, date, source, fetched_at)
);

SELECT create_hypertable('chart_data', 'fetched_at', if_not_exists => TRUE);

CREATE INDEX idx_chart_data_symbol_date ON chart_data(symbol, date DESC);

-- ============================================================
-- View: recent sentiment with news (join via news_item_id)
-- ============================================================
CREATE OR REPLACE VIEW recent_sentiment_with_news AS
SELECT 
    sa.id,
    sa.symbol,
    sa.analyzed_at,
    sa.bert_label,
    sa.bert_confidence,
    sa.bert_score,
    ni.title,
    ni.content,
    ni.published_date,
    ni.source,
    ni.link
FROM sentiment_analysis sa
JOIN news_items ni ON sa.news_item_id = ni.id
ORDER BY sa.analyzed_at DESC;

-- ============================================================
-- Continuous Aggregate: daily sentiment summary
-- Replaces the plain VIEW for much faster dashboard queries
-- ============================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS daily_sentiment_summary
WITH (timescaledb.continuous) AS
SELECT 
    symbol,
    time_bucket('1 day', analyzed_at) AS bucket,
    COUNT(*) AS total_analyses,
    AVG(bert_score) AS avg_sentiment_score,
    AVG(bert_confidence) AS avg_confidence,
    SUM(CASE WHEN bert_label = 'positive' THEN 1 ELSE 0 END) AS positive_count,
    SUM(CASE WHEN bert_label = 'neutral'  THEN 1 ELSE 0 END) AS neutral_count,
    SUM(CASE WHEN bert_label = 'negative' THEN 1 ELSE 0 END) AS negative_count
FROM sentiment_analysis
WHERE bert_label IS NOT NULL
GROUP BY symbol, time_bucket('1 day', analyzed_at)
WITH NO DATA;

-- Refresh policy: materialise data older than 1 hour, every 30 minutes
SELECT add_continuous_aggregate_policy('daily_sentiment_summary',
    start_offset    => INTERVAL '7 days',
    end_offset      => INTERVAL '1 hour',
    schedule_interval => INTERVAL '30 minutes',
    if_not_exists   => TRUE
);

-- ============================================================
-- Function: get sentiment trend using time_bucket
-- ============================================================
CREATE OR REPLACE FUNCTION get_sentiment_trend(
    p_symbol VARCHAR(20),
    p_days INT DEFAULT 7
)
RETURNS TABLE (
    date DATE,
    avg_sentiment DECIMAL,
    avg_confidence DECIMAL,
    analysis_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        time_bucket('1 day', analyzed_at)::DATE AS date,
        AVG(bert_score)::DECIMAL AS avg_sentiment,
        AVG(bert_confidence)::DECIMAL AS avg_confidence,
        COUNT(*) AS analysis_count
    FROM sentiment_analysis
    WHERE symbol = p_symbol
      AND analyzed_at >= NOW() - (p_days || ' days')::INTERVAL
      AND bert_label IS NOT NULL
    GROUP BY time_bucket('1 day', analyzed_at)
    ORDER BY date DESC;
END;
$$ LANGUAGE plpgsql;
