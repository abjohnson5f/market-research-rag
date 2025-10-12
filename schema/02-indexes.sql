-- ============================================================================
-- Performance Indexes for Market Research RAG System
-- ============================================================================
-- Run AFTER 01-tables.sql
-- These indexes optimize common query patterns used by the AI agent
-- ============================================================================

-- ============================================================================
-- EXECUTION TABLE INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_executions_created
    ON market_executions(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_executions_status
    ON market_executions(status) WHERE status != 'completed';

COMMENT ON INDEX idx_executions_status IS 'Find in-progress or failed executions quickly';


-- ============================================================================
-- BUSINESS TABLE INDEXES
-- ============================================================================

-- Foreign key index
CREATE INDEX IF NOT EXISTS idx_businesses_execution
    ON businesses(execution_id);

-- Common filter columns (from generated columns)
CREATE INDEX IF NOT EXISTS idx_businesses_city
    ON businesses(city) WHERE city IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_businesses_category
    ON businesses(category) WHERE category IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_businesses_rating
    ON businesses(rating DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_businesses_review_count
    ON businesses(review_count DESC NULLS LAST);

-- Name search (case-insensitive)
CREATE INDEX IF NOT EXISTS idx_businesses_name_lower
    ON businesses(LOWER(business_name) text_pattern_ops);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_businesses_city_rating
    ON businesses(city, rating DESC) WHERE city IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_businesses_city_category
    ON businesses(city, category) WHERE city IS NOT NULL AND category IS NOT NULL;

-- JSONB indexes using GIN (Generalized Inverted Index)
-- These enable fast queries on JSONB fields

-- General JSONB queries (supports all operators: ?, ?&, ?|, @>, @@)
CREATE INDEX IF NOT EXISTS idx_businesses_data_gin
    ON businesses USING GIN (business_data jsonb_path_ops);

-- Specific JSONB path indexes (faster for known paths)
CREATE INDEX IF NOT EXISTS idx_businesses_overview_gin
    ON businesses USING GIN ((business_data->'overview'));

CREATE INDEX IF NOT EXISTS idx_businesses_social_gin
    ON businesses USING GIN ((business_data->'social'));

CREATE INDEX IF NOT EXISTS idx_businesses_rating_gin
    ON businesses USING GIN ((business_data->'rating'));

COMMENT ON INDEX idx_businesses_data_gin IS 'Enables fast queries like: WHERE business_data @> ''{"overview": {"city": "Phoenix"}}''';


-- ============================================================================
-- REVIEW TABLE INDEXES
-- ============================================================================

-- Foreign key
CREATE INDEX IF NOT EXISTS idx_reviews_business
    ON business_reviews(business_id);

-- Common filters
CREATE INDEX IF NOT EXISTS idx_reviews_stars
    ON business_reviews(stars DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_reviews_date
    ON business_reviews(published_at DESC NULLS LAST);

-- Full-text search on review text (enables fast text searches)
CREATE INDEX IF NOT EXISTS idx_reviews_text_fts
    ON business_reviews USING GIN (to_tsvector('english', review_text));

COMMENT ON INDEX idx_reviews_text_fts IS 'Enables queries like: WHERE to_tsvector(''english'', review_text) @@ to_tsquery(''parking & problem'')';

-- JSONB index for review data
CREATE INDEX IF NOT EXISTS idx_reviews_data_gin
    ON business_reviews USING GIN (review_data jsonb_path_ops);

-- Composite index for business + rating queries
CREATE INDEX IF NOT EXISTS idx_reviews_business_stars
    ON business_reviews(business_id, stars DESC);


-- ============================================================================
-- ANALYZE TABLES (Update query planner statistics)
-- ============================================================================

ANALYZE market_executions;
ANALYZE businesses;
ANALYZE business_reviews;


-- ============================================================================
-- EXAMPLE QUERIES THAT USE THESE INDEXES
-- ============================================================================

-- 1. Find businesses in Phoenix with rating > 4.5 (uses idx_businesses_city_rating)
-- EXPLAIN ANALYZE
-- SELECT business_name, rating, review_count
-- FROM businesses
-- WHERE city = 'Phoenix' AND rating > 4.5
-- ORDER BY rating DESC;

-- 2. Full-text search in reviews (uses idx_reviews_text_fts)
-- EXPLAIN ANALYZE
-- SELECT b.business_name, r.review_text, r.stars
-- FROM business_reviews r
-- JOIN businesses b ON b.id = r.business_id
-- WHERE to_tsvector('english', r.review_text) @@ to_tsquery('parking & problem')
-- ORDER BY r.stars DESC;

-- 3. JSONB path query (uses idx_businesses_data_gin)
-- EXPLAIN ANALYZE
-- SELECT business_name, business_data->'social'->>'instagrams' as instagram
-- FROM businesses
-- WHERE business_data->'social' ? 'instagrams'
--   AND business_data->'social'->>'instagrams' != '';

-- 4. Recent executions (uses idx_executions_created)
-- EXPLAIN ANALYZE
-- SELECT * FROM recent_executions
-- WHERE created_at > NOW() - INTERVAL '7 days'
-- ORDER BY created_at DESC;
