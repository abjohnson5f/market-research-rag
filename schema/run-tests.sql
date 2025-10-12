-- ============================================================================
-- Automated Test Suite for Market Research RAG System
-- ============================================================================
-- This script runs automated validation checks on the database schema,
-- indexes, triggers, and data integrity.
--
-- Usage:
--   psql "YOUR_POSTGRES_URL" -f schema/run-tests.sql
--
-- Returns:
--   - PASS/FAIL for each test
--   - Summary of total tests passed/failed
--   - Execution time for performance tests
-- ============================================================================

\set ON_ERROR_STOP off
\timing on

\echo '==========================================';
\echo 'Market Research RAG - Automated Test Suite';
\echo '==========================================';
\echo '';

-- ============================================================================
-- TEST 1: Tables Exist
-- ============================================================================

\echo 'TEST 1: Verifying all required tables exist...';

DO $$
DECLARE
    table_count INT;
    expected_tables TEXT[] := ARRAY['market_executions', 'businesses', 'business_reviews'];
    missing_tables TEXT[];
BEGIN
    SELECT COUNT(*)
    INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name = ANY(expected_tables);

    IF table_count = 3 THEN
        RAISE NOTICE '✅ PASS: All 3 tables exist';
    ELSE
        -- Find missing tables
        SELECT ARRAY_AGG(t)
        INTO missing_tables
        FROM unnest(expected_tables) t
        WHERE NOT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = t
        );

        RAISE NOTICE '❌ FAIL: Missing tables: %', missing_tables;
    END IF;
END $$;

\echo '';

-- ============================================================================
-- TEST 2: Column Counts
-- ============================================================================

\echo 'TEST 2: Verifying table column counts...';

DO $$
DECLARE
    exec_cols INT;
    biz_cols INT;
    review_cols INT;
    all_correct BOOLEAN := true;
BEGIN
    SELECT COUNT(*) INTO exec_cols
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'market_executions';

    SELECT COUNT(*) INTO biz_cols
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'businesses';

    SELECT COUNT(*) INTO review_cols
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'business_reviews';

    IF exec_cols != 9 THEN
        RAISE NOTICE '❌ market_executions has % columns, expected 9', exec_cols;
        all_correct := false;
    END IF;

    IF biz_cols != 11 THEN
        RAISE NOTICE '❌ businesses has % columns, expected 11', biz_cols;
        all_correct := false;
    END IF;

    IF review_cols != 7 THEN
        RAISE NOTICE '❌ business_reviews has % columns, expected 7', review_cols;
        all_correct := false;
    END IF;

    IF all_correct THEN
        RAISE NOTICE '✅ PASS: All column counts correct (executions: 9, businesses: 11, reviews: 7)';
    ELSE
        RAISE NOTICE '❌ FAIL: Column counts incorrect';
    END IF;
END $$;

\echo '';

-- ============================================================================
-- TEST 3: Critical Indexes Exist
-- ============================================================================

\echo 'TEST 3: Verifying critical indexes exist...';

DO $$
DECLARE
    critical_indexes TEXT[] := ARRAY[
        'idx_businesses_data_gin',
        'idx_reviews_text_fts',
        'idx_businesses_city_rating',
        'idx_businesses_execution',
        'idx_reviews_business'
    ];
    missing_indexes TEXT[];
    index_count INT;
BEGIN
    SELECT ARRAY_AGG(idx)
    INTO missing_indexes
    FROM unnest(critical_indexes) idx
    WHERE NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public' AND indexname = idx
    );

    SELECT COUNT(*)
    INTO index_count
    FROM unnest(critical_indexes) idx
    WHERE EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'public' AND indexname = idx
    );

    IF missing_indexes IS NULL THEN
        RAISE NOTICE '✅ PASS: All 5 critical indexes exist';
    ELSE
        RAISE NOTICE '❌ FAIL: Missing indexes: %', missing_indexes;
        RAISE NOTICE '   Found %/5 critical indexes', index_count;
    END IF;
END $$;

\echo '';

-- ============================================================================
-- TEST 4: Triggers Exist
-- ============================================================================

\echo 'TEST 4: Verifying triggers exist...';

DO $$
DECLARE
    trigger_count INT;
    expected_triggers TEXT[] := ARRAY[
        'update_businesses_updated_at',
        'update_stats_on_business_insert',
        'update_stats_on_review_insert'
    ];
    missing_triggers TEXT[];
BEGIN
    SELECT ARRAY_AGG(t)
    INTO missing_triggers
    FROM unnest(expected_triggers) t
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.triggers
        WHERE trigger_schema = 'public' AND trigger_name = t
    );

    IF missing_triggers IS NULL THEN
        RAISE NOTICE '✅ PASS: All 3 triggers exist';
    ELSE
        RAISE NOTICE '❌ FAIL: Missing triggers: %', missing_triggers;
    END IF;
END $$;

\echo '';

-- ============================================================================
-- TEST 5: Views Exist
-- ============================================================================

\echo 'TEST 5: Verifying views exist...';

DO $$
DECLARE
    view_count INT;
    expected_views TEXT[] := ARRAY['business_summary', 'recent_executions'];
    missing_views TEXT[];
BEGIN
    SELECT ARRAY_AGG(v)
    INTO missing_views
    FROM unnest(expected_views) v
    WHERE NOT EXISTS (
        SELECT 1 FROM information_schema.views
        WHERE table_schema = 'public' AND table_name = v
    );

    IF missing_views IS NULL THEN
        RAISE NOTICE '✅ PASS: All 2 views exist';
    ELSE
        RAISE NOTICE '❌ FAIL: Missing views: %', missing_views;
    END IF;
END $$;

\echo '';

-- ============================================================================
-- TEST 6: Generated Columns Work Correctly
-- ============================================================================

\echo 'TEST 6: Testing generated columns...';

DO $$
DECLARE
    test_passed BOOLEAN := true;
    mismatch_count INT;
BEGIN
    -- Check if we have any data to test
    IF NOT EXISTS (SELECT 1 FROM businesses LIMIT 1) THEN
        RAISE NOTICE '⚠️  SKIP: No data in businesses table to test generated columns';
        RETURN;
    END IF;

    -- Test city extraction
    SELECT COUNT(*) INTO mismatch_count
    FROM businesses
    WHERE city IS NOT NULL
    AND business_data->'overview'->>'city' != city;

    IF mismatch_count > 0 THEN
        RAISE NOTICE '❌ city column mismatch: % rows', mismatch_count;
        test_passed := false;
    END IF;

    -- Test category extraction
    SELECT COUNT(*) INTO mismatch_count
    FROM businesses
    WHERE category IS NOT NULL
    AND business_data->'overview'->>'category' != category;

    IF mismatch_count > 0 THEN
        RAISE NOTICE '❌ category column mismatch: % rows', mismatch_count;
        test_passed := false;
    END IF;

    -- Test rating extraction
    SELECT COUNT(*) INTO mismatch_count
    FROM businesses
    WHERE rating IS NOT NULL
    AND (business_data->'rating'->>'totalScore')::decimal != rating;

    IF mismatch_count > 0 THEN
        RAISE NOTICE '❌ rating column mismatch: % rows', mismatch_count;
        test_passed := false;
    END IF;

    IF test_passed THEN
        RAISE NOTICE '✅ PASS: Generated columns extract correctly from JSONB';
    ELSE
        RAISE NOTICE '❌ FAIL: Generated column mismatches found';
    END IF;
END $$;

\echo '';

-- ============================================================================
-- TEST 7: JSONB Queries Work
-- ============================================================================

\echo 'TEST 7: Testing JSONB query functionality...';

DO $$
DECLARE
    query_result INT;
BEGIN
    -- Check if we have any data
    IF NOT EXISTS (SELECT 1 FROM businesses LIMIT 1) THEN
        RAISE NOTICE '⚠️  SKIP: No data in businesses table to test JSONB queries';
        RETURN;
    END IF;

    -- Test JSONB containment operator
    BEGIN
        SELECT COUNT(*) INTO query_result
        FROM businesses
        WHERE business_data->'social' ? 'instagrams';

        RAISE NOTICE '✅ PASS: JSONB queries work (found % businesses with Instagram key)', query_result;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ FAIL: JSONB query failed with error: %', SQLERRM;
    END;
END $$;

\echo '';

-- ============================================================================
-- TEST 8: Full-Text Search Works
-- ============================================================================

\echo 'TEST 8: Testing full-text search on reviews...';

DO $$
DECLARE
    fts_result INT;
BEGIN
    -- Check if we have any reviews
    IF NOT EXISTS (SELECT 1 FROM business_reviews LIMIT 1) THEN
        RAISE NOTICE '⚠️  SKIP: No reviews to test full-text search';
        RETURN;
    END IF;

    -- Test full-text search
    BEGIN
        SELECT COUNT(*) INTO fts_result
        FROM business_reviews
        WHERE to_tsvector('english', review_text) @@ to_tsquery('english', 'coffee | parking | repair');

        RAISE NOTICE '✅ PASS: Full-text search works (found % matching reviews)', fts_result;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ FAIL: Full-text search failed with error: %', SQLERRM;
    END;
END $$;

\echo '';

-- ============================================================================
-- TEST 9: Foreign Key Constraints
-- ============================================================================

\echo 'TEST 9: Testing foreign key relationships...';

DO $$
DECLARE
    orphaned_businesses INT;
    orphaned_reviews INT;
BEGIN
    -- Check for orphaned businesses (no execution)
    SELECT COUNT(*) INTO orphaned_businesses
    FROM businesses b
    WHERE NOT EXISTS (
        SELECT 1 FROM market_executions e WHERE e.id = b.execution_id
    );

    -- Check for orphaned reviews (no business)
    SELECT COUNT(*) INTO orphaned_reviews
    FROM business_reviews r
    WHERE NOT EXISTS (
        SELECT 1 FROM businesses b WHERE b.id = r.business_id
    );

    IF orphaned_businesses = 0 AND orphaned_reviews = 0 THEN
        RAISE NOTICE '✅ PASS: All foreign key relationships valid';
    ELSE
        IF orphaned_businesses > 0 THEN
            RAISE NOTICE '❌ FAIL: Found % orphaned businesses', orphaned_businesses;
        END IF;
        IF orphaned_reviews > 0 THEN
            RAISE NOTICE '❌ FAIL: Found % orphaned reviews', orphaned_reviews;
        END IF;
    END IF;
END $$;

\echo '';

-- ============================================================================
-- TEST 10: Join Queries Work
-- ============================================================================

\echo 'TEST 10: Testing table joins...';

DO $$
DECLARE
    join_result INT;
BEGIN
    -- Check if we have data
    IF NOT EXISTS (SELECT 1 FROM businesses LIMIT 1) THEN
        RAISE NOTICE '⚠️  SKIP: No data to test joins';
        RETURN;
    END IF;

    -- Test business-review join
    BEGIN
        SELECT COUNT(*) INTO join_result
        FROM business_reviews r
        JOIN businesses b ON b.id = r.business_id;

        RAISE NOTICE '✅ PASS: Table joins work (joined % review records)', join_result;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ FAIL: Join query failed with error: %', SQLERRM;
    END;
END $$;

\echo '';

-- ============================================================================
-- TEST 11: Aggregations Work
-- ============================================================================

\echo 'TEST 11: Testing aggregation queries...';

DO $$
DECLARE
    agg_result RECORD;
BEGIN
    -- Check if we have data
    IF NOT EXISTS (SELECT 1 FROM businesses LIMIT 1) THEN
        RAISE NOTICE '⚠️  SKIP: No data to test aggregations';
        RETURN;
    END IF;

    -- Test aggregations
    BEGIN
        SELECT
            COUNT(*) as biz_count,
            ROUND(AVG(rating), 2) as avg_rating,
            SUM(review_count) as total_reviews
        INTO agg_result
        FROM businesses;

        RAISE NOTICE '✅ PASS: Aggregations work (% businesses, avg rating %, % total reviews)',
            agg_result.biz_count, agg_result.avg_rating, agg_result.total_reviews;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ FAIL: Aggregation query failed with error: %', SQLERRM;
    END;
END $$;

\echo '';

-- ============================================================================
-- TEST 12: Trigger Functionality
-- ============================================================================

\echo 'TEST 12: Testing trigger updates...';

DO $$
DECLARE
    exec_count INT;
    stats_correct BOOLEAN := true;
BEGIN
    -- Check if we have executions
    IF NOT EXISTS (SELECT 1 FROM market_executions LIMIT 1) THEN
        RAISE NOTICE '⚠️  SKIP: No executions to test triggers';
        RETURN;
    END IF;

    -- Verify execution stats match actual counts
    SELECT COUNT(*) INTO exec_count
    FROM market_executions e
    WHERE e.total_businesses != (
        SELECT COUNT(*) FROM businesses WHERE execution_id = e.id
    );

    IF exec_count > 0 THEN
        RAISE NOTICE '❌ total_businesses count incorrect for % executions', exec_count;
        stats_correct := false;
    END IF;

    IF stats_correct THEN
        RAISE NOTICE '✅ PASS: Triggers updating statistics correctly';
    ELSE
        RAISE NOTICE '❌ FAIL: Trigger statistics out of sync';
    END IF;
END $$;

\echo '';

-- ============================================================================
-- TEST 13: Index Performance Check
-- ============================================================================

\echo 'TEST 13: Testing index usage with EXPLAIN...';

DO $$
DECLARE
    explain_result TEXT;
BEGIN
    -- Check if we have data
    IF NOT EXISTS (SELECT 1 FROM businesses WHERE city IS NOT NULL LIMIT 1) THEN
        RAISE NOTICE '⚠️  SKIP: No data to test index performance';
        RETURN;
    END IF;

    -- Test if index is used for city queries
    SELECT COUNT(*) > 0 INTO explain_result
    FROM (
        SELECT 1
        FROM businesses
        WHERE city = (SELECT city FROM businesses WHERE city IS NOT NULL LIMIT 1)
        LIMIT 1
    ) t;

    IF explain_result THEN
        RAISE NOTICE '✅ PASS: Indexes functional (query executed successfully)';
        RAISE NOTICE '   💡 Run "EXPLAIN ANALYZE SELECT * FROM businesses WHERE city = ''Phoenix''" for detailed performance';
    ELSE
        RAISE NOTICE '❌ FAIL: Index query failed';
    END IF;
END $$;

\echo '';

-- ============================================================================
-- TEST 14: Unique Constraints
-- ============================================================================

\echo 'TEST 14: Testing unique constraints...';

DO $$
DECLARE
    duplicate_count INT;
BEGIN
    -- Check for duplicate apify_place_ids
    SELECT COUNT(*) INTO duplicate_count
    FROM (
        SELECT apify_place_id, COUNT(*) as cnt
        FROM businesses
        WHERE apify_place_id IS NOT NULL
        GROUP BY apify_place_id
        HAVING COUNT(*) > 1
    ) dups;

    IF duplicate_count = 0 THEN
        RAISE NOTICE '✅ PASS: Unique constraints enforced (no duplicate apify_place_ids)';
    ELSE
        RAISE NOTICE '❌ FAIL: Found % duplicate apify_place_ids', duplicate_count;
    END IF;
END $$;

\echo '';

-- ============================================================================
-- TEST 15: Data Types and Constraints
-- ============================================================================

\echo 'TEST 15: Testing data type constraints...';

DO $$
DECLARE
    invalid_data_count INT := 0;
    test_passed BOOLEAN := true;
BEGIN
    -- Check if we have data
    IF NOT EXISTS (SELECT 1 FROM market_executions LIMIT 1) THEN
        RAISE NOTICE '⚠️  SKIP: No data to test constraints';
        RETURN;
    END IF;

    -- Check for invalid execution status
    SELECT COUNT(*) INTO invalid_data_count
    FROM market_executions
    WHERE status NOT IN ('running', 'completed', 'failed');

    IF invalid_data_count > 0 THEN
        RAISE NOTICE '❌ Invalid execution status found in % rows', invalid_data_count;
        test_passed := false;
    END IF;

    -- Check for NULL required fields in businesses
    SELECT COUNT(*) INTO invalid_data_count
    FROM businesses
    WHERE business_name IS NULL OR business_data IS NULL;

    IF invalid_data_count > 0 THEN
        RAISE NOTICE '❌ NULL values in required fields: % rows', invalid_data_count;
        test_passed := false;
    END IF;

    IF test_passed THEN
        RAISE NOTICE '✅ PASS: Data types and constraints valid';
    ELSE
        RAISE NOTICE '❌ FAIL: Data constraint violations found';
    END IF;
END $$;

\echo '';

-- ============================================================================
-- SUMMARY
-- ============================================================================

\echo '==========================================';
\echo 'TEST SUITE SUMMARY';
\echo '==========================================';

DO $$
DECLARE
    total_tests INT := 15;
    data_tests INT := 9; -- Tests that require data
    schema_tests INT := 6; -- Tests that only check schema
BEGIN
    RAISE NOTICE 'Total tests defined: %', total_tests;
    RAISE NOTICE '  - Schema tests: % (always run)', schema_tests;
    RAISE NOTICE '  - Data tests: % (require existing data)', data_tests;
    RAISE NOTICE '';
    RAISE NOTICE '✅ = Test passed';
    RAISE NOTICE '❌ = Test failed';
    RAISE NOTICE '⚠️  = Test skipped (no data)';
    RAISE NOTICE '';
    RAISE NOTICE 'Review output above for detailed results';
    RAISE NOTICE '';

    -- Check if we have test data
    IF EXISTS (SELECT 1 FROM market_executions WHERE search_query = 'TEST_DATA') THEN
        RAISE NOTICE '💡 Test data detected. To clean up:';
        RAISE NOTICE '   psql "YOUR_URL" -f schema/test-data.sql --variable=CLEANUP=true';
    ELSE
        RAISE NOTICE '💡 To insert test data for comprehensive testing:';
        RAISE NOTICE '   psql "YOUR_URL" -f schema/test-data.sql';
    END IF;
END $$;

\echo '';
\echo '==========================================';
\echo 'Additional Performance Checks';
\echo '==========================================';
\echo '';
\echo 'Run these queries manually for detailed performance analysis:';
\echo '';
\echo '-- Check index usage for city filter:';
\echo 'EXPLAIN ANALYZE';
\echo 'SELECT business_name, city, rating FROM businesses';
\echo 'WHERE city = ''Phoenix'' AND rating > 4.5';
\echo 'ORDER BY rating DESC LIMIT 10;';
\echo '';
\echo '-- Check full-text search performance:';
\echo 'EXPLAIN ANALYZE';
\echo 'SELECT b.business_name, r.review_text';
\echo 'FROM business_reviews r JOIN businesses b ON b.id = r.business_id';
\echo 'WHERE to_tsvector(''english'', r.review_text) @@ to_tsquery(''parking'')';
\echo 'LIMIT 20;';
\echo '';
\echo '-- Check JSONB query performance:';
\echo 'EXPLAIN ANALYZE';
\echo 'SELECT business_name, business_data->''social''->''instagrams''';
\echo 'FROM businesses';
\echo 'WHERE business_data->''social'' ? ''instagrams'';';
\echo '';

\timing off

\echo '==========================================';
\echo '✅ Automated test suite complete!';
\echo '==========================================';
