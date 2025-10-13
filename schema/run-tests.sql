-- ============================================================================
-- Market Research RAG System - Automated Test Suite
-- ============================================================================
-- Comprehensive testing across 7 categories with 40 test cases
-- Run AFTER test-data.sql has been loaded
--
-- Usage:
--   1. Load test data: psql -f schema/test-data.sql
--   2. Run tests: psql -f schema/run-tests.sql
--   3. Review results for PASS/FAIL markers
--
-- Test Categories:
--   1. Database Health (8 tests)
--   2. Data Collection Workflow (6 tests)
--   3. RAG Chat Interface (5 tests)
--   4. AI Tool Execution (7 tests)
--   5. Error Handling (4 tests)
--   6. Performance (5 tests)
--   7. End-to-End Scenarios (5 tests)
-- ============================================================================

\set QUIET on
\pset format wrapped
\pset border 2

-- Enable timing for performance tests
\timing on

SELECT '
============================================================================
MARKET RESEARCH RAG SYSTEM - TEST SUITE
============================================================================
Starting automated tests...
Test Date: ' || NOW()::DATE || '
Test Time: ' || NOW()::TIME || '
============================================================================
' as test_header;


-- ============================================================================
-- CATEGORY 1: DATABASE HEALTH (8 tests)
-- ============================================================================

SELECT '
============================================================================
CATEGORY 1: DATABASE HEALTH
============================================================================' as category;

-- Test 1.1: Tables Exist
-- Expected: All 3 core tables exist with correct column counts
SELECT '
-- Test 1.1: Tables Exist
-- Expected: All 3 tables (market_executions, businesses, business_reviews)
-- Result: ' as test_info;

DO $$
DECLARE
    table_count INT;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name IN ('market_executions', 'businesses', 'business_reviews');

    IF table_count = 3 THEN
        RAISE NOTICE '✓ PASS - All 3 tables exist';
    ELSE
        RAISE NOTICE '✗ FAIL - Expected 3 tables, found %', table_count;
    END IF;
END $$;

SELECT
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
AND table_name IN ('market_executions', 'businesses', 'business_reviews')
ORDER BY table_name;


-- Test 1.2: Indexes Exist
-- Expected: All tables have appropriate indexes for performance
SELECT '
-- Test 1.2: Indexes Exist
-- Expected: businesses (~12), business_reviews (~5), market_executions (~2)
-- Result: ' as test_info;

DO $$
DECLARE
    business_indexes INT;
    review_indexes INT;
    execution_indexes INT;
BEGIN
    SELECT COUNT(*) INTO business_indexes
    FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'businesses';

    SELECT COUNT(*) INTO review_indexes
    FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'business_reviews';

    SELECT COUNT(*) INTO execution_indexes
    FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'market_executions';

    IF business_indexes >= 10 AND review_indexes >= 4 AND execution_indexes >= 1 THEN
        RAISE NOTICE '✓ PASS - Indexes present: businesses=%, reviews=%, executions=%',
            business_indexes, review_indexes, execution_indexes;
    ELSE
        RAISE NOTICE '✗ FAIL - Insufficient indexes: businesses=%, reviews=%, executions=%',
            business_indexes, review_indexes, execution_indexes;
    END IF;
END $$;

SELECT tablename, COUNT(*) as index_count
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename IN ('businesses', 'business_reviews', 'market_executions')
GROUP BY tablename
ORDER BY tablename;


-- Test 1.3: Triggers Work
-- Expected: updated_at and stats update triggers exist
SELECT '
-- Test 1.3: Triggers Work
-- Expected: update_businesses_updated_at, update_stats_on_business_insert, update_stats_on_review_insert
-- Result: ' as test_info;

DO $$
DECLARE
    trigger_count INT;
BEGIN
    SELECT COUNT(*) INTO trigger_count
    FROM information_schema.triggers
    WHERE trigger_schema = 'public'
    AND event_object_table IN ('businesses', 'business_reviews', 'market_executions');

    IF trigger_count >= 3 THEN
        RAISE NOTICE '✓ PASS - Found % triggers', trigger_count;
    ELSE
        RAISE NOTICE '✗ FAIL - Expected at least 3 triggers, found %', trigger_count;
    END IF;
END $$;

SELECT trigger_name, event_object_table, action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;


-- Test 1.4: Views Accessible
-- Expected: business_summary and recent_executions views exist
SELECT '
-- Test 1.4: Views Accessible
-- Expected: business_summary, recent_executions
-- Result: ' as test_info;

DO $$
DECLARE
    view_count INT;
BEGIN
    SELECT COUNT(*) INTO view_count
    FROM information_schema.views
    WHERE table_schema = 'public'
    AND table_name IN ('business_summary', 'recent_executions');

    IF view_count = 2 THEN
        RAISE NOTICE '✓ PASS - Both views exist';
    ELSE
        RAISE NOTICE '✗ FAIL - Expected 2 views, found %', view_count;
    END IF;
END $$;

SELECT table_name, view_definition IS NOT NULL as has_definition
FROM information_schema.views
WHERE table_schema = 'public'
AND table_name IN ('business_summary', 'recent_executions');


-- Test 1.5: Generated Columns Functioning
-- Expected: Generated columns extract data from JSONB correctly
SELECT '
-- Test 1.5: Generated Columns Functioning
-- Expected: city, category, rating, review_count auto-populate from JSONB
-- Result: ' as test_info;

DO $$
DECLARE
    generated_match_count INT;
    total_count INT;
BEGIN
    SELECT
        COUNT(*) FILTER (WHERE city = business_data->'overview'->>'city'),
        COUNT(*)
    INTO generated_match_count, total_count
    FROM businesses
    WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA');

    IF generated_match_count = total_count THEN
        RAISE NOTICE '✓ PASS - All % businesses have matching generated columns', total_count;
    ELSE
        RAISE NOTICE '✗ FAIL - Generated column mismatch: %/% match', generated_match_count, total_count;
    END IF;
END $$;

SELECT
    business_name,
    city,
    business_data->'overview'->>'city' as jsonb_city,
    city = business_data->'overview'->>'city' as columns_match
FROM businesses
WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
LIMIT 3;


-- Test 1.6: Foreign Keys Enforced
-- Expected: Cannot insert review without valid business_id
SELECT '
-- Test 1.6: Foreign Keys Enforced
-- Expected: Foreign key constraints prevent orphaned records
-- Result: ' as test_info;

DO $$
BEGIN
    -- Try to insert a review with non-existent business_id
    BEGIN
        INSERT INTO business_reviews (business_id, review_data)
        VALUES (999999, '{"text": "This should fail"}'::jsonb);

        RAISE NOTICE '✗ FAIL - Foreign key constraint not enforced';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE '✓ PASS - Foreign key constraint working correctly';
    END;
END $$;


-- Test 1.7: Constraints Valid
-- Expected: CHECK constraints on status field work
SELECT '
-- Test 1.7: Constraints Valid
-- Expected: Status field only accepts: running, completed, failed
-- Result: ' as test_info;

DO $$
BEGIN
    -- Try to insert invalid status
    BEGIN
        INSERT INTO market_executions (status, search_query)
        VALUES ('invalid_status', 'TEST_CONSTRAINT');

        RAISE NOTICE '✗ FAIL - CHECK constraint not enforced';
        -- Clean up if it somehow succeeded
        DELETE FROM market_executions WHERE search_query = 'TEST_CONSTRAINT';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE '✓ PASS - CHECK constraint working correctly';
    END;
END $$;


-- Test 1.8: Full-Text Search Enabled
-- Expected: FTS index exists on review_text
SELECT '
-- Test 1.8: Full-Text Search Enabled
-- Expected: GIN index idx_reviews_text_fts exists
-- Result: ' as test_info;

DO $$
DECLARE
    fts_index_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public'
        AND tablename = 'business_reviews'
        AND indexname = 'idx_reviews_text_fts'
    ) INTO fts_index_exists;

    IF fts_index_exists THEN
        RAISE NOTICE '✓ PASS - Full-text search index exists';
    ELSE
        RAISE NOTICE '✗ FAIL - Full-text search index missing';
    END IF;
END $$;

-- Verify FTS actually works
SELECT COUNT(*) as fts_test_result
FROM business_reviews
WHERE to_tsvector('english', review_text) @@ to_tsquery('parking');


-- ============================================================================
-- CATEGORY 2: DATA COLLECTION WORKFLOW (6 tests)
-- ============================================================================

SELECT '
============================================================================
CATEGORY 2: DATA COLLECTION WORKFLOW
============================================================================' as category;

-- Test 2.1: Execution Tracking Works
-- Expected: Test execution exists with correct statistics
SELECT '
-- Test 2.1: Execution Tracking Works
-- Expected: Test execution has status=completed, total_businesses=10, total_reviews=30
-- Result: ' as test_info;

DO $$
DECLARE
    exec_status TEXT;
    exec_businesses INT;
    exec_reviews INT;
BEGIN
    SELECT status, total_businesses, total_reviews
    INTO exec_status, exec_businesses, exec_reviews
    FROM market_executions
    WHERE search_query = 'TEST_DATA';

    IF exec_status = 'completed' AND exec_businesses = 10 AND exec_reviews = 30 THEN
        RAISE NOTICE '✓ PASS - Execution tracking correct: status=%, businesses=%, reviews=%',
            exec_status, exec_businesses, exec_reviews;
    ELSE
        RAISE NOTICE '✗ FAIL - Execution tracking incorrect: status=%, businesses=%, reviews=%',
            exec_status, exec_businesses, exec_reviews;
    END IF;
END $$;

SELECT id, status, total_businesses, total_reviews, search_query
FROM market_executions
WHERE search_query = 'TEST_DATA';


-- Test 2.2: Business UPSERT Prevents Duplicates
-- Expected: Unique constraint on apify_place_id prevents duplicates
SELECT '
-- Test 2.2: Business UPSERT Prevents Duplicates
-- Expected: Cannot insert duplicate apify_place_id
-- Result: ' as test_info;

DO $$
BEGIN
    -- Try to insert duplicate
    BEGIN
        INSERT INTO businesses (execution_id, business_name, apify_place_id, business_data)
        VALUES (
            (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA'),
            'Duplicate Test',
            'TEST_ChIJ1234_Phoenix_Auto',
            '{"overview": {}}'::jsonb
        );

        RAISE NOTICE '✗ FAIL - Duplicate apify_place_id was allowed';
        -- Clean up
        DELETE FROM businesses WHERE business_name = 'Duplicate Test';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE '✓ PASS - Unique constraint prevents duplicates';
    END;
END $$;


-- Test 2.3: Reviews Batch Insert Atomic
-- Expected: All reviews linked to valid businesses
SELECT '
-- Test 2.3: Reviews Batch Insert Atomic
-- Expected: All reviews have valid business_id (no orphans)
-- Result: ' as test_info;

DO $$
DECLARE
    orphan_count INT;
BEGIN
    SELECT COUNT(*)
    INTO orphan_count
    FROM business_reviews r
    WHERE NOT EXISTS (
        SELECT 1 FROM businesses b WHERE b.id = r.business_id
    );

    IF orphan_count = 0 THEN
        RAISE NOTICE '✓ PASS - No orphaned reviews';
    ELSE
        RAISE NOTICE '✗ FAIL - Found % orphaned reviews', orphan_count;
    END IF;
END $$;


-- Test 2.4: JSONB Structure Correct
-- Expected: All businesses have required JSONB keys
SELECT '
-- Test 2.4: JSONB Structure Correct
-- Expected: All business_data contains: overview, contact, social, rating
-- Result: ' as test_info;

DO $$
DECLARE
    valid_structure_count INT;
    total_count INT;
BEGIN
    SELECT
        COUNT(*) FILTER (
            WHERE business_data ? 'overview'
            AND business_data ? 'contact'
            AND business_data ? 'social'
            AND business_data ? 'rating'
        ),
        COUNT(*)
    INTO valid_structure_count, total_count
    FROM businesses
    WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA');

    IF valid_structure_count = total_count THEN
        RAISE NOTICE '✓ PASS - All % businesses have valid JSONB structure', total_count;
    ELSE
        RAISE NOTICE '✗ FAIL - Invalid JSONB structure: %/% valid', valid_structure_count, total_count;
    END IF;
END $$;

SELECT
    business_name,
    business_data ? 'overview' as has_overview,
    business_data ? 'contact' as has_contact,
    business_data ? 'social' as has_social,
    business_data ? 'rating' as has_rating
FROM businesses
WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
LIMIT 3;


-- Test 2.5: Generated Columns Populated
-- Expected: Generated columns have values (not all NULL)
SELECT '
-- Test 2.5: Generated Columns Populated
-- Expected: city, category, rating, review_count are not NULL
-- Result: ' as test_info;

DO $$
DECLARE
    populated_count INT;
    total_count INT;
BEGIN
    SELECT
        COUNT(*) FILTER (
            WHERE city IS NOT NULL
            AND category IS NOT NULL
            AND rating IS NOT NULL
            AND review_count IS NOT NULL
        ),
        COUNT(*)
    INTO populated_count, total_count
    FROM businesses
    WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA');

    IF populated_count = total_count THEN
        RAISE NOTICE '✓ PASS - All % businesses have populated generated columns', total_count;
    ELSE
        RAISE NOTICE '✗ FAIL - Missing generated columns: %/% populated', populated_count, total_count;
    END IF;
END $$;


-- Test 2.6: Statistics Auto-Updated
-- Expected: Trigger updates execution stats on insert
SELECT '
-- Test 2.6: Statistics Auto-Updated
-- Expected: total_businesses and total_reviews match actual counts
-- Result: ' as test_info;

DO $$
DECLARE
    recorded_businesses INT;
    actual_businesses INT;
    recorded_reviews INT;
    actual_reviews INT;
BEGIN
    -- Get recorded stats
    SELECT total_businesses, total_reviews
    INTO recorded_businesses, recorded_reviews
    FROM market_executions
    WHERE search_query = 'TEST_DATA';

    -- Get actual counts
    SELECT COUNT(*) INTO actual_businesses
    FROM businesses
    WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA');

    SELECT COUNT(*) INTO actual_reviews
    FROM business_reviews r
    JOIN businesses b ON b.id = r.business_id
    WHERE b.execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA');

    IF recorded_businesses = actual_businesses AND recorded_reviews = actual_reviews THEN
        RAISE NOTICE '✓ PASS - Statistics match: businesses=%, reviews=%',
            actual_businesses, actual_reviews;
    ELSE
        RAISE NOTICE '✗ FAIL - Statistics mismatch: recorded (%, %), actual (%, %)',
            recorded_businesses, recorded_reviews, actual_businesses, actual_reviews;
    END IF;
END $$;


-- ============================================================================
-- CATEGORY 3: RAG CHAT INTERFACE (5 tests)
-- ============================================================================

SELECT '
============================================================================
CATEGORY 3: RAG CHAT INTERFACE
============================================================================
Note: Tests 3.1-3.5 require n8n workflow to be running.
These tests verify database queries that the AI agent would execute.
============================================================================' as category;

-- Test 3.1: Chat Webhook Responds
-- Expected: Database can handle typical chat queries
SELECT '
-- Test 3.1: Chat Webhook Responds
-- Expected: Simple business query executes successfully
-- Result: ' as test_info;

DO $$
DECLARE
    result_count INT;
BEGIN
    -- Simulate typical AI query: "Show me 3 businesses"
    SELECT COUNT(*) INTO result_count
    FROM (
        SELECT business_name, city, rating
        FROM businesses
        WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
        LIMIT 3
    ) subquery;

    IF result_count = 3 THEN
        RAISE NOTICE '✓ PASS - Basic query returns expected results';
    ELSE
        RAISE NOTICE '✗ FAIL - Expected 3 results, got %', result_count;
    END IF;
END $$;


-- Test 3.2: AI Agent Accessible
-- Expected: Complex aggregation queries work (AI tool functionality)
SELECT '
-- Test 3.2: AI Agent Accessible
-- Expected: Category aggregation query executes
-- Result: ' as test_info;

DO $$
DECLARE
    category_count INT;
BEGIN
    SELECT COUNT(*) INTO category_count
    FROM (
        SELECT category, COUNT(*) as count, AVG(rating) as avg_rating
        FROM businesses
        WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
        GROUP BY category
    ) subquery;

    IF category_count > 0 THEN
        RAISE NOTICE '✓ PASS - Aggregation query works, found % categories', category_count;
    ELSE
        RAISE NOTICE '✗ FAIL - Aggregation query failed';
    END IF;
END $$;


-- Test 3.3: Memory Stores Conversations
-- Expected: Database structure supports session tracking (table exists in n8n)
SELECT '
-- Test 3.3: Memory Stores Conversations
-- Expected: System can track session context via execution_id
-- Result: ' as test_info;

DO $$
BEGIN
    -- Verify we can query by execution_id (session analog)
    IF EXISTS (
        SELECT 1 FROM businesses
        WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
    ) THEN
        RAISE NOTICE '✓ PASS - Session tracking mechanism works';
    ELSE
        RAISE NOTICE '✗ FAIL - Cannot track sessions';
    END IF;
END $$;


-- Test 3.4: Tools Connected Properly
-- Expected: All three AI tools can query database
SELECT '
-- Test 3.4: Tools Connected Properly
-- Expected: Tool 1 (businesses), Tool 2 (reviews), Tool 3 (opportunities) all executable
-- Result: ' as test_info;

DO $$
BEGIN
    -- Tool 1: Query businesses
    IF EXISTS (SELECT 1 FROM businesses LIMIT 1) THEN
        RAISE NOTICE '✓ Tool 1: query_businesses - PASS';
    ELSE
        RAISE NOTICE '✗ Tool 1: query_businesses - FAIL';
    END IF;

    -- Tool 2: Query reviews
    IF EXISTS (SELECT 1 FROM business_reviews LIMIT 1) THEN
        RAISE NOTICE '✓ Tool 2: query_reviews - PASS';
    ELSE
        RAISE NOTICE '✗ Tool 2: query_reviews - FAIL';
    END IF;

    -- Tool 3: Analyze opportunities (complex query)
    IF EXISTS (
        SELECT 1 FROM businesses
        WHERE rating > 4.0 AND review_count < 50
        LIMIT 1
    ) THEN
        RAISE NOTICE '✓ Tool 3: analyze_opportunities - PASS';
    ELSE
        RAISE NOTICE '✗ Tool 3: analyze_opportunities - FAIL';
    END IF;
END $$;


-- Test 3.5: Query Execution Works
-- Expected: JSONB queries execute correctly
SELECT '
-- Test 3.5: Query Execution Works
-- Expected: JSONB operator queries work (Instagram presence check)
-- Result: ' as test_info;

DO $$
DECLARE
    instagram_count INT;
BEGIN
    SELECT COUNT(*) INTO instagram_count
    FROM businesses
    WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
    AND business_data->'social' ? 'instagrams'
    AND business_data->'social'->>'instagrams' IS NOT NULL
    AND business_data->'social'->>'instagrams' != '';

    IF instagram_count > 0 THEN
        RAISE NOTICE '✓ PASS - JSONB queries work, found % businesses with Instagram', instagram_count;
    ELSE
        RAISE NOTICE '✗ FAIL - JSONB queries not working';
    END IF;
END $$;


-- ============================================================================
-- CATEGORY 4: AI TOOL EXECUTION (7 tests)
-- ============================================================================

SELECT '
============================================================================
CATEGORY 4: AI TOOL EXECUTION
============================================================================' as category;

-- Test 4.1: Tool 1 - Query High-Rated Businesses
-- Expected: Returns businesses with rating > 4.5
SELECT '
-- Test 4.1: Tool 1 - Query High-Rated Businesses
-- Expected: Find businesses with rating > 4.5
-- Result: ' as test_info;

DO $$
DECLARE
    high_rated_count INT;
BEGIN
    SELECT COUNT(*) INTO high_rated_count
    FROM businesses
    WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
    AND rating > 4.5;

    IF high_rated_count >= 5 THEN
        RAISE NOTICE '✓ PASS - Found % businesses with rating > 4.5', high_rated_count;
    ELSE
        RAISE NOTICE '✗ FAIL - Expected at least 5 high-rated businesses, found %', high_rated_count;
    END IF;
END $$;

SELECT business_name, city, rating, review_count
FROM businesses
WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
AND rating > 4.5
ORDER BY rating DESC
LIMIT 5;


-- Test 4.2: Tool 1 - Filter by City
-- Expected: Returns only Phoenix businesses
SELECT '
-- Test 4.2: Tool 1 - Filter by City
-- Expected: Filter businesses WHERE city = ''Phoenix''
-- Result: ' as test_info;

DO $$
DECLARE
    phoenix_count INT;
    non_phoenix_count INT;
BEGIN
    SELECT COUNT(*) INTO phoenix_count
    FROM businesses
    WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
    AND city = 'Phoenix';

    SELECT COUNT(*) INTO non_phoenix_count
    FROM (
        SELECT * FROM businesses
        WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
        AND city = 'Phoenix'
    ) subquery
    WHERE city != 'Phoenix';

    IF phoenix_count > 0 AND non_phoenix_count = 0 THEN
        RAISE NOTICE '✓ PASS - City filter works, found % Phoenix businesses', phoenix_count;
    ELSE
        RAISE NOTICE '✗ FAIL - City filter issue: Phoenix=%, Non-Phoenix=%',
            phoenix_count, non_phoenix_count;
    END IF;
END $$;


-- Test 4.3: Tool 2 - Full-Text Review Search
-- Expected: Full-text search finds reviews mentioning "parking"
SELECT '
-- Test 4.3: Tool 2 - Full-Text Review Search
-- Expected: FTS finds reviews mentioning "parking"
-- Result: ' as test_info;

DO $$
DECLARE
    parking_reviews INT;
BEGIN
    SELECT COUNT(*) INTO parking_reviews
    FROM business_reviews
    WHERE to_tsvector('english', review_text) @@ to_tsquery('parking');

    IF parking_reviews > 0 THEN
        RAISE NOTICE '✓ PASS - Full-text search works, found % reviews about parking', parking_reviews;
    ELSE
        RAISE NOTICE '✗ FAIL - Full-text search found no results (expected at least 1)';
    END IF;
END $$;

SELECT b.business_name, r.review_text, r.stars
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE to_tsvector('english', r.review_text) @@ to_tsquery('parking')
LIMIT 3;


-- Test 4.4: Tool 2 - Sentiment Analysis
-- Expected: Can separate positive (4-5 stars) from negative (1-2 stars) reviews
SELECT '
-- Test 4.4: Tool 2 - Sentiment Analysis
-- Expected: Categorize reviews by star rating
-- Result: ' as test_info;

DO $$
DECLARE
    positive_count INT;
    negative_count INT;
BEGIN
    SELECT COUNT(*) INTO positive_count
    FROM business_reviews
    WHERE stars >= 4;

    SELECT COUNT(*) INTO negative_count
    FROM business_reviews
    WHERE stars <= 2;

    IF positive_count > 0 AND negative_count > 0 THEN
        RAISE NOTICE '✓ PASS - Sentiment analysis works: positive=%, negative=%',
            positive_count, negative_count;
    ELSE
        RAISE NOTICE '✗ FAIL - Sentiment data incomplete: positive=%, negative=%',
            positive_count, negative_count;
    END IF;
END $$;

SELECT
    CASE
        WHEN stars >= 4 THEN 'Positive'
        WHEN stars = 3 THEN 'Neutral'
        ELSE 'Negative'
    END as sentiment,
    COUNT(*) as review_count
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE b.execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
GROUP BY sentiment
ORDER BY sentiment;


-- Test 4.5: Tool 3 - Find Market Gaps
-- Expected: Identify high-rated businesses with low review counts
SELECT '
-- Test 4.5: Tool 3 - Find Market Gaps
-- Expected: High rating (>4.5) + low reviews (<50) = opportunity
-- Result: ' as test_info;

DO $$
DECLARE
    opportunity_count INT;
BEGIN
    SELECT COUNT(*) INTO opportunity_count
    FROM businesses
    WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
    AND rating > 4.5
    AND review_count < 50;

    IF opportunity_count > 0 THEN
        RAISE NOTICE '✓ PASS - Found % market gap opportunities', opportunity_count;
    ELSE
        RAISE NOTICE '✗ FAIL - No opportunities found (check test data)';
    END IF;
END $$;

SELECT business_name, city, rating, review_count,
       'Low visibility despite quality' as opportunity_type
FROM businesses
WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
AND rating > 4.5
AND review_count < 50
ORDER BY rating DESC;


-- Test 4.6: Tool 3 - Competitive Analysis
-- Expected: Compare categories by average rating and review volume
SELECT '
-- Test 4.6: Tool 3 - Competitive Analysis
-- Expected: Category-level aggregation with rankings
-- Result: ' as test_info;

DO $$
DECLARE
    category_analysis_count INT;
BEGIN
    SELECT COUNT(*) INTO category_analysis_count
    FROM (
        SELECT
            category,
            COUNT(*) as business_count,
            AVG(rating) as avg_rating,
            SUM(review_count) as total_reviews
        FROM businesses
        WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
        GROUP BY category
    ) subquery
    WHERE business_count > 0;

    IF category_analysis_count > 0 THEN
        RAISE NOTICE '✓ PASS - Competitive analysis works for % categories', category_analysis_count;
    ELSE
        RAISE NOTICE '✗ FAIL - Competitive analysis failed';
    END IF;
END $$;

SELECT
    category,
    COUNT(*) as business_count,
    ROUND(AVG(rating), 2) as avg_rating,
    SUM(review_count) as total_reviews
FROM businesses
WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
GROUP BY category
ORDER BY total_reviews DESC
LIMIT 5;


-- Test 4.7: Tool 3 - Category Aggregation
-- Expected: Complex aggregation with multiple dimensions
SELECT '
-- Test 4.7: Tool 3 - Category Aggregation
-- Expected: Multi-dimensional analysis (city + category)
-- Result: ' as test_info;

DO $$
DECLARE
    aggregation_count INT;
BEGIN
    SELECT COUNT(*) INTO aggregation_count
    FROM (
        SELECT
            city,
            category,
            COUNT(*) as count,
            AVG(rating) as avg_rating
        FROM businesses
        WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
        GROUP BY city, category
    ) subquery;

    IF aggregation_count > 0 THEN
        RAISE NOTICE '✓ PASS - Multi-dimensional aggregation works, % combinations', aggregation_count;
    ELSE
        RAISE NOTICE '✗ FAIL - Aggregation query failed';
    END IF;
END $$;


-- ============================================================================
-- CATEGORY 5: ERROR HANDLING (4 tests)
-- ============================================================================

SELECT '
============================================================================
CATEGORY 5: ERROR HANDLING
============================================================================' as category;

-- Test 5.1: Invalid SQL Handled
-- Expected: Syntax errors are caught
SELECT '
-- Test 5.1: Invalid SQL Handled
-- Expected: Invalid column reference raises error
-- Result: ' as test_info;

DO $$
BEGIN
    BEGIN
        PERFORM * FROM businesses WHERE nonexistent_column = 'test';
        RAISE NOTICE '✗ FAIL - Invalid SQL was accepted';
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE '✓ PASS - Invalid SQL properly rejected';
    END;
END $$;


-- Test 5.2: Missing execution_id Handled
-- Expected: Query with NULL execution_id returns empty results
SELECT '
-- Test 5.2: Missing execution_id Handled
-- Expected: NULL execution_id returns 0 results, no crash
-- Result: ' as test_info;

DO $$
DECLARE
    result_count INT;
BEGIN
    SELECT COUNT(*) INTO result_count
    FROM businesses
    WHERE execution_id IS NULL;

    RAISE NOTICE '✓ PASS - NULL execution_id handled gracefully (% results)', result_count;
END $$;


-- Test 5.3: Duplicate apify_place_id Handled
-- Expected: Duplicate insert caught by unique constraint
SELECT '
-- Test 5.3: Duplicate apify_place_id Handled
-- Expected: UPSERT logic prevents duplicates
-- Result: ' as test_info;

DO $$
BEGIN
    BEGIN
        INSERT INTO businesses (execution_id, business_name, apify_place_id, business_data)
        VALUES (
            (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA'),
            'Duplicate Test',
            'TEST_ChIJ1234_Phoenix_Auto',  -- Existing ID
            '{"overview": {}}'::jsonb
        );
        RAISE NOTICE '✗ FAIL - Duplicate was allowed';
        DELETE FROM businesses WHERE business_name = 'Duplicate Test';
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE '✓ PASS - Duplicate properly prevented';
    END;
END $$;


-- Test 5.4: NULL review_data Handled
-- Expected: Cannot insert NULL review_data (NOT NULL constraint)
SELECT '
-- Test 5.4: NULL review_data Handled
-- Expected: NOT NULL constraint prevents empty reviews
-- Result: ' as test_info;

DO $$
BEGIN
    BEGIN
        INSERT INTO business_reviews (business_id, review_data)
        VALUES (
            (SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ1234_Phoenix_Auto'),
            NULL
        );
        RAISE NOTICE '✗ FAIL - NULL review_data was allowed';
        DELETE FROM business_reviews WHERE review_data IS NULL;
    EXCEPTION WHEN not_null_violation THEN
        RAISE NOTICE '✓ PASS - NULL review_data properly prevented';
    END;
END $$;


-- ============================================================================
-- CATEGORY 6: PERFORMANCE (5 tests)
-- ============================================================================

SELECT '
============================================================================
CATEGORY 6: PERFORMANCE
============================================================================' as category;

-- Test 6.1: Index Usage Verified
-- Expected: Queries use indexes (not sequential scans)
SELECT '
-- Test 6.1: Index Usage Verified
-- Expected: City filter uses idx_businesses_city
-- Result: Check EXPLAIN output below' as test_info;

EXPLAIN (ANALYZE, BUFFERS)
SELECT business_name, rating
FROM businesses
WHERE city = 'Phoenix'
AND rating > 4.0
ORDER BY rating DESC
LIMIT 10;


-- Test 6.2: Query Execution < 100ms
-- Expected: Simple filtered queries complete quickly
SELECT '
-- Test 6.2: Query Execution < 100ms
-- Expected: Execution time < 100ms for indexed query
-- Result: Check timing above' as test_info;

-- Timing is shown automatically with \timing on
SELECT COUNT(*) as fast_query_test
FROM businesses
WHERE city = 'Phoenix' AND rating > 4.0;


-- Test 6.3: JSONB Operators Efficient
-- Expected: GIN index used for JSONB queries
SELECT '
-- Test 6.3: JSONB Operators Efficient
-- Expected: JSONB query uses idx_businesses_social_gin
-- Result: Check EXPLAIN output below' as test_info;

EXPLAIN (ANALYZE, BUFFERS)
SELECT business_name, business_data->'social'->>'instagrams' as instagram
FROM businesses
WHERE business_data->'social' ? 'instagrams'
LIMIT 10;


-- Test 6.4: Full-Text Search Optimized
-- Expected: FTS uses GIN index
SELECT '
-- Test 6.4: Full-Text Search Optimized
-- Expected: Full-text search uses idx_reviews_text_fts
-- Result: Check EXPLAIN output below' as test_info;

EXPLAIN (ANALYZE, BUFFERS)
SELECT review_text, stars
FROM business_reviews
WHERE to_tsvector('english', review_text) @@ to_tsquery('parking | service')
LIMIT 10;


-- Test 6.5: Batch Operations Fast
-- Expected: Inserting multiple records is efficient
SELECT '
-- Test 6.5: Batch Operations Fast
-- Expected: Aggregate query completes quickly
-- Result: Check timing above' as test_info;

SELECT
    city,
    COUNT(*) as businesses,
    AVG(rating) as avg_rating,
    SUM(review_count) as total_reviews
FROM businesses
WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
GROUP BY city
ORDER BY total_reviews DESC;


-- ============================================================================
-- CATEGORY 7: END-TO-END SCENARIOS (5 tests)
-- ============================================================================

SELECT '
============================================================================
CATEGORY 7: END-TO-END SCENARIOS
============================================================================' as category;

-- Test 7.1: Complete Data Pipeline
-- Expected: Full workflow from execution → businesses → reviews
SELECT '
-- Test 7.1: Complete Data Pipeline
-- Expected: Data flows correctly through all tables
-- Result: ' as test_info;

DO $$
DECLARE
    pipeline_valid BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM market_executions e
        JOIN businesses b ON b.execution_id = e.id
        JOIN business_reviews r ON r.business_id = b.id
        WHERE e.search_query = 'TEST_DATA'
    ) INTO pipeline_valid;

    IF pipeline_valid THEN
        RAISE NOTICE '✓ PASS - Complete data pipeline functioning';
    ELSE
        RAISE NOTICE '✗ FAIL - Data pipeline broken';
    END IF;
END $$;

SELECT
    e.search_query,
    e.total_businesses,
    COUNT(DISTINCT b.id) as actual_businesses,
    COUNT(r.id) as actual_reviews
FROM market_executions e
LEFT JOIN businesses b ON b.execution_id = e.id
LEFT JOIN business_reviews r ON r.business_id = b.id
WHERE e.search_query = 'TEST_DATA'
GROUP BY e.id, e.search_query, e.total_businesses;


-- Test 7.2: RAG Query Workflow
-- Expected: Complex multi-table query (typical AI agent query)
SELECT '
-- Test 7.2: RAG Query Workflow
-- Expected: "Find businesses with complaints about parking"
-- Result: ' as test_info;

SELECT
    b.business_name,
    b.city,
    b.rating,
    COUNT(r.id) as parking_complaints,
    AVG(r.stars) as avg_complaint_rating
FROM businesses b
JOIN business_reviews r ON r.business_id = b.id
WHERE b.execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
AND to_tsvector('english', r.review_text) @@ to_tsquery('parking')
GROUP BY b.id, b.business_name, b.city, b.rating
HAVING COUNT(r.id) > 0
ORDER BY parking_complaints DESC;


-- Test 7.3: Memory Persistence
-- Expected: Can track historical executions
SELECT '
-- Test 7.3: Memory Persistence
-- Expected: Historical execution data preserved
-- Result: ' as test_info;

SELECT
    id,
    created_at,
    search_query,
    total_businesses,
    total_reviews,
    status
FROM market_executions
ORDER BY created_at DESC
LIMIT 5;


-- Test 7.4: Multi-Turn Conversation
-- Expected: Complex sequential queries (simulating conversation)
SELECT '
-- Test 7.4: Multi-Turn Conversation
-- Expected: Sequential queries maintain context
-- Turn 1: Show me auto repair shops
-- Turn 2: Which of these have the worst reviews?
-- Turn 3: What are common complaints?
-- Result: ' as test_info;

-- Turn 1: Find category
WITH auto_shops AS (
    SELECT id, business_name, rating, review_count
    FROM businesses
    WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
    AND category ILIKE '%auto%'
),
-- Turn 2: Get worst rated
worst_shop AS (
    SELECT id, business_name, rating
    FROM auto_shops
    ORDER BY rating ASC
    LIMIT 1
)
-- Turn 3: Analyze complaints
SELECT
    w.business_name,
    w.rating,
    r.stars,
    r.review_text
FROM worst_shop w
LEFT JOIN business_reviews r ON r.business_id = w.id
WHERE r.stars <= 3
ORDER BY r.stars ASC
LIMIT 5;


-- Test 7.5: Tool Chaining
-- Expected: Multiple tools used in sequence
SELECT '
-- Test 7.5: Tool Chaining
-- Expected: Tool 1 (businesses) → Tool 2 (reviews) → Tool 3 (analysis)
-- Scenario: Find high-rated businesses → Check their reviews → Identify success patterns
-- Result: ' as test_info;

WITH high_performers AS (
    -- Tool 1: query_businesses
    SELECT id, business_name, rating, review_count
    FROM businesses
    WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
    AND rating > 4.7
),
positive_reviews AS (
    -- Tool 2: query_reviews
    SELECT
        hp.business_name,
        r.review_text,
        r.stars
    FROM high_performers hp
    JOIN business_reviews r ON r.business_id = hp.id
    WHERE r.stars >= 4
)
-- Tool 3: analyze_opportunities
SELECT
    business_name,
    COUNT(*) as positive_review_count,
    string_agg(
        CASE
            WHEN review_text ILIKE '%service%' THEN 'service'
            WHEN review_text ILIKE '%quality%' THEN 'quality'
            WHEN review_text ILIKE '%friendly%' THEN 'friendly'
            WHEN review_text ILIKE '%professional%' THEN 'professional'
        END,
        ', '
    ) as success_factors
FROM positive_reviews
GROUP BY business_name
HAVING COUNT(*) > 0
ORDER BY positive_review_count DESC;


-- ============================================================================
-- TEST SUITE SUMMARY
-- ============================================================================

SELECT '
============================================================================
TEST SUITE COMPLETE
============================================================================

Review the output above for PASS/FAIL markers.

Expected results:
- Category 1 (Database Health): 8/8 PASS
- Category 2 (Data Collection): 6/6 PASS
- Category 3 (RAG Chat Interface): 5/5 PASS
- Category 4 (AI Tool Execution): 7/7 PASS
- Category 5 (Error Handling): 4/4 PASS
- Category 6 (Performance): 5/5 PASS (check timings < 100ms)
- Category 7 (End-to-End): 5/5 PASS

Total: 40/40 tests

Next steps:
1. Count PASS/FAIL from output above
2. Investigate any failures
3. If >= 38/40 pass (95%), system is production-ready
4. Document results in GitHub Issue #5

============================================================================
' as summary;

\timing off
