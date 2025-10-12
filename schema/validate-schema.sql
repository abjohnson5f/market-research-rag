-- ============================================================================
-- Schema Validation Script
-- ============================================================================
-- Validates that all required database objects exist and are properly configured
-- Run after: 01-tables.sql and 02-indexes.sql
-- ============================================================================

\set ON_ERROR_STOP on
\set QUIET on

-- Store results in temporary table
CREATE TEMP TABLE validation_results (
    check_type TEXT,
    object_name TEXT,
    status TEXT,
    details TEXT
);

-- ============================================================================
-- TABLE VALIDATION
-- ============================================================================

\echo ''
\echo '========================================='
\echo 'VALIDATING TABLES'
\echo '========================================='
\echo ''

-- Check required tables
DO $$
DECLARE
    required_tables TEXT[] := ARRAY['market_executions', 'businesses', 'business_reviews'];
    tbl TEXT;
    table_exists BOOLEAN;
BEGIN
    FOREACH tbl IN ARRAY required_tables
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = tbl
        ) INTO table_exists;

        IF table_exists THEN
            INSERT INTO validation_results VALUES ('TABLE', tbl, 'PASS', 'Table exists');
        ELSE
            INSERT INTO validation_results VALUES ('TABLE', tbl, 'FAIL', 'Table missing');
        END IF;
    END LOOP;
END $$;

-- ============================================================================
-- COLUMN VALIDATION
-- ============================================================================

\echo 'Validating table columns...'

-- market_executions columns
DO $$
DECLARE
    required_columns TEXT[] := ARRAY['id', 'created_at', 'completed_at', 'status', 'search_query',
                                      'apify_dataset_id', 'total_businesses', 'total_reviews', 'notes'];
    col TEXT;
    column_exists BOOLEAN;
BEGIN
    FOREACH col IN ARRAY required_columns
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'market_executions'
              AND column_name = col
        ) INTO column_exists;

        IF NOT column_exists THEN
            INSERT INTO validation_results VALUES ('COLUMN', 'market_executions.' || col, 'FAIL', 'Column missing');
        END IF;
    END LOOP;
END $$;

-- businesses columns
DO $$
DECLARE
    required_columns TEXT[] := ARRAY['id', 'execution_id', 'business_name', 'search_string',
                                      'apify_place_id', 'business_data', 'city', 'category',
                                      'rating', 'review_count', 'website', 'phone',
                                      'created_at', 'updated_at'];
    col TEXT;
    column_exists BOOLEAN;
BEGIN
    FOREACH col IN ARRAY required_columns
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'businesses'
              AND column_name = col
        ) INTO column_exists;

        IF NOT column_exists THEN
            INSERT INTO validation_results VALUES ('COLUMN', 'businesses.' || col, 'FAIL', 'Column missing');
        END IF;
    END LOOP;
END $$;

-- business_reviews columns
DO $$
DECLARE
    required_columns TEXT[] := ARRAY['id', 'business_id', 'review_data', 'reviewer_name',
                                      'stars', 'review_text', 'published_at', 'created_at'];
    col TEXT;
    column_exists BOOLEAN;
BEGIN
    FOREACH col IN ARRAY required_columns
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'business_reviews'
              AND column_name = col
        ) INTO column_exists;

        IF NOT column_exists THEN
            INSERT INTO validation_results VALUES ('COLUMN', 'business_reviews.' || col, 'FAIL', 'Column missing');
        END IF;
    END LOOP;
END $$;

-- ============================================================================
-- CONSTRAINT VALIDATION
-- ============================================================================

\echo 'Validating constraints...'

-- Check foreign key constraints
DO $$
DECLARE
    fk_exists BOOLEAN;
BEGIN
    -- businesses.execution_id -> market_executions.id
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.constraint_column_usage ccu
            ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'businesses'
          AND tc.constraint_type = 'FOREIGN KEY'
          AND ccu.table_name = 'market_executions'
    ) INTO fk_exists;

    IF fk_exists THEN
        INSERT INTO validation_results VALUES ('FK', 'businesses.execution_id', 'PASS', 'Foreign key exists');
    ELSE
        INSERT INTO validation_results VALUES ('FK', 'businesses.execution_id', 'FAIL', 'Foreign key missing');
    END IF;

    -- business_reviews.business_id -> businesses.id
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints tc
        JOIN information_schema.constraint_column_usage ccu
            ON tc.constraint_name = ccu.constraint_name
        WHERE tc.table_name = 'business_reviews'
          AND tc.constraint_type = 'FOREIGN KEY'
          AND ccu.table_name = 'businesses'
    ) INTO fk_exists;

    IF fk_exists THEN
        INSERT INTO validation_results VALUES ('FK', 'business_reviews.business_id', 'PASS', 'Foreign key exists');
    ELSE
        INSERT INTO validation_results VALUES ('FK', 'business_reviews.business_id', 'FAIL', 'Foreign key missing');
    END IF;
END $$;

-- Check unique constraint on apify_place_id
DO $$
DECLARE
    unique_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'businesses'
          AND constraint_type = 'UNIQUE'
          AND constraint_name LIKE '%apify_place_id%'
    ) INTO unique_exists;

    IF unique_exists THEN
        INSERT INTO validation_results VALUES ('UNIQUE', 'businesses.apify_place_id', 'PASS', 'Unique constraint exists');
    ELSE
        INSERT INTO validation_results VALUES ('UNIQUE', 'businesses.apify_place_id', 'FAIL', 'Unique constraint missing');
    END IF;
END $$;

-- Check status constraint on market_executions
DO $$
DECLARE
    check_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM information_schema.constraint_column_usage
        WHERE table_name = 'market_executions'
          AND column_name = 'status'
    ) INTO check_exists;

    IF check_exists THEN
        INSERT INTO validation_results VALUES ('CHECK', 'market_executions.status', 'PASS', 'Check constraint exists');
    ELSE
        INSERT INTO validation_results VALUES ('CHECK', 'market_executions.status', 'FAIL', 'Check constraint missing');
    END IF;
END $$;

-- ============================================================================
-- INDEX VALIDATION
-- ============================================================================

\echo ''
\echo '========================================='
\echo 'VALIDATING INDEXES'
\echo '========================================='
\echo ''

-- Check required indexes
DO $$
DECLARE
    required_indexes TEXT[] := ARRAY[
        'idx_executions_created',
        'idx_executions_status',
        'idx_businesses_execution',
        'idx_businesses_city',
        'idx_businesses_category',
        'idx_businesses_rating',
        'idx_businesses_review_count',
        'idx_businesses_name_lower',
        'idx_businesses_city_rating',
        'idx_businesses_city_category',
        'idx_businesses_data_gin',
        'idx_businesses_overview_gin',
        'idx_businesses_social_gin',
        'idx_businesses_rating_gin',
        'idx_reviews_business',
        'idx_reviews_stars',
        'idx_reviews_date',
        'idx_reviews_text_fts',
        'idx_reviews_data_gin',
        'idx_reviews_business_stars'
    ];
    idx TEXT;
    index_exists BOOLEAN;
BEGIN
    FOREACH idx IN ARRAY required_indexes
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM pg_indexes
            WHERE schemaname = 'public' AND indexname = idx
        ) INTO index_exists;

        IF index_exists THEN
            INSERT INTO validation_results VALUES ('INDEX', idx, 'PASS', 'Index exists');
        ELSE
            INSERT INTO validation_results VALUES ('INDEX', idx, 'FAIL', 'Index missing');
        END IF;
    END LOOP;
END $$;

-- ============================================================================
-- TRIGGER VALIDATION
-- ============================================================================

\echo ''
\echo '========================================='
\echo 'VALIDATING TRIGGERS'
\echo '========================================='
\echo ''

-- Check required triggers
DO $$
DECLARE
    required_triggers TEXT[] := ARRAY[
        'update_businesses_updated_at',
        'update_stats_on_business_insert',
        'update_stats_on_review_insert'
    ];
    trg TEXT;
    trigger_exists BOOLEAN;
BEGIN
    FOREACH trg IN ARRAY required_triggers
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.triggers
            WHERE trigger_schema = 'public' AND trigger_name = trg
        ) INTO trigger_exists;

        IF trigger_exists THEN
            INSERT INTO validation_results VALUES ('TRIGGER', trg, 'PASS', 'Trigger exists');
        ELSE
            INSERT INTO validation_results VALUES ('TRIGGER', trg, 'FAIL', 'Trigger missing');
        END IF;
    END LOOP;
END $$;

-- ============================================================================
-- FUNCTION VALIDATION
-- ============================================================================

\echo 'Validating functions...'

-- Check required functions
DO $$
DECLARE
    required_functions TEXT[] := ARRAY[
        'update_updated_at_column',
        'update_execution_stats'
    ];
    func TEXT;
    function_exists BOOLEAN;
BEGIN
    FOREACH func IN ARRAY required_functions
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM pg_proc
            JOIN pg_namespace ON pg_proc.pronamespace = pg_namespace.oid
            WHERE pg_namespace.nspname = 'public'
              AND pg_proc.proname = func
        ) INTO function_exists;

        IF function_exists THEN
            INSERT INTO validation_results VALUES ('FUNCTION', func, 'PASS', 'Function exists');
        ELSE
            INSERT INTO validation_results VALUES ('FUNCTION', func, 'FAIL', 'Function missing');
        END IF;
    END LOOP;
END $$;

-- ============================================================================
-- VIEW VALIDATION
-- ============================================================================

\echo ''
\echo '========================================='
\echo 'VALIDATING VIEWS'
\echo '========================================='
\echo ''

-- Check required views
DO $$
DECLARE
    required_views TEXT[] := ARRAY['business_summary', 'recent_executions'];
    vw TEXT;
    view_exists BOOLEAN;
BEGIN
    FOREACH vw IN ARRAY required_views
    LOOP
        SELECT EXISTS (
            SELECT 1 FROM information_schema.views
            WHERE table_schema = 'public' AND table_name = vw
        ) INTO view_exists;

        IF view_exists THEN
            INSERT INTO validation_results VALUES ('VIEW', vw, 'PASS', 'View exists');
        ELSE
            INSERT INTO validation_results VALUES ('VIEW', vw, 'FAIL', 'View missing');
        END IF;
    END LOOP;
END $$;

-- ============================================================================
-- GENERATED COLUMN VALIDATION
-- ============================================================================

\echo 'Validating generated columns...'

-- Verify generated columns are properly configured
DO $$
DECLARE
    generated_count INT;
BEGIN
    -- Check businesses generated columns
    SELECT COUNT(*) INTO generated_count
    FROM information_schema.columns
    WHERE table_name = 'businesses'
      AND is_generated = 'ALWAYS'
      AND column_name IN ('city', 'category', 'rating', 'review_count', 'website', 'phone');

    IF generated_count = 6 THEN
        INSERT INTO validation_results VALUES ('GENERATED', 'businesses', 'PASS', '6 generated columns configured');
    ELSE
        INSERT INTO validation_results VALUES ('GENERATED', 'businesses', 'FAIL',
            'Expected 6 generated columns, found ' || generated_count);
    END IF;

    -- Check business_reviews generated columns
    SELECT COUNT(*) INTO generated_count
    FROM information_schema.columns
    WHERE table_name = 'business_reviews'
      AND is_generated = 'ALWAYS'
      AND column_name IN ('reviewer_name', 'stars', 'review_text', 'published_at');

    IF generated_count = 4 THEN
        INSERT INTO validation_results VALUES ('GENERATED', 'business_reviews', 'PASS', '4 generated columns configured');
    ELSE
        INSERT INTO validation_results VALUES ('GENERATED', 'business_reviews', 'FAIL',
            'Expected 4 generated columns, found ' || generated_count);
    END IF;
END $$;

-- ============================================================================
-- DISPLAY RESULTS
-- ============================================================================

\echo ''
\echo '========================================='
\echo 'VALIDATION RESULTS SUMMARY'
\echo '========================================='
\echo ''

\set QUIET off

-- Display all results
SELECT
    check_type,
    object_name,
    status,
    details
FROM validation_results
ORDER BY
    CASE check_type
        WHEN 'TABLE' THEN 1
        WHEN 'COLUMN' THEN 2
        WHEN 'FK' THEN 3
        WHEN 'UNIQUE' THEN 4
        WHEN 'CHECK' THEN 5
        WHEN 'INDEX' THEN 6
        WHEN 'TRIGGER' THEN 7
        WHEN 'FUNCTION' THEN 8
        WHEN 'VIEW' THEN 9
        WHEN 'GENERATED' THEN 10
        ELSE 99
    END,
    object_name;

-- Summary counts
\echo ''
\echo '========================================='
\echo 'VALIDATION SUMMARY'
\echo '========================================='

SELECT
    check_type,
    COUNT(*) FILTER (WHERE status = 'PASS') as passed,
    COUNT(*) FILTER (WHERE status = 'FAIL') as failed,
    COUNT(*) as total
FROM validation_results
GROUP BY check_type
ORDER BY
    CASE check_type
        WHEN 'TABLE' THEN 1
        WHEN 'COLUMN' THEN 2
        WHEN 'FK' THEN 3
        WHEN 'UNIQUE' THEN 4
        WHEN 'CHECK' THEN 5
        WHEN 'INDEX' THEN 6
        WHEN 'TRIGGER' THEN 7
        WHEN 'FUNCTION' THEN 8
        WHEN 'VIEW' THEN 9
        WHEN 'GENERATED' THEN 10
        ELSE 99
    END;

-- Overall result
\echo ''
\echo '========================================='
\echo 'OVERALL VALIDATION STATUS'
\echo '========================================='

DO $$
DECLARE
    failure_count INT;
BEGIN
    SELECT COUNT(*) INTO failure_count
    FROM validation_results
    WHERE status = 'FAIL';

    IF failure_count = 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '✓ ALL CHECKS PASSED';
        RAISE NOTICE '';
        RAISE NOTICE 'Schema validation: SUCCESSFUL';
        RAISE NOTICE 'All required tables, indexes, triggers, views, and functions are present.';
        RAISE NOTICE '';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '✗ VALIDATION FAILED';
        RAISE NOTICE '';
        RAISE NOTICE 'Schema validation: FAILED';
        RAISE NOTICE 'Found % failed check(s). Review results above.', failure_count;
        RAISE NOTICE '';
        RAISE EXCEPTION 'Schema validation failed with % errors', failure_count;
    END IF;
END $$;

-- Clean up
DROP TABLE validation_results;

\echo ''
\echo 'Validation complete!'
\echo ''
