# Testing Guide - Market Research RAG System

Comprehensive testing guide for validating the complete Market Research RAG system from data collection to AI-powered analysis.

**Total time estimate:** 1-2 hours
**Prerequisites:** Issues #1-4 completed
**Outcome:** Production-ready system with documented test results

---

## Table of Contents

- [Quick Start](#quick-start)
- [Test Categories](#test-categories)
  - [1. Database Health](#1-database-health)
  - [2. Data Collection Workflow](#2-data-collection-workflow)
  - [3. RAG Chat Interface](#3-rag-chat-interface)
  - [4. AI Tool Execution](#4-ai-tool-execution)
  - [5. Error Handling](#5-error-handling)
  - [6. Performance Benchmarks](#6-performance-benchmarks)
  - [7. Production Readiness](#7-production-readiness)
- [End-to-End Scenarios](#end-to-end-scenarios)
- [Automated Test Scripts](#automated-test-scripts)
- [Test Results Template](#test-results-template)

---

## Quick Start

### Running Automated Tests

```bash
# 1. Insert test data
psql "YOUR_POSTGRES_URL" -f schema/test-data.sql

# 2. Run automated validation
psql "YOUR_POSTGRES_URL" -f schema/run-tests.sql

# 3. Clean up test data
psql "YOUR_POSTGRES_URL" -f schema/test-data.sql --variable=CLEANUP=true
```

### Manual Testing Checklist

- [ ] Database schema validated
- [ ] Test data inserted successfully
- [ ] Data collection workflow runs without errors
- [ ] Chat interface accessible and responsive
- [ ] AI tools execute queries correctly
- [ ] Performance benchmarks met
- [ ] Production readiness checklist complete

---

## Test Categories

## 1. Database Health

### Test 1.1: Schema Verification

**Objective:** Verify all required tables exist with correct column structure.

**SQL Query:**
```sql
SELECT
  table_name,
  (SELECT COUNT(*) FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public'
AND table_name IN ('market_executions', 'businesses', 'business_reviews');
```

**Expected Output:**
```
   table_name      | column_count
-------------------+-------------
 market_executions |      9
 businesses        |     11
 business_reviews  |      7
```

**Pass Criteria:**
- ✅ All 3 tables exist
- ✅ Column counts match expected values
- ✅ No errors during query execution

---

### Test 1.2: Index Verification

**Objective:** Ensure all performance indexes are created.

**SQL Query:**
```sql
SELECT tablename, COUNT(*) as index_count
FROM pg_indexes
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;
```

**Expected Output:**
- businesses: ~12 indexes
- business_reviews: ~5 indexes
- market_executions: ~2 indexes

**Pass Criteria:**
- ✅ All tables have indexes
- ✅ GIN indexes exist for JSONB columns
- ✅ Full-text search index exists on review_text

**Detailed Index Check:**
```sql
-- Check specific critical indexes
SELECT indexname, tablename
FROM pg_indexes
WHERE schemaname = 'public'
AND indexname IN (
  'idx_businesses_data_gin',
  'idx_reviews_text_fts',
  'idx_businesses_city_rating'
);
```

---

### Test 1.3: Trigger Verification

**Objective:** Confirm triggers for automated updates are functional.

**SQL Query:**
```sql
SELECT trigger_name, event_object_table, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public';
```

**Expected Triggers:**
- `update_businesses_updated_at` on businesses table
- `update_stats_on_business_insert` on businesses table
- `update_stats_on_review_insert` on business_reviews table

**Pass Criteria:**
- ✅ All 3 triggers exist
- ✅ Triggers fire on correct events (INSERT/UPDATE)
- ✅ No duplicate triggers

---

### Test 1.4: View Verification

**Objective:** Check that convenience views are created.

**SQL Query:**
```sql
SELECT table_name, view_definition
FROM information_schema.views
WHERE table_schema = 'public';
```

**Expected Views:**
- `business_summary` - Flattened business data with review stats
- `recent_executions` - Last 50 workflow runs

**Pass Criteria:**
- ✅ Both views exist
- ✅ Views return data without errors

---

## 2. Data Collection Workflow

### Test 2.1: Execution Tracking

**Objective:** Verify workflow creates execution records correctly.

**Manual Steps:**
1. Open n8n "Market Research - Data Collection" workflow
2. Modify Apify URL to include `maxCrawledPlacesPerSearch=5` (limit to 5 businesses)
3. Execute workflow manually
4. Wait for completion (30-60 seconds)

**Verification Query:**
```sql
SELECT id, created_at, status, total_businesses, total_reviews
FROM market_executions
ORDER BY created_at DESC
LIMIT 1;
```

**Pass Criteria:**
- ✅ New execution record created
- ✅ `status = 'completed'`
- ✅ `total_businesses = 5` (or your limit value)
- ✅ `total_reviews > 0`
- ✅ `completed_at` is not null
- ✅ Duration is reasonable (< 5 minutes for 5 businesses)

---

### Test 2.2: Business Data Integrity

**Objective:** Validate JSONB structure and generated columns.

**SQL Query:**
```sql
SELECT
  business_name,
  business_data ? 'overview' as has_overview,
  business_data ? 'contact' as has_contact,
  business_data ? 'social' as has_social,
  business_data ? 'rating' as has_rating,
  business_data->'overview'->>'city' as city_check,
  city as generated_city,
  business_data->'overview'->>'city' = city as city_match
FROM businesses
WHERE execution_id = (SELECT MAX(id) FROM market_executions)
LIMIT 5;
```

**Pass Criteria:**
- ✅ All JSONB sections present (has_* = true)
- ✅ `city_check` is not null
- ✅ `city_match = true` (generated column matches JSONB)
- ✅ No NULL values in required fields

---

### Test 2.3: Generated Columns Accuracy

**Objective:** Ensure generated columns extract correctly from JSONB.

**SQL Query:**
```sql
SELECT
  business_name,
  city,
  category,
  rating,
  review_count,
  website,
  phone,
  -- Verify each generated column matches JSONB source
  business_data->'overview'->>'city' = city as city_ok,
  business_data->'overview'->>'category' = category as category_ok,
  (business_data->'rating'->>'totalScore')::decimal = rating as rating_ok,
  (business_data->'rating'->>'reviewsCount')::int = review_count as reviews_ok
FROM businesses
WHERE execution_id = (SELECT MAX(id) FROM market_executions)
LIMIT 3;
```

**Pass Criteria:**
- ✅ All *_ok columns return `true`
- ✅ No type conversion errors
- ✅ Decimal precision maintained for ratings

---

### Test 2.4: Review Linkage

**Objective:** Verify reviews correctly link to parent businesses.

**SQL Query:**
```sql
SELECT
  b.business_name,
  COUNT(r.id) as review_count_actual,
  b.review_count as review_count_claimed,
  ROUND(AVG(r.stars), 2) as avg_stars_calculated,
  b.rating as rating_claimed
FROM businesses b
LEFT JOIN business_reviews r ON r.business_id = b.id
WHERE b.execution_id = (SELECT MAX(id) FROM market_executions)
GROUP BY b.id, b.business_name, b.review_count, b.rating
HAVING COUNT(r.id) > 0
LIMIT 5;
```

**Pass Criteria:**
- ✅ `review_count_actual > 0` for businesses with reviews
- ✅ Foreign key relationships intact
- ✅ No orphaned reviews (all reviews have valid business_id)

---

### Test 2.5: Deduplication

**Objective:** Verify `apify_place_id` prevents duplicate businesses.

**SQL Query:**
```sql
-- Check for duplicate place IDs
SELECT apify_place_id, COUNT(*) as duplicate_count
FROM businesses
WHERE apify_place_id IS NOT NULL
GROUP BY apify_place_id
HAVING COUNT(*) > 1;
```

**Pass Criteria:**
- ✅ Query returns 0 rows (no duplicates)
- ✅ UNIQUE constraint on `apify_place_id` enforced

**Test Deduplication:**
```sql
-- Try to insert duplicate (should fail)
INSERT INTO businesses (execution_id, business_name, apify_place_id, business_data)
VALUES (
  (SELECT MAX(id) FROM market_executions),
  'Test Business',
  (SELECT apify_place_id FROM businesses LIMIT 1), -- Existing place_id
  '{}'::jsonb
);
-- Expected: ERROR: duplicate key value violates unique constraint
```

---

## 3. RAG Chat Interface

### Test 3.1: Chat Interface Accessibility

**Objective:** Verify chat interface loads and is accessible.

**Manual Steps:**
1. Open n8n "Market Research - RAG Chat" workflow
2. Ensure workflow is **ACTIVATED** (toggle ON in top right)
3. Click "When chat message received" node (Chat Trigger)
4. Copy webhook URL (e.g., `https://your-n8n.com/webhook/chat-123`)
5. Open URL in browser

**Pass Criteria:**
- ✅ Chat interface loads within 3 seconds
- ✅ No JavaScript errors in browser console
- ✅ Input field and send button visible
- ✅ Chat history area displays

---

### Test 3.2: Basic Conversation

**Objective:** Test AI responds to simple questions.

**Test Query:**
```
You: "Hello! What can you help me with?"
```

**Expected Behavior:**
- ✅ AI responds within 5 seconds
- ✅ Response mentions market research capabilities
- ✅ Response mentions businesses and reviews
- ✅ Tone is helpful and professional

**Sample Expected Response:**
```
Hello! I'm your Market Research AI assistant. I can help you with:

- Finding businesses in your database by city, category, or rating
- Analyzing customer reviews for sentiment and patterns
- Identifying market opportunities and newsletter ideas
- Running complex analytical queries

What would you like to explore?
```

---

### Test 3.3: Memory Persistence

**Objective:** Verify AI remembers context within a session.

**Test Conversation:**
```
You: "My name is TestUser"
AI: [Acknowledges]

You: "What's my name?"
AI: [Should respond with "TestUser"]
```

**Pass Criteria:**
- ✅ AI remembers your name correctly
- ✅ Memory persists for at least 5 messages
- ✅ Different browser sessions have separate memory

---

### Test 3.4: System Knowledge

**Objective:** Confirm AI understands its capabilities.

**Test Query:**
```
You: "What database are you connected to?"
```

**Expected Response Should Mention:**
- ✅ Postgres database
- ✅ `businesses` table
- ✅ `business_reviews` table
- ✅ JSONB structure for flexible data
- ✅ Available tools (query_businesses, query_reviews, analyze_opportunities)

---

## 4. AI Tool Execution

### Test 4.1: Query Businesses Tool

**Objective:** Verify AI can query businesses table.

**Test Query:**
```
You: "Show me 3 businesses"
```

**Expected AI Behavior:**
1. AI recognizes this requires `query_businesses` tool
2. Writes SQL: `SELECT business_name, city, rating FROM businesses LIMIT 3`
3. Executes query
4. Formats results in natural language

**Pass Criteria:**
- ✅ Returns exactly 3 businesses
- ✅ Includes business names, cities, and ratings
- ✅ Response is well-formatted
- ✅ Query completes in < 3 seconds

---

### Test 4.2: City Filtering

**Objective:** Test filtering by city (generated column index).

**Test Query (replace [CITY] with city from your data):**
```
You: "Show me businesses in Phoenix"
```

**Expected SQL Pattern:**
```sql
SELECT business_name, category, rating, review_count
FROM businesses
WHERE city = 'Phoenix'
ORDER BY rating DESC
LIMIT 10;
```

**Pass Criteria:**
- ✅ AI uses `WHERE city = 'Phoenix'`
- ✅ All results are from specified city
- ✅ AI states number of businesses found
- ✅ Uses `idx_businesses_city` index (check EXPLAIN ANALYZE)

---

### Test 4.3: Rating Filtering

**Objective:** Test numeric filtering and ordering.

**Test Query:**
```
You: "Find businesses with rating above 4.5"
```

**Expected SQL Pattern:**
```sql
SELECT business_name, city, rating, review_count
FROM businesses
WHERE rating > 4.5
ORDER BY rating DESC;
```

**Pass Criteria:**
- ✅ AI writes `WHERE rating > 4.5`
- ✅ All results have rating > 4.5
- ✅ Results ordered by rating (highest first)
- ✅ Uses `idx_businesses_rating` index

---

### Test 4.4: JSONB Queries

**Objective:** Test AI can query nested JSONB data.

**Test Query:**
```
You: "Which businesses have Instagram accounts?"
```

**Expected SQL Pattern:**
```sql
SELECT
  business_name,
  city,
  business_data->'social'->>'instagrams' as instagram
FROM businesses
WHERE business_data->'social' ? 'instagrams'
  AND business_data->'social'->>'instagrams' != ''
LIMIT 20;
```

**Pass Criteria:**
- ✅ AI uses JSONB operators (`->`, `->>`, `?`)
- ✅ Returns only businesses with Instagram
- ✅ Displays Instagram URLs
- ✅ Uses `idx_businesses_social_gin` index

---

### Test 4.5: Full-Text Search on Reviews

**Objective:** Test full-text search capabilities.

**Test Query:**
```
You: "What are customers saying about parking?"
```

**Expected SQL Pattern:**
```sql
SELECT b.business_name, r.review_text, r.stars
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE to_tsvector('english', r.review_text) @@ to_tsquery('parking')
ORDER BY r.stars
LIMIT 20;
```

**Pass Criteria:**
- ✅ AI uses `query_reviews` tool
- ✅ Uses full-text search (`to_tsvector`, `to_tsquery`)
- ✅ Returns reviews mentioning "parking"
- ✅ Summarizes sentiment (positive vs negative)
- ✅ Uses `idx_reviews_text_fts` index

---

### Test 4.6: Opportunity Analysis

**Objective:** Test complex analytical queries.

**Test Query:**
```
You: "What are the best newsletter opportunities in this data?"
```

**Expected Behavior:**
- ✅ AI uses `analyze_opportunities` tool
- ✅ Performs aggregations (GROUP BY, COUNT, AVG)
- ✅ Identifies categories with high review volume + low ratings
- ✅ Suggests specific newsletter angles
- ✅ Cites data (e.g., "Auto Repair has 450 reviews, avg 3.2 stars")

**Sample Expected Response:**
```
Based on the data, here are the top newsletter opportunities:

1. **Auto Repair Services** - 47 businesses, avg rating 3.4, 1,200+ reviews
   Newsletter angle: "How to find trustworthy mechanics in Phoenix"

2. **Home Cleaning** - 23 businesses, avg rating 3.7, 600+ reviews
   Newsletter angle: "Vetted home cleaners with verified reviews"

3. **HVAC Services** - 31 businesses, avg rating 3.5, 800+ reviews
   Newsletter angle: "Emergency AC repair: Who to call at 2 AM"

These categories have high demand (many reviews) but trust issues (low ratings),
making them perfect for a curation newsletter.
```

---

### Test 4.7: Multi-Step Reasoning

**Objective:** Test AI maintains context across multiple queries.

**Conversation Flow:**
```
You: "Show me coffee shops"
AI: [Lists 10 coffee shops]

You: "Which of these have the worst reviews?"
AI: [Filters to bottom-rated from previous list]

You: "What are the common complaints?"
AI: [Analyzes review text from those businesses]
```

**Pass Criteria:**
- ✅ AI maintains context across 3+ questions
- ✅ Uses multiple tools in sequence
- ✅ Each query builds on previous results
- ✅ Provides actionable insights

---

## 5. Error Handling

### Test 5.1: Invalid Input Recovery

**Objective:** Ensure AI handles nonsensical input gracefully.

**Test Query:**
```
You: "Show me XYZ123 businesses"
```

**Expected Behavior:**
- ✅ AI either interprets as "show me some businesses" OR
- ✅ Asks for clarification ("Did you mean show me businesses in a specific city?")
- ✅ Does NOT crash the workflow
- ✅ Does NOT write invalid SQL

---

### Test 5.2: Empty Results

**Objective:** Test AI response when queries return no results.

**Test Query:**
```
You: "Show me businesses in Atlantis"
```

**Expected Response:**
```
I found 0 businesses in Atlantis.

Would you like to search for businesses in a different city?
Here are the cities in the database: Phoenix, Seattle, Denver, ...
```

**Pass Criteria:**
- ✅ AI executes query correctly
- ✅ Reports "I found 0 businesses"
- ✅ Does NOT hallucinate/make up data
- ✅ Offers helpful alternatives

---

### Test 5.3: Ambiguous Questions

**Objective:** Test AI clarification behavior.

**Test Query:**
```
You: "Tell me about businesses"
```

**Expected Behavior (one of two approaches):**

**Approach 1: Ask for clarification**
```
I can help with businesses! What would you like to know?
- Businesses in a specific city?
- Businesses in a specific category?
- Overall statistics?
```

**Approach 2: Provide summary**
```
Here's an overview of the businesses in the database:
- Total businesses: 150
- Cities: Phoenix (47), Seattle (38), Denver (25), ...
- Categories: Coffee Shops (12), Auto Repair (9), Restaurants (15), ...

What specific aspect would you like to explore?
```

**Pass Criteria:**
- ✅ AI does NOT return all 150 businesses (overwhelming)
- ✅ Response is helpful and guides user
- ✅ Provides context for follow-up questions

---

## 6. Performance Benchmarks

### Test 6.1: Response Time

**Objective:** Measure end-to-end query performance.

**Test Queries:**

| Query Type | Query | Expected Time | Your Result |
|-----------|-------|---------------|-------------|
| **Simple** | "Show me 3 businesses" | < 3 seconds | ___ seconds |
| **Filter** | "Businesses in Phoenix with rating > 4.5" | < 4 seconds | ___ seconds |
| **JSONB** | "Businesses with Instagram accounts" | < 5 seconds | ___ seconds |
| **Join** | "Reviews mentioning 'parking'" | < 6 seconds | ___ seconds |
| **Aggregation** | "Average rating by category" | < 5 seconds | ___ seconds |
| **Complex** | "Best newsletter opportunities" | < 8 seconds | ___ seconds |

**Pass Criteria:**
- ✅ 90% of queries complete within expected time
- ✅ No queries timeout (> 30 seconds)
- ✅ Response time consistent across multiple runs

**How to Measure:**
- Use browser Developer Tools → Network tab
- Or note timestamp of your message vs AI response

---

### Test 6.2: Concurrent Users

**Objective:** Verify session isolation with multiple users.

**Test Steps:**
1. Open chat interface in Browser Window 1
2. Open same URL in **Incognito/Private** Browser Window 2
3. Run conversation:

**Window 1:**
```
You: "My name is Alice"
You: "What's my name?"
Expected: "Alice"
```

**Window 2:**
```
You: "My name is Bob"
You: "What's my name?"
Expected: "Bob"
```

**Pass Criteria:**
- ✅ Window 1 gets "Alice"
- ✅ Window 2 gets "Bob"
- ✅ No session crossover
- ✅ Both windows maintain independent memory

---

### Test 6.3: Database Query Performance

**Objective:** Verify indexes are being used effectively.

**Test Query:**
```sql
EXPLAIN ANALYZE
SELECT business_name, city, rating, review_count
FROM businesses
WHERE city = 'Phoenix' AND rating > 4.5
ORDER BY rating DESC
LIMIT 10;
```

**Expected Plan:**
```
Index Scan using idx_businesses_city_rating on businesses
  Index Cond: ((city = 'Phoenix') AND (rating > 4.5))
  Execution Time: 0.250 ms
```

**Pass Criteria:**
- ✅ Uses index (not Seq Scan)
- ✅ Execution time < 100ms
- ✅ Planning time < 50ms

**Test Full-Text Search:**
```sql
EXPLAIN ANALYZE
SELECT b.business_name, r.review_text, r.stars
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE to_tsvector('english', r.review_text) @@ to_tsquery('parking')
LIMIT 20;
```

**Pass Criteria:**
- ✅ Uses `idx_reviews_text_fts` (Bitmap Index Scan)
- ✅ Execution time < 500ms for 1000+ reviews

---

## 7. Production Readiness

### Test 7.1: Credentials Security

**Checklist:**
- [ ] Postgres password not hardcoded in workflow JSON
- [ ] OpenAI API key stored in n8n credentials (not in nodes)
- [ ] Apify API token stored in n8n credentials
- [ ] Webhook URLs use authentication if public-facing
- [ ] No sensitive data in git repository

**How to Verify:**
```bash
# Export workflow JSON
# Search for sensitive patterns
grep -i "password\|api_key\|token" workflow.json
# Should return no matches (credentials use variable syntax instead)
```

---

### Test 7.2: Error Notifications

**Objective:** Ensure you're notified of workflow failures.

**Setup:**
1. Add Error Trigger node to data collection workflow
2. Connect to Slack/Email notification node
3. Test by forcing error (invalid Postgres connection)

**Pass Criteria:**
- [ ] Workflow execution marked as 'failed' in n8n
- [ ] You receive notification within 5 minutes
- [ ] Notification includes error details

---

### Test 7.3: Data Backup

**Objective:** Verify database can be backed up and restored.

**Backup Test:**
```bash
# Create backup
pg_dump "YOUR_POSTGRES_URL" > backup_$(date +%Y%m%d).sql

# Verify backup file
ls -lh backup_*.sql
# Should be > 1MB if you have real data

# Check backup contents
head -n 50 backup_*.sql
# Should show CREATE TABLE statements
```

**Restore Test (use test database!):**
```bash
# Create test database
psql "YOUR_POSTGRES_URL" -c "CREATE DATABASE test_restore;"

# Restore backup
psql "postgresql://user:pass@host/test_restore" < backup_20250111.sql

# Verify data
psql "postgresql://user:pass@host/test_restore" -c "SELECT COUNT(*) FROM businesses;"

# Clean up
psql "YOUR_POSTGRES_URL" -c "DROP DATABASE test_restore;"
```

**Pass Criteria:**
- ✅ Backup creates successfully (no errors)
- ✅ Backup file size is reasonable (not empty)
- ✅ Restore works on clean database
- ✅ Data integrity maintained after restore

---

### Test 7.4: Documentation Complete

**Checklist:**
- [ ] README.md explains system purpose and architecture
- [ ] docs/SETUP.md has step-by-step implementation guide
- [ ] docs/TESTING.md (this file) covers all test scenarios
- [ ] docs/TROUBLESHOOTING.md lists common issues and fixes
- [ ] docs/PRODUCTION-CHECKLIST.md for pre-launch validation
- [ ] schema/*.sql files have inline comments
- [ ] Example queries provided for common use cases

---

## End-to-End Scenarios

### Scenario 1: New Market Research Project

**Objective:** Test complete workflow from data collection to analysis.

**Steps:**
1. Update Apify search URL in data collection workflow
   - Change search term (e.g., "coffee shops in Seattle")
   - Remove `maxCrawledPlacesPerSearch` limit for full dataset
2. Execute workflow manually
3. Monitor execution (should take 3-10 minutes for 100 businesses)
4. Check execution record in database
5. Open chat interface
6. Ask: "Summarize what we just collected"

**Expected AI Response:**
```
I just analyzed the data from the latest collection run:

- **Total Businesses**: 127 coffee shops in Seattle
- **Average Rating**: 4.2 stars
- **Total Reviews**: 3,450 reviews collected
- **Top Categories**: Specialty Coffee (45), Cafes (38), Coffee Roasters (12)
- **Geographic Spread**: Capitol Hill (23), Downtown (18), Fremont (15)...

**Key Insights**:
- 34% of businesses have ratings below 4.0 (trust issues)
- Only 40% have Instagram accounts (social media gap)
- Highest-rated area: Capitol Hill (avg 4.5)

Would you like me to dive deeper into any of these insights?
```

**Pass Criteria:**
- ✅ Workflow completes without errors
- ✅ All businesses and reviews imported to database
- ✅ Chat provides accurate summary immediately
- ✅ Can query new data with follow-up questions

---

### Scenario 2: Weekly Newsletter Creation

**Objective:** Generate newsletter ideas from market data.

**Conversation Flow:**
```
You: "I need 30 newsletter ideas for home services businesses in Phoenix"

AI: [Runs analyze_opportunities tool, identifies patterns]
    "Here are 30 newsletter opportunities based on Phoenix market data:

    **HIGH PRIORITY (Trust Issues + High Demand)**
    1. 'The 10 Most Reliable HVAC Companies in Phoenix (Real Reviews)'
    2. 'Emergency Plumbers: Who Answers at 2 AM?'
    ...

    **MEDIUM PRIORITY (Underserved Categories)**
    11. 'Phoenix Lawn Care: Hidden Gems with Perfect Reviews'
    ...

    **SOCIAL MEDIA GAPS**
    21. 'Great Service, Zero Social Presence: Phoenix's Best Kept Secrets'
    ..."

You: "Focus on the top 3 opportunities"

AI: [Dives deeper with specific businesses]
    "Let's explore the top 3 in detail:

    **1. HVAC Services (47 businesses, avg 3.4 stars, 1,200 reviews)**
    - Trust issue: 45% of reviews mention 'unexpected charges'
    - High-rated exceptions: [Lists 5 businesses with 4.8+ ratings]
    - Newsletter angle: 'Transparent pricing HVAC pros'
    ..."

You: "For HVAC, what specific pain points should the newsletter address?"

AI: [Analyzes negative reviews]
    "Analyzing 340 negative HVAC reviews, here are the common complaints:

    1. **Pricing transparency** (mentioned in 62% of bad reviews)
       - 'Hidden fees', 'bait and switch', 'quote doubled'
    2. **Response time** (43%)
       - 'No call back', 'waited 3 days', 'never showed up'
    3. **Quality of repair** (38%)
       - 'Fixed same issue 3 times', 'still broken', 'temporary fix'

    Newsletter should emphasize:
    - Upfront, written estimates
    - Same-day emergency service
    - Warranty on work performed"
```

**Pass Criteria:**
- ✅ AI provides 30 specific ideas (not generic)
- ✅ Ideas are data-driven (cites business counts, ratings, review volumes)
- ✅ Follow-up questions refine the analysis
- ✅ Output is actionable (newsletter creator can use immediately)
- ✅ Total time: < 5 minutes for complete analysis

---

### Scenario 3: Competitive Analysis

**Objective:** Compare multiple categories to identify market dynamics.

**Conversation Flow:**
```
You: "Compare coffee shops to auto repair shops in Phoenix"

AI: [Runs comparative query]
    "Here's the comparison between coffee shops and auto repair in Phoenix:

    | Metric | Coffee Shops | Auto Repair |
    |--------|-------------|-------------|
    | Total businesses | 34 | 47 |
    | Avg rating | 4.5 | 3.4 |
    | Total reviews | 2,100 | 4,500 |
    | % with social media | 85% | 30% |
    | Avg review length | 45 words | 120 words |

    **Key Differences**:
    - Auto repair has 2x the review volume despite lower ratings
    - Coffee shops invest heavily in social media presence
    - Auto repair reviews are detailed (frustrated customers explain issues)"

You: "Which category has more trust issues?"

AI: [Analyzes sentiment]
    "Auto Repair has significantly more trust issues:

    - 45% of reviews mention pricing concerns ('overcharged', 'hidden fees')
    - 38% question quality ('not fixed', 'worse after visit')
    - 22% mention honesty ('felt cheated', 'unnecessary repairs')

    Coffee shops by comparison:
    - Only 12% negative reviews
    - Complaints focus on wait times, not trust

    **Newsletter Opportunity**: 'Honest Mechanics in Phoenix' - High demand, low trust"

You: "Show me the worst-rated auto repair shop and its reviews"

AI: [Queries specific business]
    "The lowest-rated auto repair shop is [Business Name] (2.1 stars, 89 reviews):

    **Recent 1-star reviews**:
    - 'Charged $800 for brake job quoted at $200' (Jan 2025)
    - 'Car broke down again 2 days after $600 repair' (Jan 2025)
    - 'Told me I needed transmission work, got second opinion - was fine' (Dec 2024)

    **Common themes**:
    - Inflated quotes (mentioned in 68% of bad reviews)
    - Poor communication (no callbacks, no updates)
    - Questionable diagnosis (customers report unnecessary work)

    This is a perfect example of the trust gap in Phoenix auto repair."
```

**Pass Criteria:**
- ✅ AI performs multi-category analysis
- ✅ Identifies quantitative patterns (ratings, review volumes)
- ✅ Identifies qualitative patterns (trust issues, sentiment)
- ✅ Drills down from category → specific business → specific reviews
- ✅ Provides actionable business insights

---

## Automated Test Scripts

### Using test-data.sql

The `schema/test-data.sql` script creates a consistent test dataset.

**Insert test data:**
```bash
psql "YOUR_POSTGRES_URL" -f schema/test-data.sql
```

**What it creates:**
- 1 test execution record
- 5 test businesses (varied data)
  - 2 in Phoenix (1 coffee shop, 1 auto repair)
  - 2 in Seattle (1 restaurant, 1 bookstore)
  - 1 in Denver (1 brewery)
- 10 test reviews (mix of ratings and content)
- Covers edge cases (missing data, special characters, long text)

**Clean up test data:**
```bash
psql "YOUR_POSTGRES_URL" -f schema/test-data.sql --variable=CLEANUP=true
```

This removes only test data (execution_id for test execution).

---

### Using run-tests.sql

The `schema/run-tests.sql` script runs automated validation checks.

**Run all tests:**
```bash
psql "YOUR_POSTGRES_URL" -f schema/run-tests.sql
```

**What it checks:**
- ✅ All tables exist
- ✅ All indexes exist
- ✅ All triggers exist
- ✅ Generated columns work correctly
- ✅ JSONB queries work
- ✅ Full-text search works
- ✅ Joins work correctly
- ✅ Aggregations work correctly

**Output format:**
```
TEST: Tables Exist - PASS
TEST: Indexes Exist - PASS
TEST: Triggers Exist - PASS
TEST: Generated Columns - PASS
TEST: JSONB Queries - PASS
TEST: Full-Text Search - PASS
TEST: Foreign Keys - PASS
TEST: Aggregations - PASS

==================
SUMMARY: 8/8 tests passed
==================
```

---

## Test Results Template

Copy this template to document your testing results:

```markdown
# Market Research RAG System - Test Results

**Test Date:** [YYYY-MM-DD]
**Tester:** [Your Name]
**System Version:** Issues #1-4 completed
**Database:** [Supabase/Postgres version]
**n8n Version:** [version number]

---

## Automated Tests

**Database Health:**
- [ ] Schema verification: PASS / FAIL
- [ ] Index verification: PASS / FAIL
- [ ] Trigger verification: PASS / FAIL
- [ ] View verification: PASS / FAIL

**Automated Test Script:**
```bash
psql "YOUR_URL" -f schema/run-tests.sql
```
- [ ] All tests passed: YES / NO
- Tests passed: __ / 8

---

## Manual Tests

### Data Collection
- [ ] Execution tracking: PASS / FAIL
- [ ] Business data integrity: PASS / FAIL
- [ ] Generated columns: PASS / FAIL
- [ ] Review linkage: PASS / FAIL
- [ ] Deduplication: PASS / FAIL

### RAG Chat Interface
- [ ] Chat accessibility: PASS / FAIL
- [ ] Basic conversation: PASS / FAIL
- [ ] Memory persistence: PASS / FAIL
- [ ] System knowledge: PASS / FAIL

### AI Tool Execution
- [ ] Query businesses: PASS / FAIL
- [ ] City filtering: PASS / FAIL
- [ ] Rating filtering: PASS / FAIL
- [ ] JSONB queries: PASS / FAIL
- [ ] Review analysis (full-text): PASS / FAIL
- [ ] Opportunity analysis: PASS / FAIL
- [ ] Multi-step reasoning: PASS / FAIL

### Error Handling
- [ ] Invalid input recovery: PASS / FAIL
- [ ] Empty results: PASS / FAIL
- [ ] Ambiguous questions: PASS / FAIL

### Performance
| Query Type | Expected | Actual | Status |
|-----------|----------|--------|--------|
| Simple | < 3s | __s | PASS/FAIL |
| Filter | < 4s | __s | PASS/FAIL |
| JSONB | < 5s | __s | PASS/FAIL |
| Join | < 6s | __s | PASS/FAIL |
| Aggregation | < 5s | __s | PASS/FAIL |
| Complex | < 8s | __s | PASS/FAIL |

- [ ] Concurrent users: PASS / FAIL
- [ ] Database query performance: PASS / FAIL

### Production Readiness
- [ ] Credentials security: PASS / FAIL
- [ ] Error notifications: PASS / FAIL
- [ ] Data backup: PASS / FAIL
- [ ] Documentation complete: PASS / FAIL

---

## End-to-End Scenarios

- [ ] Scenario 1: New market research: PASS / FAIL
  - Notes: ________________________________

- [ ] Scenario 2: Newsletter creation: PASS / FAIL
  - Time to generate 30 ideas: __ minutes
  - Notes: ________________________________

- [ ] Scenario 3: Competitive analysis: PASS / FAIL
  - Notes: ________________________________

---

## Issues Found

[List any issues discovered during testing]

1. Issue: ________________________________
   - Severity: Critical / High / Medium / Low
   - Steps to reproduce: ________________________________
   - Workaround: ________________________________

2. Issue: ________________________________
   ...

---

## Overall Assessment

- **Total Tests**: 40
- **Passed**: ___
- **Failed**: ___
- **Pass Rate**: ___%

**System Status**: ✅ READY FOR PRODUCTION / ⚠️ NEEDS WORK / ❌ MAJOR ISSUES

**Recommendation**:
[Your assessment of production readiness]

---

## Next Steps

[List actions based on test results]

- [ ] Fix critical issues: ________________________________
- [ ] Deploy to production: ________________________________
- [ ] Train stakeholders: ________________________________
- [ ] Schedule first real data collection: ________________________________

---

**Tester Signature:** _______________
**Date:** _______________
```

---

## Performance Benchmarks

### Expected Performance Targets

**Query Response Times (End-to-End):**
- Simple queries (< 10 rows): < 3 seconds
- Medium queries (10-50 rows): < 5 seconds
- Complex queries (aggregations): < 8 seconds
- Full-text search: < 6 seconds

**Database Query Times (SQL only):**
- Indexed queries: < 100ms
- JSONB queries with GIN: < 200ms
- Full-text search: < 500ms
- Complex joins: < 1 second

**Workflow Execution Times:**
- Data collection (10 businesses): 30-60 seconds
- Data collection (100 businesses): 3-5 minutes
- Chat message processing: 2-5 seconds

---

## Troubleshooting

For common issues and solutions, see [docs/TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

Quick reference:
- **Slow queries**: Check indexes with `EXPLAIN ANALYZE`
- **AI hallucinations**: Update system prompt to emphasize data accuracy
- **Memory not working**: Verify sessionId in Postgres Chat Memory
- **Tools not executing**: Check ai_tool port connections
- **Workflow failures**: Check n8n execution logs and error messages

---

## Additional Resources

- [Setup Guide](./SETUP.md) - Initial system setup
- [Troubleshooting Guide](./TROUBLESHOOTING.md) - Common issues
- [Production Checklist](./PRODUCTION-CHECKLIST.md) - Pre-launch validation
- [GitHub Issues](https://github.com/abjohnson5f/market-research-rag/issues) - Implementation steps

---

**Next:** After successful testing, proceed to [PRODUCTION-CHECKLIST.md](./PRODUCTION-CHECKLIST.md) for final validation before launch.
