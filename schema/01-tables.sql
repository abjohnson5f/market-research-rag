-- ============================================================================
-- Market Research RAG System - Database Schema
-- ============================================================================
-- This schema stores local business data from Google Maps (via Apify)
-- and supports RAG-powered market analysis via AI agents
--
-- Design principles:
-- 1. JSONB for semi-structured data (Apify schema changes frequently)
-- 2. Generated columns for common filters (city, rating, etc.)
-- 3. One-to-many relationships (business → reviews)
-- 4. Full-text search on review text
-- ============================================================================

-- ============================================================================
-- EXECUTION TRACKING
-- ============================================================================
-- Tracks each workflow execution (replaces Google Sheets file creation)
CREATE TABLE IF NOT EXISTS market_executions (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    status TEXT DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed')),

    -- Search context
    search_query TEXT,           -- What was searched (e.g., "plumbers in Phoenix")
    apify_dataset_id TEXT,       -- Link back to Apify dataset

    -- Statistics
    total_businesses INT DEFAULT 0,
    total_reviews INT DEFAULT 0,

    -- Notes
    notes TEXT
);

COMMENT ON TABLE market_executions IS 'Tracks each workflow run - one row per execution';
COMMENT ON COLUMN market_executions.status IS 'Current state: running | completed | failed';


-- ============================================================================
-- BUSINESS DATA (Core Table)
-- ============================================================================
-- One row per business with all dimensions stored as JSONB
-- This consolidates what were previously 8 separate Google Sheets
CREATE TABLE IF NOT EXISTS businesses (
    id SERIAL PRIMARY KEY,
    execution_id INT NOT NULL REFERENCES market_executions(id) ON DELETE CASCADE,

    -- Business identifiers
    business_name TEXT NOT NULL,
    search_string TEXT,
    apify_place_id TEXT UNIQUE,  -- For deduplication across runs

    -- All business data as single JSONB column
    -- Contains: overview, contact, social, rating, popular_times, tags, lead_enrichment
    business_data JSONB NOT NULL,

    -- Generated columns for common queries (extracted from JSONB)
    city TEXT GENERATED ALWAYS AS (business_data->'overview'->>'city') STORED,
    category TEXT GENERATED ALWAYS AS (business_data->'overview'->>'category') STORED,
    rating DECIMAL GENERATED ALWAYS AS ((business_data->'rating'->>'totalScore')::decimal) STORED,
    review_count INT GENERATED ALWAYS AS ((business_data->'rating'->>'reviewsCount')::int) STORED,
    website TEXT GENERATED ALWAYS AS (business_data->'contact'->>'website') STORED,
    phone TEXT GENERATED ALWAYS AS (business_data->'contact'->>'phone') STORED,

    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE businesses IS 'One row per business with all dimensions in business_data JSONB';
COMMENT ON COLUMN businesses.business_data IS 'JSONB containing overview, contact, social, rating, popular_times, tags, lead_enrichment';
COMMENT ON COLUMN businesses.apify_place_id IS 'Unique identifier from Apify - prevents duplicates when re-running searches';


-- ============================================================================
-- BUSINESS REVIEWS (One-to-Many)
-- ============================================================================
-- Individual customer reviews with full JSONB storage
CREATE TABLE IF NOT EXISTS business_reviews (
    id SERIAL PRIMARY KEY,
    business_id INT NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,

    -- Store entire review as JSONB (fields vary by review)
    review_data JSONB NOT NULL,

    -- Extracted columns for filtering/sorting (not generated due to Postgres 17 immutability requirements)
    -- Populated automatically by extract_review_fields() trigger (with defensive error handling)
    reviewer_name TEXT,
    stars INT,
    review_text TEXT,
    published_at DATE,

    created_at TIMESTAMP DEFAULT NOW(),

    -- Data quality constraints: Validate stars is valid rating scale (NULL allowed for malformed data)
    CONSTRAINT valid_stars_range CHECK (stars IS NULL OR stars BETWEEN 0 AND 5)
);

COMMENT ON TABLE business_reviews IS 'Individual customer reviews - one-to-many with businesses';
COMMENT ON COLUMN business_reviews.review_data IS 'Full review object: text, stars, reviewer info, images, owner response, etc.';
COMMENT ON COLUMN business_reviews.stars IS 'Rating (0-5 scale). NULL if malformed in source data. Analytics should use COALESCE(stars, 0) or filter WHERE stars IS NOT NULL.';
COMMENT ON COLUMN business_reviews.review_text IS 'Extracted for full-text search - automatically populated by trigger';
COMMENT ON COLUMN business_reviews.published_at IS 'Publication date. NULL if unparseable in source data.';


-- ============================================================================
-- TRIGGER: Update business.updated_at on UPSERT
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_businesses_updated_at
    BEFORE UPDATE ON businesses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- ============================================================================
-- TRIGGER: Extract review fields from JSONB
-- ============================================================================
-- Postgres 17+ requires immutable generated columns, but JSONB extraction is STABLE
-- Solution: Use trigger to populate extracted columns on INSERT/UPDATE
--
-- DATA QUALITY STRATEGY (Fail-Open with Validation):
-- 1. Trigger: Defensive casting - malformed types become NULL (graceful degradation)
-- 2. Constraint: Range validation - valid types but wrong values rejected (data integrity)
-- 3. Result: Best of both worlds - resilient to API changes, strict on valid data
--
-- Example scenarios:
--   stars: 5           → SUCCESS (valid integer, valid range)
--   stars: "five"      → NULL (malformed type, trigger catches, logs warning)
--   stars: 99          → REJECT (valid type, invalid range, constraint catches)
--   stars: null        → NULL (missing data allowed, analytics handle gracefully)
--
-- Trade-off: NULL values in analytics require COALESCE/filtering, but system never crashes
CREATE OR REPLACE FUNCTION extract_review_fields()
RETURNS TRIGGER AS $$
BEGIN
    -- Extract reviewer name (safe - text always succeeds)
    NEW.reviewer_name := NEW.review_data->>'reviewerName';

    -- Extract stars with defensive casting (default to NULL if unparseable)
    BEGIN
        NEW.stars := (NEW.review_data->>'stars')::int;
    EXCEPTION WHEN OTHERS THEN
        NEW.stars := NULL;
        RAISE WARNING 'Invalid stars value in review_data for review ID %: %', NEW.id, NEW.review_data->>'stars';
    END;

    -- Extract review text (safe - text always succeeds)
    NEW.review_text := NEW.review_data->>'text';

    -- Extract published date with defensive casting (default to NULL if unparseable)
    BEGIN
        NEW.published_at := (NEW.review_data->>'publishedAtDate')::date;
    EXCEPTION WHEN OTHERS THEN
        NEW.published_at := NULL;
        RAISE WARNING 'Invalid date value in review_data for review ID %: %', NEW.id, NEW.review_data->>'publishedAtDate';
    END;

    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER extract_review_fields_trigger
    BEFORE INSERT OR UPDATE ON business_reviews
    FOR EACH ROW
    EXECUTE FUNCTION extract_review_fields();


-- ============================================================================
-- TRIGGER: Update execution statistics
-- ============================================================================
CREATE OR REPLACE FUNCTION update_execution_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update business count when businesses are inserted
    IF TG_TABLE_NAME = 'businesses' AND TG_OP = 'INSERT' THEN
        UPDATE market_executions
        SET total_businesses = total_businesses + 1
        WHERE id = NEW.execution_id;
    END IF;

    -- Update review count when reviews are inserted
    IF TG_TABLE_NAME = 'business_reviews' AND TG_OP = 'INSERT' THEN
        UPDATE market_executions e
        SET total_reviews = total_reviews + 1
        FROM businesses b
        WHERE b.id = NEW.business_id
          AND e.id = b.execution_id;
    END IF;

    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_stats_on_business_insert
    AFTER INSERT ON businesses
    FOR EACH ROW
    EXECUTE FUNCTION update_execution_stats();

CREATE TRIGGER update_stats_on_review_insert
    AFTER INSERT ON business_reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_execution_stats();


-- ============================================================================
-- VIEWS: Common Queries
-- ============================================================================

-- Business summary with review stats
CREATE OR REPLACE VIEW business_summary AS
SELECT
    b.id,
    b.business_name,
    b.city,
    b.category,
    b.rating,
    b.review_count,
    b.phone,
    b.website,
    COUNT(r.id) as stored_reviews,
    AVG(r.stars) as avg_review_rating,
    b.business_data->'social'->>'instagrams' as instagram,
    b.business_data->'social'->>'facebooks' as facebook,
    b.created_at
FROM businesses b
LEFT JOIN business_reviews r ON r.business_id = b.id
GROUP BY b.id, b.business_name, b.city, b.category, b.rating,
         b.review_count, b.phone, b.website, b.business_data, b.created_at;

COMMENT ON VIEW business_summary IS 'Flattened view of businesses with review aggregations';


-- Recent executions summary
CREATE OR REPLACE VIEW recent_executions AS
SELECT
    e.id,
    e.created_at,
    e.completed_at,
    e.status,
    e.search_query,
    e.total_businesses,
    e.total_reviews,
    ROUND(EXTRACT(EPOCH FROM (e.completed_at - e.created_at)) / 60, 2) as duration_minutes
FROM market_executions e
ORDER BY e.created_at DESC
LIMIT 50;

COMMENT ON VIEW recent_executions IS 'Last 50 workflow runs with statistics';


-- ============================================================================
-- SAMPLE QUERIES (for testing)
-- ============================================================================

-- Find high-rated businesses with few reviews (underserved opportunities)
-- SELECT * FROM businesses
-- WHERE rating > 4.5 AND review_count < 20
-- ORDER BY rating DESC;

-- Search reviews for specific keywords
-- SELECT b.business_name, r.review_text, r.stars
-- FROM business_reviews r
-- JOIN businesses b ON b.id = r.business_id
-- WHERE r.review_text ILIKE '%parking%'
-- ORDER BY r.stars DESC;

-- Find businesses with Instagram but low review count (influencer potential)
-- SELECT business_name, city, rating, review_count,
--        business_data->'social'->>'instagrams' as instagram
-- FROM businesses
-- WHERE business_data->'social'->>'instagrams' IS NOT NULL
--   AND review_count < 50
-- ORDER BY rating DESC;

-- Category analysis by city
-- SELECT city, category, COUNT(*) as business_count,
--        AVG(rating) as avg_rating, SUM(review_count) as total_reviews
-- FROM businesses
-- WHERE city IS NOT NULL
-- GROUP BY city, category
-- HAVING COUNT(*) > 3
-- ORDER BY total_reviews DESC;
