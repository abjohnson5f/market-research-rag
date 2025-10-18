-- ============================================================================
-- Market Research RAG System - Test Data
-- ============================================================================
-- This file creates realistic sample data for testing the system
-- Run AFTER 01-tables.sql and 02-indexes.sql
--
-- Contents:
-- - 1 test execution
-- - 10 sample businesses (diverse cities, categories, ratings)
-- - 30 sample reviews (varied sentiments, topics)
-- - Edge cases: high/low ratings, missing data, JSONB variations
-- ============================================================================

-- Clean up any existing test data
DELETE FROM business_reviews WHERE business_id IN (
    SELECT id FROM businesses WHERE execution_id IN (
        SELECT id FROM market_executions WHERE search_query = 'TEST_DATA'
    )
);
DELETE FROM businesses WHERE execution_id IN (
    SELECT id FROM market_executions WHERE search_query = 'TEST_DATA'
);
DELETE FROM market_executions WHERE search_query = 'TEST_DATA';

-- ============================================================================
-- TEST EXECUTION
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
    NOW() - INTERVAL '30 minutes',
    'completed',
    'TEST_DATA',
    'test_dataset_12345',
    10,
    30,
    'Test data for system validation - Issue #5'
);

-- Store execution_id for use in subsequent inserts
DO $$
DECLARE
    test_execution_id INT;
BEGIN
    SELECT id INTO test_execution_id FROM market_executions WHERE search_query = 'TEST_DATA';

-- ============================================================================
-- SAMPLE BUSINESSES (10 businesses across different scenarios)
-- ============================================================================

-- Business 1: High-rated auto repair in Phoenix (newsletter opportunity)
INSERT INTO businesses (execution_id, business_name, search_string, apify_place_id, business_data) VALUES (
    test_execution_id,
    'Phoenix Premium Auto Repair',
    'auto repair Phoenix',
    'TEST_ChIJ1234_Phoenix_Auto',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'title', 'Phoenix Premium Auto Repair',
            'category', 'Auto Repair Shop',
            'address', '1234 E Main St, Phoenix, AZ 85001',
            'city', 'Phoenix',
            'state', 'Arizona',
            'postalCode', '85001',
            'countryCode', 'US'
        ),
        'contact', jsonb_build_object(
            'phone', '+1 602-555-0101',
            'website', 'https://phoenixpremiumauto.com'
        ),
        'social', jsonb_build_object(
            'instagrams', 'https://instagram.com/phoenixpremiumauto',
            'facebooks', 'https://facebook.com/phoenixpremiumauto'
        ),
        'rating', jsonb_build_object(
            'totalScore', '4.8',
            'reviewsCount', '156'
        ),
        'tags', jsonb_build_array('Oil Change', 'Brake Repair', 'Engine Diagnostics')
    )
);

-- Business 2: Low-rated plumber in Phoenix (pain point analysis opportunity)
INSERT INTO businesses (execution_id, business_name, search_string, apify_place_id, business_data) VALUES (
    test_execution_id,
    'Quick Fix Plumbing',
    'plumber Phoenix',
    'TEST_ChIJ5678_Phoenix_Plumber',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'title', 'Quick Fix Plumbing',
            'category', 'Plumber',
            'address', '5678 W Indian School Rd, Phoenix, AZ 85031',
            'city', 'Phoenix',
            'state', 'Arizona',
            'postalCode', '85031'
        ),
        'contact', jsonb_build_object(
            'phone', '+1 602-555-0202',
            'website', NULL
        ),
        'social', jsonb_build_object(),
        'rating', jsonb_build_object(
            'totalScore', '2.3',
            'reviewsCount', '89'
        ),
        'tags', jsonb_build_array('Emergency Service', '24/7')
    )
);

-- Business 3: Coffee shop in Scottsdale (high engagement, Instagram presence)
INSERT INTO businesses (execution_id, business_name, search_string, apify_place_id, business_data) VALUES (
    test_execution_id,
    'Artisan Coffee Collective',
    'coffee shop Scottsdale',
    'TEST_ChIJ9012_Scottsdale_Coffee',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'title', 'Artisan Coffee Collective',
            'category', 'Coffee Shop',
            'address', '7890 E Shea Blvd, Scottsdale, AZ 85260',
            'city', 'Scottsdale',
            'state', 'Arizona',
            'postalCode', '85260'
        ),
        'contact', jsonb_build_object(
            'phone', '+1 480-555-0303',
            'website', 'https://artisancoffeecollective.com'
        ),
        'social', jsonb_build_object(
            'instagrams', 'https://instagram.com/artisancoffeeco',
            'facebooks', 'https://facebook.com/artisancoffeeco',
            'tiktok', 'https://tiktok.com/@artisancoffeeco'
        ),
        'rating', jsonb_build_object(
            'totalScore', '4.9',
            'reviewsCount', '342'
        ),
        'tags', jsonb_build_array('Specialty Coffee', 'Local Roastery', 'Pastries', 'WiFi')
    )
);

-- Business 4: Dentist in Tempe (professional services)
INSERT INTO businesses (execution_id, business_name, search_string, apify_place_id, business_data) VALUES (
    test_execution_id,
    'Tempe Family Dentistry',
    'dentist Tempe',
    'TEST_ChIJ3456_Tempe_Dentist',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'title', 'Tempe Family Dentistry',
            'category', 'Dentist',
            'address', '456 S Mill Ave, Tempe, AZ 85281',
            'city', 'Tempe',
            'state', 'Arizona',
            'postalCode', '85281'
        ),
        'contact', jsonb_build_object(
            'phone', '+1 480-555-0404',
            'website', 'https://tempefamilydentistry.com'
        ),
        'social', jsonb_build_object(
            'facebooks', 'https://facebook.com/tempefamilydentistry'
        ),
        'rating', jsonb_build_object(
            'totalScore', '4.6',
            'reviewsCount', '78'
        ),
        'tags', jsonb_build_array('Cosmetic Dentistry', 'Family Friendly', 'Emergency Care')
    )
);

-- Business 5: HVAC in Mesa (home services, seasonal)
INSERT INTO businesses (execution_id, business_name, search_string, apify_place_id, business_data) VALUES (
    test_execution_id,
    'Desert Cool HVAC',
    'hvac Mesa',
    'TEST_ChIJ7890_Mesa_HVAC',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'title', 'Desert Cool HVAC',
            'category', 'HVAC Contractor',
            'address', '2345 E Main St, Mesa, AZ 85203',
            'city', 'Mesa',
            'state', 'Arizona',
            'postalCode', '85203'
        ),
        'contact', jsonb_build_object(
            'phone', '+1 480-555-0505',
            'website', 'https://desertcoolhvac.com'
        ),
        'social', jsonb_build_object(
            'instagrams', 'https://instagram.com/desertcoolhvac'
        ),
        'rating', jsonb_build_object(
            'totalScore', '4.4',
            'reviewsCount', '124'
        ),
        'tags', jsonb_build_array('AC Repair', 'Heating', 'Installation', 'Maintenance')
    )
);

-- Business 6: Restaurant in Phoenix (food service, high volume)
INSERT INTO businesses (execution_id, business_name, search_string, apify_place_id, business_data) VALUES (
    test_execution_id,
    'Casa del Sol Mexican Grill',
    'mexican restaurant Phoenix',
    'TEST_ChIJ2345_Phoenix_Restaurant',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'title', 'Casa del Sol Mexican Grill',
            'category', 'Mexican Restaurant',
            'address', '8901 N 7th St, Phoenix, AZ 85020',
            'city', 'Phoenix',
            'state', 'Arizona',
            'postalCode', '85020'
        ),
        'contact', jsonb_build_object(
            'phone', '+1 602-555-0606',
            'website', 'https://casadelsolphx.com'
        ),
        'social', jsonb_build_object(
            'instagrams', 'https://instagram.com/casadelsolphx',
            'facebooks', 'https://facebook.com/casadelsolphx'
        ),
        'rating', jsonb_build_object(
            'totalScore', '4.7',
            'reviewsCount', '523'
        ),
        'tags', jsonb_build_array('Authentic Mexican', 'Family Owned', 'Outdoor Seating', 'Happy Hour')
    )
);

-- Business 7: Gym in Chandler (fitness, membership model)
INSERT INTO businesses (execution_id, business_name, search_string, apify_place_id, business_data) VALUES (
    test_execution_id,
    'Chandler Fitness Studio',
    'gym Chandler',
    'TEST_ChIJ6789_Chandler_Gym',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'title', 'Chandler Fitness Studio',
            'category', 'Gym',
            'address', '3456 W Chandler Blvd, Chandler, AZ 85226',
            'city', 'Chandler',
            'state', 'Arizona',
            'postalCode', '85226'
        ),
        'contact', jsonb_build_object(
            'phone', '+1 480-555-0707',
            'website', 'https://chandlerfitnessstudio.com'
        ),
        'social', jsonb_build_object(
            'instagrams', 'https://instagram.com/chandlerfitness',
            'tiktok', 'https://tiktok.com/@chandlerfitness'
        ),
        'rating', jsonb_build_object(
            'totalScore', '4.5',
            'reviewsCount', '201'
        ),
        'tags', jsonb_build_array('Personal Training', 'Group Classes', '24/7 Access', 'Showers')
    )
);

-- Business 8: Pet grooming in Gilbert (niche service)
INSERT INTO businesses (execution_id, business_name, search_string, apify_place_id, business_data) VALUES (
    test_execution_id,
    'Pampered Paws Grooming',
    'pet grooming Gilbert',
    'TEST_ChIJ8901_Gilbert_Grooming',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'title', 'Pampered Paws Grooming',
            'category', 'Pet Groomer',
            'address', '5678 S Val Vista Dr, Gilbert, AZ 85296',
            'city', 'Gilbert',
            'state', 'Arizona',
            'postalCode', '85296'
        ),
        'contact', jsonb_build_object(
            'phone', '+1 480-555-0808',
            'website', NULL
        ),
        'social', jsonb_build_object(
            'facebooks', 'https://facebook.com/pamperedpawsgilbert'
        ),
        'rating', jsonb_build_object(
            'totalScore', '4.9',
            'reviewsCount', '67'
        ),
        'tags', jsonb_build_array('Dog Grooming', 'Cat Grooming', 'Nail Trimming')
    )
);

-- Business 9: New business with few reviews (opportunity)
INSERT INTO businesses (execution_id, business_name, search_string, apify_place_id, business_data) VALUES (
    test_execution_id,
    'Sunrise Yoga Studio',
    'yoga Scottsdale',
    'TEST_ChIJ4567_Scottsdale_Yoga',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'title', 'Sunrise Yoga Studio',
            'category', 'Yoga Studio',
            'address', '1234 N Scottsdale Rd, Scottsdale, AZ 85257',
            'city', 'Scottsdale',
            'state', 'Arizona',
            'postalCode', '85257'
        ),
        'contact', jsonb_build_object(
            'phone', '+1 480-555-0909',
            'website', 'https://sunriseyogascottsdale.com'
        ),
        'social', jsonb_build_object(
            'instagrams', 'https://instagram.com/sunriseyogascottsdale'
        ),
        'rating', jsonb_build_object(
            'totalScore', '5.0',
            'reviewsCount', '12'
        ),
        'tags', jsonb_build_array('Hatha Yoga', 'Vinyasa', 'Meditation', 'Beginner Friendly')
    )
);

-- Business 10: Edge case - minimal data
INSERT INTO businesses (execution_id, business_name, search_string, apify_place_id, business_data) VALUES (
    test_execution_id,
    'Main Street Barber',
    'barber Phoenix',
    'TEST_ChIJ0123_Phoenix_Barber',
    jsonb_build_object(
        'overview', jsonb_build_object(
            'title', 'Main Street Barber',
            'category', 'Barber Shop',
            'address', '999 W Main St, Phoenix, AZ 85003',
            'city', 'Phoenix'
        ),
        'contact', jsonb_build_object(
            'phone', '+1 602-555-1010'
        ),
        'social', jsonb_build_object(),
        'rating', jsonb_build_object(
            'totalScore', '3.8',
            'reviewsCount', '23'
        ),
        'tags', jsonb_build_array()
    )
);

-- ============================================================================
-- SAMPLE REVIEWS (30 reviews across businesses)
-- ============================================================================

-- Reviews for Business 1: Phoenix Premium Auto Repair (mix of positive)
INSERT INTO business_reviews (business_id, review_data) VALUES
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ1234_Phoenix_Auto'),
    jsonb_build_object(
        'reviewerName', 'Sarah M.',
        'stars', 5,
        'text', 'Excellent service! They diagnosed my brake issue quickly and the repair was done the same day. Fair pricing and great customer service.',
        'publishedAtDate', '2025-09-15',
        'likesCount', 12
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ1234_Phoenix_Auto'),
    jsonb_build_object(
        'reviewerName', 'Mike T.',
        'stars', 5,
        'text', 'Best auto shop in Phoenix! Honest mechanics who explain everything clearly. They found issues my dealership missed.',
        'publishedAtDate', '2025-08-22',
        'likesCount', 8
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ1234_Phoenix_Auto'),
    jsonb_build_object(
        'reviewerName', 'Jennifer L.',
        'stars', 4,
        'text', 'Very professional. The waiting area could use better coffee, but the work quality is top-notch.',
        'publishedAtDate', '2025-07-10',
        'likesCount', 3
    )
);

-- Reviews for Business 2: Quick Fix Plumbing (mostly negative - pain points)
INSERT INTO business_reviews (business_id, review_data) VALUES
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ5678_Phoenix_Plumber'),
    jsonb_build_object(
        'reviewerName', 'David R.',
        'stars', 1,
        'text', 'Terrible experience. They showed up 3 hours late and the leak started again the next day. Had to call another plumber to fix their work.',
        'publishedAtDate', '2025-09-20',
        'likesCount', 15
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ5678_Phoenix_Plumber'),
    jsonb_build_object(
        'reviewerName', 'Linda K.',
        'stars', 2,
        'text', 'Overpriced and poor communication. They said it would cost $200 but charged me $450. The plumber barely explained what he was doing.',
        'publishedAtDate', '2025-08-30',
        'likesCount', 9
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ5678_Phoenix_Plumber'),
    jsonb_build_object(
        'reviewerName', 'Robert P.',
        'stars', 3,
        'text', 'They got the job done eventually but the scheduling was a nightmare. Called 4 times before someone showed up.',
        'publishedAtDate', '2025-07-05',
        'likesCount', 4
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ5678_Phoenix_Plumber'),
    jsonb_build_object(
        'reviewerName', 'Amanda G.',
        'stars', 1,
        'text', 'Do NOT use this company. They left my bathroom floor flooded and refused to return my calls about the damage.',
        'publishedAtDate', '2025-06-12',
        'likesCount', 22
    )
);

-- Reviews for Business 3: Artisan Coffee Collective (highly positive, social media mentions)
INSERT INTO business_reviews (business_id, review_data) VALUES
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ9012_Scottsdale_Coffee'),
    jsonb_build_object(
        'reviewerName', 'Emma W.',
        'stars', 5,
        'text', 'Instagram-worthy latte art and actually delicious coffee! Love the cozy atmosphere. Perfect spot for remote work.',
        'publishedAtDate', '2025-09-25',
        'likesCount', 34
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ9012_Scottsdale_Coffee'),
    jsonb_build_object(
        'reviewerName', 'Chris B.',
        'stars', 5,
        'text', 'Best cold brew in Scottsdale. The baristas are super knowledgeable and friendly. Parking can be tricky but worth it.',
        'publishedAtDate', '2025-09-18',
        'likesCount', 18
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ9012_Scottsdale_Coffee'),
    jsonb_build_object(
        'reviewerName', 'Maya S.',
        'stars', 5,
        'text', 'Amazing pastries from local bakery and ethically sourced beans. This place really cares about quality and community.',
        'publishedAtDate', '2025-08-14',
        'likesCount', 27
    )
);

-- Reviews for Business 4: Tempe Family Dentistry
INSERT INTO business_reviews (business_id, review_data) VALUES
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ3456_Tempe_Dentist'),
    jsonb_build_object(
        'reviewerName', 'Patricia H.',
        'stars', 5,
        'text', 'Dr. Johnson is wonderful with kids. My daughter actually looks forward to her dental appointments now!',
        'publishedAtDate', '2025-09-12',
        'likesCount', 6
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ3456_Tempe_Dentist'),
    jsonb_build_object(
        'reviewerName', 'Tom D.',
        'stars', 4,
        'text', 'Professional staff and modern equipment. The wait time was a bit long but the care was excellent.',
        'publishedAtDate', '2025-08-20',
        'likesCount', 4
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ3456_Tempe_Dentist'),
    jsonb_build_object(
        'reviewerName', 'Karen M.',
        'stars', 5,
        'text', 'Painless tooth extraction and they work with my insurance. Highly recommend for families.',
        'publishedAtDate', '2025-07-28',
        'likesCount', 8
    )
);

-- Reviews for Business 5: Desert Cool HVAC (seasonal service mentions)
INSERT INTO business_reviews (business_id, review_data) VALUES
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ7890_Mesa_HVAC'),
    jsonb_build_object(
        'reviewerName', 'Steve A.',
        'stars', 5,
        'text', 'Our AC died during the summer heat wave and they came out same day. Lifesavers! Fair pricing for emergency service.',
        'publishedAtDate', '2025-08-01',
        'likesCount', 11
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ7890_Mesa_HVAC'),
    jsonb_build_object(
        'reviewerName', 'Rachel F.',
        'stars', 4,
        'text', 'Technician was knowledgeable and explained everything. Only issue was they didn''t have the part in stock so had to come back next day.',
        'publishedAtDate', '2025-07-15',
        'likesCount', 5
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ7890_Mesa_HVAC'),
    jsonb_build_object(
        'reviewerName', 'James C.',
        'stars', 4,
        'text', 'Good maintenance service. They caught a potential problem before it became expensive. Will use again.',
        'publishedAtDate', '2025-06-22',
        'likesCount', 3
    )
);

-- Reviews for Business 6: Casa del Sol Mexican Grill (food quality, parking mentions)
INSERT INTO business_reviews (business_id, review_data) VALUES
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ2345_Phoenix_Restaurant'),
    jsonb_build_object(
        'reviewerName', 'Maria G.',
        'stars', 5,
        'text', 'Authentic Mexican food that reminds me of my grandmother''s cooking! The carne asada is perfection. Parking is tight on weekends.',
        'publishedAtDate', '2025-09-22',
        'likesCount', 19
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ2345_Phoenix_Restaurant'),
    jsonb_build_object(
        'reviewerName', 'Alex N.',
        'stars', 5,
        'text', 'Best margaritas in Phoenix and the outdoor patio is beautiful at sunset. Service is always friendly.',
        'publishedAtDate', '2025-09-10',
        'likesCount', 14
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ2345_Phoenix_Restaurant'),
    jsonb_build_object(
        'reviewerName', 'Brian L.',
        'stars', 4,
        'text', 'Great food and portions. Had to wait 30 minutes for a table on Friday night but it was worth it. Parking situation is challenging.',
        'publishedAtDate', '2025-08-28',
        'likesCount', 7
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ2345_Phoenix_Restaurant'),
    jsonb_build_object(
        'reviewerName', 'Nicole S.',
        'stars', 5,
        'text', 'Family-owned gem with amazing salsa bar. The staff remembers regulars by name. Can''t recommend enough!',
        'publishedAtDate', '2025-08-05',
        'likesCount', 23
    )
);

-- Reviews for Business 7: Chandler Fitness Studio
INSERT INTO business_reviews (business_id, review_data) VALUES
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ6789_Chandler_Gym'),
    jsonb_build_object(
        'reviewerName', 'Kevin P.',
        'stars', 5,
        'text', 'Clean facility with great equipment. The trainers actually care about your progress. Lost 20 pounds in 3 months!',
        'publishedAtDate', '2025-09-08',
        'likesCount', 16
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ6789_Chandler_Gym'),
    jsonb_build_object(
        'reviewerName', 'Lisa M.',
        'stars', 4,
        'text', 'Love the variety of classes. Yoga instructor is amazing. Sometimes crowded during peak hours but overall great gym.',
        'publishedAtDate', '2025-08-17',
        'likesCount', 9
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ6789_Chandler_Gym'),
    jsonb_build_object(
        'reviewerName', 'Dan W.',
        'stars', 5,
        'text', '24/7 access is clutch for my work schedule. Always clean, equipment well-maintained, and good community vibe.',
        'publishedAtDate', '2025-07-25',
        'likesCount', 12
    )
);

-- Reviews for Business 8: Pampered Paws Grooming
INSERT INTO business_reviews (business_id, review_data) VALUES
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ8901_Gilbert_Grooming'),
    jsonb_build_object(
        'reviewerName', 'Jessica R.',
        'stars', 5,
        'text', 'My anxious golden retriever actually enjoys going here! The groomers are so patient and gentle. He looks like a show dog every time.',
        'publishedAtDate', '2025-09-19',
        'likesCount', 21
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ8901_Gilbert_Grooming'),
    jsonb_build_object(
        'reviewerName', 'Mark H.',
        'stars', 5,
        'text', 'Professional service and reasonable prices. They handled my cat like a pro - no small feat!',
        'publishedAtDate', '2025-08-11',
        'likesCount', 13
    )
);

-- Reviews for Business 9: Sunrise Yoga Studio (new business, all positive)
INSERT INTO business_reviews (business_id, review_data) VALUES
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ4567_Scottsdale_Yoga'),
    jsonb_build_object(
        'reviewerName', 'Olivia T.',
        'stars', 5,
        'text', 'Beautiful new studio with natural light and peaceful energy. The instructor creates a welcoming space for all levels.',
        'publishedAtDate', '2025-09-26',
        'likesCount', 7
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ4567_Scottsdale_Yoga'),
    jsonb_build_object(
        'reviewerName', 'Sophie K.',
        'stars', 5,
        'text', 'Finally a yoga studio in Scottsdale that isn''t intimidating! Great for beginners and the meditation sessions are wonderful.',
        'publishedAtDate', '2025-09-18',
        'likesCount', 5
    )
);

-- Reviews for Business 10: Main Street Barber (edge case - basic reviews)
INSERT INTO business_reviews (business_id, review_data) VALUES
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ0123_Phoenix_Barber'),
    jsonb_build_object(
        'reviewerName', 'John D.',
        'stars', 4,
        'text', 'Good haircut, quick service.',
        'publishedAtDate', '2025-09-05',
        'likesCount', 2
    )
),
((SELECT id FROM businesses WHERE apify_place_id = 'TEST_ChIJ0123_Phoenix_Barber'),
    jsonb_build_object(
        'reviewerName', 'Carlos V.',
        'stars', 3,
        'text', 'Decent place. Cash only.',
        'publishedAtDate', '2025-08-14',
        'likesCount', 1
    )
);

END $$;

-- ============================================================================
-- VERIFY TEST DATA LOADED
-- ============================================================================

-- Summary statistics
SELECT
    'Test Execution Summary' as info,
    COUNT(DISTINCT b.id) as businesses_loaded,
    COUNT(r.id) as reviews_loaded,
    COUNT(DISTINCT b.city) as unique_cities,
    COUNT(DISTINCT b.category) as unique_categories
FROM businesses b
LEFT JOIN business_reviews r ON r.business_id = b.id
WHERE b.execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA');

-- Businesses by city
SELECT city, COUNT(*) as business_count
FROM businesses
WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
GROUP BY city
ORDER BY business_count DESC;

-- Rating distribution
SELECT
    CASE
        WHEN rating >= 4.5 THEN 'Excellent (4.5+)'
        WHEN rating >= 4.0 THEN 'Good (4.0-4.4)'
        WHEN rating >= 3.0 THEN 'Average (3.0-3.9)'
        ELSE 'Poor (<3.0)'
    END as rating_category,
    COUNT(*) as business_count
FROM businesses
WHERE execution_id = (SELECT id FROM market_executions WHERE search_query = 'TEST_DATA')
GROUP BY rating_category
ORDER BY MIN(rating) DESC;

-- ============================================================================
-- SUCCESS
-- ============================================================================
-- Test data loaded successfully!
-- You now have:
-- - 10 realistic businesses across Phoenix metro area
-- - 30 diverse reviews (positive, negative, mixed)
-- - Edge cases: new business (12 reviews), low-rated (2.3), minimal data
-- - Ready for testing all 40 test cases in run-tests.sql
-- ============================================================================
