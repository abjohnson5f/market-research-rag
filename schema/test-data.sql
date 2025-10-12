-- ============================================================================
-- Test Data for Market Research RAG System
-- ============================================================================
-- This script inserts sample test data for system validation
--
-- Usage:
--   Insert test data:  psql "YOUR_URL" -f test-data.sql
--   Cleanup test data: psql "YOUR_URL" -f test-data.sql --variable=CLEANUP=true
--
-- Creates:
--   - 1 test execution record
--   - 5 test businesses (varied scenarios)
--   - 10 test reviews (mix of ratings and sentiments)
-- ============================================================================

\set ON_ERROR_STOP on

-- ============================================================================
-- CLEANUP MODE (if --variable=CLEANUP=true)
-- ============================================================================

DO $$
BEGIN
    IF current_setting('CLEANUP', true) = 'true' THEN
        RAISE NOTICE 'CLEANUP MODE: Removing test data...';

        -- Delete test data (CASCADE will handle reviews and businesses)
        DELETE FROM market_executions
        WHERE search_query = 'TEST_DATA'
        AND apify_dataset_id = 'test_dataset_123';

        RAISE NOTICE '✓ Test data removed successfully';
        RAISE EXCEPTION 'CLEANUP_COMPLETE'; -- Exit script after cleanup
    END IF;
END $$;

-- ============================================================================
-- INSERT MODE (default)
-- ============================================================================

BEGIN;

RAISE NOTICE 'Inserting test data...';

-- ============================================================================
-- 1. Create Test Execution Record
-- ============================================================================

INSERT INTO market_executions (
    created_at,
    completed_at,
    status,
    search_query,
    apify_dataset_id,
    total_businesses,
    total_reviews,
    notes
) VALUES (
    NOW() - INTERVAL '1 hour',
    NOW() - INTERVAL '55 minutes',
    'completed',
    'TEST_DATA',
    'test_dataset_123',
    5,  -- Will be updated by triggers
    10, -- Will be updated by triggers
    'Automated test data insertion'
) RETURNING id AS test_execution_id \gset

RAISE NOTICE '✓ Created test execution record (ID: %)', :'test_execution_id';

-- ============================================================================
-- 2. Insert Test Businesses
-- ============================================================================

-- Business 1: High-rated coffee shop with Instagram
INSERT INTO businesses (
    execution_id,
    business_name,
    search_string,
    apify_place_id,
    business_data
) VALUES (
    :'test_execution_id',
    'Sunrise Coffee Roasters',
    'coffee shops in Phoenix',
    'test_place_001',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'city', 'Phoenix',
            'category', 'Coffee Shop',
            'address', '123 Main St, Phoenix, AZ 85001',
            'isAdvertisement', false
        ),
        'contact', jsonb_build_object(
            'website', 'https://sunrisecoffee.example.com',
            'phone', '+1-602-555-0101',
            'emails', ARRAY['info@sunrisecoffee.example.com'],
            'latitude', 33.4484,
            'longitude', -112.0740
        ),
        'social', jsonb_build_object(
            'instagrams', 'https://instagram.com/sunrisecoffeephx',
            'facebooks', 'https://facebook.com/sunrisecoffee'
        ),
        'rating', jsonb_build_object(
            'totalScore', 4.8,
            'reviewsCount', 245,
            'stars', jsonb_build_object(
                '5', 180,
                '4', 45,
                '3', 15,
                '2', 3,
                '1', 2
            )
        ),
        'tags', ARRAY['Specialty Coffee', 'Espresso', 'Pastries', 'WiFi']
    )
);

-- Business 2: Low-rated auto repair (trust issues)
INSERT INTO businesses (
    execution_id,
    business_name,
    search_string,
    apify_place_id,
    business_data
) VALUES (
    :'test_execution_id',
    'QuickFix Auto Repair',
    'auto repair in Phoenix',
    'test_place_002',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'city', 'Phoenix',
            'category', 'Auto Repair',
            'address', '456 Industrial Blvd, Phoenix, AZ 85003',
            'isAdvertisement', false
        ),
        'contact', jsonb_build_object(
            'website', 'https://quickfixauto.example.com',
            'phone', '+1-602-555-0102',
            'latitude', 33.4502,
            'longitude', -112.0726
        ),
        'social', jsonb_build_object(),
        'rating', jsonb_build_object(
            'totalScore', 3.2,
            'reviewsCount', 89,
            'stars', jsonb_build_object(
                '5', 20,
                '4', 15,
                '3', 10,
                '2', 22,
                '1', 22
            )
        ),
        'tags', ARRAY['Oil Change', 'Brake Service', 'Engine Repair']
    )
);

-- Business 3: New restaurant with few reviews (underserved opportunity)
INSERT INTO businesses (
    execution_id,
    business_name,
    search_string,
    apify_place_id,
    business_data
) VALUES (
    :'test_execution_id',
    'The Green Bistro',
    'restaurants in Seattle',
    'test_place_003',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'city', 'Seattle',
            'category', 'Restaurant',
            'address', '789 Pine St, Seattle, WA 98101',
            'isAdvertisement', false
        ),
        'contact', jsonb_build_object(
            'website', 'https://greenbistro.example.com',
            'phone', '+1-206-555-0103',
            'emails', ARRAY['reservations@greenbistro.example.com'],
            'latitude', 47.6062,
            'longitude', -122.3321
        ),
        'social', jsonb_build_object(
            'instagrams', 'https://instagram.com/greenbistro',
            'facebooks', 'https://facebook.com/greenbistro'
        ),
        'rating', jsonb_build_object(
            'totalScore', 4.9,
            'reviewsCount', 18,
            'stars', jsonb_build_object(
                '5', 16,
                '4', 2,
                '3', 0,
                '2', 0,
                '1', 0
            )
        ),
        'tags', ARRAY['Farm-to-Table', 'Organic', 'Vegetarian Options', 'Wine Bar']
    )
);

-- Business 4: Bookstore with no social media (engagement gap)
INSERT INTO businesses (
    execution_id,
    business_name,
    search_string,
    apify_place_id,
    business_data
) VALUES (
    :'test_execution_id',
    'Capitol Hill Books',
    'bookstores in Seattle',
    'test_place_004',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'city', 'Seattle',
            'category', 'Bookstore',
            'address', '321 Broadway E, Seattle, WA 98102',
            'isAdvertisement', false
        ),
        'contact', jsonb_build_object(
            'website', 'https://capitolhillbooks.example.com',
            'phone', '+1-206-555-0104',
            'latitude', 47.6205,
            'longitude', -122.3212
        ),
        'social', jsonb_build_object(),
        'rating', jsonb_build_object(
            'totalScore', 4.6,
            'reviewsCount', 127,
            'stars', jsonb_build_object(
                '5', 85,
                '4', 30,
                '3', 8,
                '2', 3,
                '1', 1
            )
        ),
        'tags', ARRAY['Independent Bookstore', 'Used Books', 'Rare Books', 'Events']
    )
);

-- Business 5: Brewery with edge cases (special characters, missing data)
INSERT INTO businesses (
    execution_id,
    business_name,
    search_string,
    apify_place_id,
    business_data
) VALUES (
    :'test_execution_id',
    'Mile High Brewing Co.',
    'breweries in Denver',
    'test_place_005',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'city', 'Denver',
            'category', 'Brewery',
            'address', '555 Blake St, Denver, CO 80202',
            'isAdvertisement', false
        ),
        'contact', jsonb_build_object(
            'phone', '+1-303-555-0105',
            'latitude', 39.7539,
            'longitude', -104.9967
        ),
        'social', jsonb_build_object(
            'instagrams', 'https://instagram.com/milehighbrewing'
        ),
        'rating', jsonb_build_object(
            'totalScore', 4.4,
            'reviewsCount', 312,
            'stars', jsonb_build_object(
                '5', 180,
                '4', 90,
                '3', 25,
                '2', 10,
                '1', 7
            )
        ),
        'tags', ARRAY['Craft Beer', 'IPA', 'Food Trucks', 'Live Music']
    )
);

RAISE NOTICE '✓ Inserted 5 test businesses';

-- ============================================================================
-- 3. Insert Test Reviews
-- ============================================================================

-- Reviews for Sunrise Coffee Roasters (mostly positive)
INSERT INTO business_reviews (business_id, review_data) VALUES
(
    (SELECT id FROM businesses WHERE apify_place_id = 'test_place_001'),
    jsonb_build_object(
        'reviewerName', 'Sarah M.',
        'stars', 5,
        'text', 'Best coffee in Phoenix! The espresso is perfectly balanced and the atmosphere is cozy. Great place to work with fast WiFi.',
        'publishedAtDate', '2025-01-15',
        'responseFromOwner', jsonb_build_object(
            'text', 'Thank you Sarah! We love having you here. See you soon!',
            'publishedAtDate', '2025-01-16'
        )
    )
),
(
    (SELECT id FROM businesses WHERE apify_place_id = 'test_place_001'),
    jsonb_build_object(
        'reviewerName', 'Mike D.',
        'stars', 4,
        'text', 'Great coffee, but parking can be challenging during morning rush. Still worth the visit!',
        'publishedAtDate', '2025-01-10'
    )
);

-- Reviews for QuickFix Auto Repair (trust issues - negative)
INSERT INTO business_reviews (business_id, review_data) VALUES
(
    (SELECT id FROM businesses WHERE apify_place_id = 'test_place_002'),
    jsonb_build_object(
        'reviewerName', 'John K.',
        'stars', 1,
        'text', 'Quoted $200 for brake job, charged $800 when I picked up the car. No explanation for the difference. Felt like a bait and switch. Would not recommend.',
        'publishedAtDate', '2025-01-12'
    )
),
(
    (SELECT id FROM businesses WHERE apify_place_id = 'test_place_002'),
    jsonb_build_object(
        'reviewerName', 'Lisa R.',
        'stars', 2,
        'text', 'Car broke down again 3 days after $600 repair. They said it was a different issue but I have my doubts. Poor communication throughout.',
        'publishedAtDate', '2025-01-08'
    )
),
(
    (SELECT id FROM businesses WHERE apify_place_id = 'test_place_002'),
    jsonb_build_object(
        'reviewerName', 'David P.',
        'stars', 1,
        'text', 'Was told I needed transmission work ($2000+). Got a second opinion - transmission was fine, just needed fluid change ($150). Very dishonest.',
        'publishedAtDate', '2024-12-28'
    )
);

-- Reviews for The Green Bistro (new business - all positive)
INSERT INTO business_reviews (business_id, review_data) VALUES
(
    (SELECT id FROM businesses WHERE apify_place_id = 'test_place_003'),
    jsonb_build_object(
        'reviewerName', 'Emma T.',
        'stars', 5,
        'text', 'Incredible farm-to-table experience! Every dish was beautifully presented and delicious. The seasonal menu changes keep things fresh. Best new restaurant in Seattle!',
        'publishedAtDate', '2025-01-18'
    )
),
(
    (SELECT id FROM businesses WHERE apify_place_id = 'test_place_003'),
    jsonb_build_object(
        'reviewerName', 'Chris B.',
        'stars', 5,
        'text', 'Outstanding vegetarian options and the wine list is excellent. Reservations are essential - this place will blow up soon!',
        'publishedAtDate', '2025-01-14'
    )
);

-- Reviews for Capitol Hill Books (positive with parking complaints)
INSERT INTO business_reviews (business_id, review_data) VALUES
(
    (SELECT id FROM businesses WHERE apify_place_id = 'test_place_004'),
    jsonb_build_object(
        'reviewerName', 'Rachel W.',
        'stars', 5,
        'text', 'Amazing selection of used and rare books. Staff is incredibly knowledgeable. My go-to bookstore in Seattle. Only issue is parking can be tough on weekends.',
        'publishedAtDate', '2025-01-11'
    )
),
(
    (SELECT id FROM businesses WHERE apify_place_id = 'test_place_004'),
    jsonb_build_object(
        'reviewerName', 'Tom H.',
        'stars', 4,
        'text', 'Great independent bookstore with character. Found several hard-to-find titles. Parking is a nightmare but worth the hassle.',
        'publishedAtDate', '2025-01-05'
    )
);

RAISE NOTICE '✓ Inserted 10 test reviews';

-- ============================================================================
-- 4. Verify Test Data Insertion
-- ============================================================================

DO $$
DECLARE
    business_count INT;
    review_count INT;
BEGIN
    SELECT COUNT(*) INTO business_count
    FROM businesses
    WHERE execution_id = :'test_execution_id';

    SELECT COUNT(*) INTO review_count
    FROM business_reviews r
    JOIN businesses b ON b.id = r.business_id
    WHERE b.execution_id = :'test_execution_id';

    RAISE NOTICE '✓ Verification: % businesses, % reviews', business_count, review_count;

    IF business_count != 5 THEN
        RAISE EXCEPTION 'Expected 5 businesses, found %', business_count;
    END IF;

    IF review_count != 10 THEN
        RAISE EXCEPTION 'Expected 10 reviews, found %', review_count;
    END IF;
END $$;

COMMIT;

-- ============================================================================
-- 5. Test Data Summary
-- ============================================================================

RAISE NOTICE '==========================================';
RAISE NOTICE 'Test data inserted successfully!';
RAISE NOTICE '==========================================';

SELECT
    'Test Execution ID' as detail,
    :'test_execution_id' as value
UNION ALL
SELECT
    'Total Businesses',
    COUNT(*)::text
FROM businesses
WHERE execution_id = :'test_execution_id'
UNION ALL
SELECT
    'Total Reviews',
    COUNT(*)::text
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE b.execution_id = :'test_execution_id';

-- ============================================================================
-- 6. Sample Queries to Test Data
-- ============================================================================

\echo ''
\echo '==========================================';
\echo 'Sample Queries to Test Your Data:';
\echo '==========================================';
\echo ''
\echo '-- 1. View all test businesses:';
\echo 'SELECT business_name, city, category, rating, review_count';
\echo 'FROM businesses';
\echo 'WHERE execution_id = ' :'test_execution_id' ';';
\echo ''
\echo '-- 2. Find businesses with trust issues (low ratings):';
\echo 'SELECT business_name, city, rating, review_count';
\echo 'FROM businesses';
\echo 'WHERE execution_id = ' :'test_execution_id';
\echo 'AND rating < 4.0';
\echo 'ORDER BY rating;';
\echo ''
\echo '-- 3. Full-text search for parking complaints:';
\echo 'SELECT b.business_name, r.review_text, r.stars';
\echo 'FROM business_reviews r';
\echo 'JOIN businesses b ON b.id = r.business_id';
\echo 'WHERE b.execution_id = ' :'test_execution_id';
\echo 'AND to_tsvector(''english'', r.review_text) @@ to_tsquery(''parking'');';
\echo ''
\echo '-- 4. Businesses with social media gaps:';
\echo 'SELECT business_name, city, rating, review_count,';
\echo '       business_data->''social''->''instagrams'' as instagram';
\echo 'FROM businesses';
\echo 'WHERE execution_id = ' :'test_execution_id';
\echo 'AND (business_data->''social''->''instagrams'' IS NULL';
\echo '     OR business_data->''social''->''instagrams'' = ''""'');';
\echo ''
\echo '-- 5. Cleanup test data when done:';
\echo 'psql "YOUR_URL" -f test-data.sql --variable=CLEANUP=true';
\echo ''

-- ============================================================================
-- Usage Examples
-- ============================================================================

COMMENT ON TABLE market_executions IS 'Test data: execution_id ' || :'test_execution_id' || ' is for testing purposes';

\echo '✅ Test data ready for validation!';
\echo '';
\echo 'Use this data to test:';
\echo '  - AI chat queries (city filters, rating filters, JSONB queries)';
\echo '  - Full-text search on reviews';
\echo '  - Opportunity analysis (trust issues, social gaps, underserved markets)';
\echo '  - Generated column accuracy';
\echo '  - Foreign key relationships';
\echo '';
\echo 'Run automated tests: psql "YOUR_URL" -f schema/run-tests.sql';
