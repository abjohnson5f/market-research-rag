# Database Documentation

> **Market Research RAG System - PostgreSQL Schema**
>
> Complete reference for tables, indexes, JSONB structures, and query patterns

---

## Table of Contents

- [Overview](#overview)
- [Schema Architecture](#schema-architecture)
- [Table Schemas](#table-schemas)
  - [market_executions](#market_executions)
  - [businesses](#businesses)
  - [business_reviews](#business_reviews)
- [JSONB Structure Reference](#jsonb-structure-reference)
- [Indexes & Query Optimization](#indexes--query-optimization)
- [Views](#views)
- [Triggers & Functions](#triggers--functions)
- [Common Query Patterns](#common-query-patterns)
- [Validation & Troubleshooting](#validation--troubleshooting)

---

## Overview

This database schema stores local business data scraped from Google Maps (via Apify) and supports RAG-powered market analysis through AI agents. The design consolidates what were previously 8 separate Google Sheets into a normalized relational structure with JSONB flexibility.

### Design Principles

1. **JSONB for Semi-Structured Data** - Apify schema changes frequently; JSONB provides flexibility without schema migrations
2. **Generated Columns for Performance** - Common filters (city, rating, etc.) extracted from JSONB for fast indexing
3. **One-to-Many Relationships** - Clean separation: business → reviews
4. **Full-Text Search** - Review text indexed for semantic queries
5. **Automatic Statistics** - Triggers maintain execution counts in real-time

### Installation

```bash
# Run schema files in order
psql -U your_user -d your_database -f schema/01-tables.sql
psql -U your_user -d your_database -f schema/02-indexes.sql

# Validate installation
psql -U your_user -d your_database -f schema/validate-schema.sql
```

---

## Schema Architecture

```
┌─────────────────────┐
│ market_executions   │  (Tracks each workflow run)
│ ─────────────────── │
│ id (PK)             │
│ search_query        │
│ status              │
│ total_businesses    │ ◄──┐ (Auto-updated by trigger)
│ total_reviews       │    │
└─────────────────────┘    │
          │                │
          │ 1:N            │
          │                │
┌─────────────────────┐    │
│ businesses          │────┘
│ ─────────────────── │
│ id (PK)             │
│ execution_id (FK)   │
│ business_name       │
│ business_data JSONB │ ◄── Contains: overview, contact, social,
│ city (generated)    │     rating, popular_times, tags, lead_enrichment
│ rating (generated)  │
└─────────────────────┘
          │
          │ 1:N
          │
┌─────────────────────┐
│ business_reviews    │
│ ─────────────────── │
│ id (PK)             │
│ business_id (FK)    │
│ review_data JSONB   │ ◄── Contains: text, stars, reviewer info,
│ review_text (gen)   │     images, owner response, etc.
│ stars (generated)   │
└─────────────────────┘
```

---

## Table Schemas

### market_executions

Tracks each workflow execution - replaces file-based execution tracking.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `SERIAL` | NOT NULL | auto | Primary key |
| `created_at` | `TIMESTAMP` | NULL | `NOW()` | When execution started |
| `completed_at` | `TIMESTAMP` | NULL | - | When execution finished |
| `status` | `TEXT` | NULL | `'running'` | Current state: `running`, `completed`, `failed` |
| `search_query` | `TEXT` | NULL | - | Search performed (e.g., "plumbers in Phoenix") |
| `apify_dataset_id` | `TEXT` | NULL | - | Link back to Apify dataset |
| `total_businesses` | `INT` | NULL | `0` | Count of businesses scraped (auto-updated) |
| `total_reviews` | `INT` | NULL | `0` | Count of reviews scraped (auto-updated) |
| `notes` | `TEXT` | NULL | - | Execution notes or error messages |

**Constraints:**
- `status` must be one of: `running`, `completed`, `failed`

**Usage:**
```sql
-- Start new execution
INSERT INTO market_executions (search_query, apify_dataset_id)
VALUES ('plumbers in Phoenix', 'abc123')
RETURNING id;

-- Mark execution complete
UPDATE market_executions
SET status = 'completed', completed_at = NOW()
WHERE id = 1;

-- Check recent executions
SELECT * FROM recent_executions;  -- View with duration calculations
```

---

### businesses

Core table - one row per business with all dimensions stored as JSONB.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `SERIAL` | NOT NULL | auto | Primary key |
| `execution_id` | `INT` | NOT NULL | - | FK to `market_executions` |
| `business_name` | `TEXT` | NOT NULL | - | Business name |
| `search_string` | `TEXT` | NULL | - | Search query that found this business |
| `apify_place_id` | `TEXT` | NULL | - | Unique identifier from Apify (prevents duplicates) |
| `business_data` | `JSONB` | NOT NULL | - | All business data (see JSONB structure below) |
| `city` | `TEXT` | NULL | generated | Extracted from `business_data->'overview'->>'city'` |
| `category` | `TEXT` | NULL | generated | Extracted from `business_data->'overview'->>'category'` |
| `rating` | `DECIMAL` | NULL | generated | Extracted from `business_data->'rating'->>'totalScore'` |
| `review_count` | `INT` | NULL | generated | Extracted from `business_data->'rating'->>'reviewsCount'` |
| `website` | `TEXT` | NULL | generated | Extracted from `business_data->'contact'->>'website'` |
| `phone` | `TEXT` | NULL | generated | Extracted from `business_data->'contact'->>'phone'` |
| `created_at` | `TIMESTAMP` | NULL | `NOW()` | When record created |
| `updated_at` | `TIMESTAMP` | NULL | `NOW()` | When record last updated (auto-maintained) |

**Constraints:**
- `apify_place_id` is UNIQUE (for deduplication across runs)
- `execution_id` references `market_executions(id)` with `ON DELETE CASCADE`

**Generated Columns:**
All `city`, `category`, `rating`, `review_count`, `website`, and `phone` columns are automatically extracted from the `business_data` JSONB. They cannot be directly set - modify the JSONB instead.

**Usage:**
```sql
-- Insert business
INSERT INTO businesses (execution_id, business_name, apify_place_id, business_data)
VALUES (
  1,
  'Phoenix Plumbing Co',
  'ChIJAbc123...',
  '{
    "overview": {"city": "Phoenix", "category": "Plumber"},
    "contact": {"phone": "555-1234", "website": "example.com"},
    "rating": {"totalScore": "4.5", "reviewsCount": "150"}
  }'::jsonb
);

-- Query with generated columns
SELECT business_name, city, rating, review_count
FROM businesses
WHERE city = 'Phoenix' AND rating > 4.5
ORDER BY review_count DESC;

-- Query JSONB directly
SELECT business_name, business_data->'social'->>'instagrams' as instagram
FROM businesses
WHERE business_data->'social' ? 'instagrams';
```

---

### business_reviews

Individual customer reviews - one-to-many relationship with businesses.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | `SERIAL` | NOT NULL | auto | Primary key |
| `business_id` | `INT` | NOT NULL | - | FK to `businesses` |
| `review_data` | `JSONB` | NOT NULL | - | Full review object (see JSONB structure below) |
| `reviewer_name` | `TEXT` | NULL | generated | Extracted from `review_data->>'reviewerName'` |
| `stars` | `INT` | NULL | generated | Extracted from `review_data->>'stars'` |
| `review_text` | `TEXT` | NULL | generated | Extracted from `review_data->>'text'` |
| `published_at` | `DATE` | NULL | generated | Extracted from `review_data->>'publishedAtDate'` |
| `created_at` | `TIMESTAMP` | NULL | `NOW()` | When record created |

**Constraints:**
- `business_id` references `businesses(id)` with `ON DELETE CASCADE`

**Generated Columns:**
All `reviewer_name`, `stars`, `review_text`, and `published_at` columns are automatically extracted from the `review_data` JSONB.

**Usage:**
```sql
-- Insert review
INSERT INTO business_reviews (business_id, review_data)
VALUES (
  1,
  '{
    "reviewerName": "John D.",
    "stars": "5",
    "text": "Great service! Quick and professional.",
    "publishedAtDate": "2024-01-15"
  }'::jsonb
);

-- Find reviews mentioning specific keywords
SELECT b.business_name, r.review_text, r.stars
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE to_tsvector('english', r.review_text) @@ to_tsquery('quick & professional')
ORDER BY r.stars DESC;

-- Get recent negative reviews
SELECT b.business_name, r.reviewer_name, r.review_text, r.published_at
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE r.stars <= 2
  AND r.published_at > NOW() - INTERVAL '30 days'
ORDER BY r.published_at DESC;
```

---

## JSONB Structure Reference

### businesses.business_data

The `business_data` JSONB column consolidates multiple dimensions of business information:

```json
{
  "overview": {
    "city": "Phoenix",
    "state": "AZ",
    "category": "Plumber",
    "address": "123 Main St, Phoenix, AZ 85001",
    "temporarilyClosed": false,
    "permanentlyClosed": false
  },
  "contact": {
    "phone": "+1 (555) 123-4567",
    "website": "https://example.com",
    "email": "info@example.com"
  },
  "social": {
    "instagrams": "https://instagram.com/company",
    "facebooks": "https://facebook.com/company",
    "linkedins": "https://linkedin.com/company/...",
    "twitters": null
  },
  "rating": {
    "totalScore": "4.5",
    "reviewsCount": "150",
    "reviewsDistribution": {
      "oneStar": 5,
      "twoStar": 3,
      "threeStar": 10,
      "fourStar": 32,
      "fiveStar": 100
    }
  },
  "popular_times": {
    "monday": [0, 0, 0, 0, 0, 0, 10, 30, 50, 70, 80, 90, 85, 75, 60, 50, 40, 30, 20, 10, 5, 0, 0, 0],
    "tuesday": [...],
    "histogramData": {...}
  },
  "tags": ["plumber", "emergency service", "licensed", "insured"],
  "lead_enrichment": {
    "hasWebsite": true,
    "hasEmail": true,
    "socialPresence": ["instagram", "facebook"],
    "reviewVelocity": "high",
    "lastReviewDate": "2024-10-01"
  }
}
```

**Key Paths:**
- Business location: `business_data->'overview'->>'city'`
- Phone number: `business_data->'contact'->>'phone'`
- Instagram handle: `business_data->'social'->>'instagrams'`
- Total rating: `business_data->'rating'->>'totalScore'`
- Review count: `business_data->'rating'->>'reviewsCount'`
- Custom tags: `business_data->'tags'`

### business_reviews.review_data

The `review_data` JSONB column contains complete review information:

```json
{
  "reviewerName": "John D.",
  "reviewerProfilePictureUrl": "https://...",
  "reviewerNumberOfReviews": 45,
  "reviewerIsLocalGuide": true,
  "stars": "5",
  "text": "Great service! Quick and professional. Would highly recommend.",
  "publishedAtDate": "2024-01-15",
  "likesCount": 12,
  "reviewImageUrls": ["https://...", "https://..."],
  "ownerResponse": {
    "text": "Thank you for the kind words!",
    "publishedAtDate": "2024-01-16"
  }
}
```

**Key Paths:**
- Reviewer name: `review_data->>'reviewerName'`
- Review text: `review_data->>'text'`
- Star rating: `review_data->>'stars'`
- Publication date: `review_data->>'publishedAtDate'`
- Owner response: `review_data->'ownerResponse'->>'text'`
- Images: `review_data->'reviewImageUrls'`

---

## Indexes & Query Optimization

### Execution Table Indexes

| Index Name | Columns | Type | Purpose |
|------------|---------|------|---------|
| `idx_executions_created` | `created_at DESC` | B-tree | Find recent executions |
| `idx_executions_status` | `status` (partial: != 'completed') | B-tree | Find in-progress or failed runs |

**Query Pattern:**
```sql
-- Uses idx_executions_created
SELECT * FROM market_executions
WHERE created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;

-- Uses idx_executions_status
SELECT * FROM market_executions
WHERE status = 'failed';
```

### Business Table Indexes

| Index Name | Columns | Type | Purpose |
|------------|---------|------|---------|
| `idx_businesses_execution` | `execution_id` | B-tree | FK lookup |
| `idx_businesses_city` | `city` (partial: NOT NULL) | B-tree | Filter by city |
| `idx_businesses_category` | `category` (partial: NOT NULL) | B-tree | Filter by category |
| `idx_businesses_rating` | `rating DESC NULLS LAST` | B-tree | Sort by rating |
| `idx_businesses_review_count` | `review_count DESC NULLS LAST` | B-tree | Sort by popularity |
| `idx_businesses_name_lower` | `LOWER(business_name)` | B-tree | Case-insensitive name search |
| `idx_businesses_city_rating` | `city, rating DESC` | B-tree | Combined city + rating queries |
| `idx_businesses_city_category` | `city, category` | B-tree | Combined city + category queries |
| `idx_businesses_data_gin` | `business_data` | GIN (jsonb_path_ops) | General JSONB queries |
| `idx_businesses_overview_gin` | `business_data->'overview'` | GIN | Fast overview queries |
| `idx_businesses_social_gin` | `business_data->'social'` | GIN | Fast social media queries |
| `idx_businesses_rating_gin` | `business_data->'rating'` | GIN | Fast rating queries |

**Query Patterns:**

```sql
-- Uses idx_businesses_city_rating
SELECT business_name, rating, review_count
FROM businesses
WHERE city = 'Phoenix' AND rating > 4.5
ORDER BY rating DESC;

-- Uses idx_businesses_data_gin
SELECT business_name
FROM businesses
WHERE business_data @> '{"overview": {"city": "Phoenix"}}';

-- Uses idx_businesses_social_gin
SELECT business_name, business_data->'social'->>'instagrams'
FROM businesses
WHERE business_data->'social' ? 'instagrams';

-- Uses idx_businesses_name_lower
SELECT * FROM businesses
WHERE LOWER(business_name) LIKE 'phoenix plumb%';
```

### Review Table Indexes

| Index Name | Columns | Type | Purpose |
|------------|---------|------|---------|
| `idx_reviews_business` | `business_id` | B-tree | FK lookup |
| `idx_reviews_stars` | `stars DESC NULLS LAST` | B-tree | Sort/filter by rating |
| `idx_reviews_date` | `published_at DESC NULLS LAST` | B-tree | Sort by date |
| `idx_reviews_text_fts` | `to_tsvector('english', review_text)` | GIN | Full-text search |
| `idx_reviews_data_gin` | `review_data` | GIN (jsonb_path_ops) | General JSONB queries |
| `idx_reviews_business_stars` | `business_id, stars DESC` | B-tree | Per-business rating queries |

**Query Patterns:**

```sql
-- Uses idx_reviews_text_fts
SELECT b.business_name, r.review_text, r.stars
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE to_tsvector('english', r.review_text) @@ to_tsquery('parking & problem')
ORDER BY r.stars DESC;

-- Uses idx_reviews_business_stars
SELECT AVG(stars) as avg_rating, COUNT(*) as review_count
FROM business_reviews
WHERE business_id = 123
  AND stars >= 4;

-- Uses idx_reviews_date
SELECT * FROM business_reviews
WHERE published_at > '2024-01-01'
ORDER BY published_at DESC;
```

### Index Maintenance

```sql
-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan;

-- Rebuild indexes if needed
REINDEX TABLE businesses;
REINDEX TABLE business_reviews;

-- Update statistics after bulk inserts
ANALYZE businesses;
ANALYZE business_reviews;
```

---

## Views

### business_summary

Flattened view combining business data with review aggregations.

**Definition:**
```sql
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
GROUP BY b.id;
```

**Usage:**
```sql
-- Quick business overview
SELECT * FROM business_summary
WHERE city = 'Phoenix'
  AND rating > 4.5
ORDER BY stored_reviews DESC;
```

### recent_executions

Last 50 workflow runs with duration calculations.

**Definition:**
```sql
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
```

**Usage:**
```sql
-- Check recent execution performance
SELECT search_query, duration_minutes, total_businesses, total_reviews
FROM recent_executions
WHERE status = 'completed'
ORDER BY duration_minutes DESC;
```

---

## Triggers & Functions

### update_updated_at_column()

Automatically updates `businesses.updated_at` timestamp on any UPDATE.

**Function:**
```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';
```

**Trigger:**
```sql
CREATE TRIGGER update_businesses_updated_at
    BEFORE UPDATE ON businesses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

### update_execution_stats()

Automatically maintains `total_businesses` and `total_reviews` counters in `market_executions`.

**Function:**
```sql
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
```

**Triggers:**
```sql
CREATE TRIGGER update_stats_on_business_insert
    AFTER INSERT ON businesses
    FOR EACH ROW
    EXECUTE FUNCTION update_execution_stats();

CREATE TRIGGER update_stats_on_review_insert
    AFTER INSERT ON business_reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_execution_stats();
```

**Behavior:**
- Inserting a business increments `market_executions.total_businesses`
- Inserting a review increments `market_executions.total_reviews`
- Counts are always up-to-date without manual maintenance

---

## Common Query Patterns

### Market Opportunity Analysis

**High-rated businesses with few reviews (underserved opportunities):**
```sql
SELECT business_name, city, rating, review_count, phone, website
FROM businesses
WHERE rating > 4.5
  AND review_count < 20
ORDER BY rating DESC, review_count ASC;
```

**Businesses with Instagram but low review count (influencer potential):**
```sql
SELECT business_name, city, rating, review_count,
       business_data->'social'->>'instagrams' as instagram
FROM businesses
WHERE business_data->'social' ? 'instagrams'
  AND business_data->'social'->>'instagrams' != ''
  AND review_count < 50
ORDER BY rating DESC;
```

### Competitive Intelligence

**Category analysis by city:**
```sql
SELECT city, category,
       COUNT(*) as business_count,
       AVG(rating) as avg_rating,
       SUM(review_count) as total_reviews,
       AVG(review_count) as avg_reviews_per_business
FROM businesses
WHERE city IS NOT NULL AND category IS NOT NULL
GROUP BY city, category
HAVING COUNT(*) > 3
ORDER BY total_reviews DESC;
```

**Market saturation check:**
```sql
SELECT city,
       COUNT(*) as total_businesses,
       AVG(rating) as market_avg_rating,
       COUNT(*) FILTER (WHERE rating > 4.5) as high_rated_count,
       COUNT(*) FILTER (WHERE review_count < 20) as low_review_count
FROM businesses
WHERE city IS NOT NULL
GROUP BY city
ORDER BY total_businesses DESC;
```

### Review Sentiment Analysis

**Search reviews for specific keywords:**
```sql
SELECT b.business_name, b.city, r.review_text, r.stars, r.published_at
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE to_tsvector('english', r.review_text) @@ to_tsquery('parking & problem')
ORDER BY r.stars DESC;
```

**Recent negative reviews requiring attention:**
```sql
SELECT b.business_name, b.city, b.phone,
       r.reviewer_name, r.review_text, r.stars, r.published_at
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE r.stars <= 2
  AND r.published_at > NOW() - INTERVAL '30 days'
ORDER BY r.published_at DESC;
```

**Businesses with owner responses (engagement level):**
```sql
SELECT b.business_name, b.city, b.rating,
       COUNT(*) as reviews_with_responses,
       COUNT(*) * 100.0 / NULLIF(b.review_count, 0) as response_rate
FROM businesses b
JOIN business_reviews r ON r.business_id = b.id
WHERE r.review_data->'ownerResponse' IS NOT NULL
GROUP BY b.id, b.business_name, b.city, b.rating, b.review_count
ORDER BY response_rate DESC;
```

### Lead Generation

**Businesses missing website (web design opportunities):**
```sql
SELECT business_name, city, category, phone, rating, review_count
FROM businesses
WHERE website IS NULL
  OR website = ''
  OR business_data->'contact'->>'website' IS NULL
ORDER BY rating DESC, review_count DESC;
```

**Businesses with low social presence but high ratings:**
```sql
SELECT business_name, city, rating, review_count, phone,
       CASE
           WHEN business_data->'social' ? 'instagrams' THEN 'yes'
           ELSE 'no'
       END as has_instagram,
       CASE
           WHEN business_data->'social' ? 'facebooks' THEN 'yes'
           ELSE 'no'
       END as has_facebook
FROM businesses
WHERE rating > 4.5
  AND review_count > 50
  AND (
      business_data->'social' IS NULL
      OR (
          (business_data->'social'->>'instagrams' IS NULL OR business_data->'social'->>'instagrams' = '')
          AND (business_data->'social'->>'facebooks' IS NULL OR business_data->'social'->>'facebooks' = '')
      )
  )
ORDER BY review_count DESC;
```

### Performance Monitoring

**Execution success rate:**
```sql
SELECT
    COUNT(*) as total_executions,
    COUNT(*) FILTER (WHERE status = 'completed') as completed,
    COUNT(*) FILTER (WHERE status = 'failed') as failed,
    COUNT(*) FILTER (WHERE status = 'running') as running,
    ROUND(COUNT(*) FILTER (WHERE status = 'completed') * 100.0 / COUNT(*), 2) as success_rate
FROM market_executions
WHERE created_at > NOW() - INTERVAL '30 days';
```

**Average execution performance:**
```sql
SELECT
    AVG(total_businesses) as avg_businesses_per_run,
    AVG(total_reviews) as avg_reviews_per_run,
    AVG(EXTRACT(EPOCH FROM (completed_at - created_at)) / 60) as avg_duration_minutes
FROM market_executions
WHERE status = 'completed'
  AND created_at > NOW() - INTERVAL '30 days';
```

---

## Validation & Troubleshooting

### Schema Validation

Run the validation script to check all tables, indexes, triggers, and views:

```bash
psql -U your_user -d your_database -f schema/validate-schema.sql
```

Expected output:
```
✓ All required tables exist
✓ All required indexes exist
✓ All required triggers exist
✓ All required views exist
✓ All required functions exist
Schema validation: PASSED
```

### Manual Validation Queries

**Check table existence:**
```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('market_executions', 'businesses', 'business_reviews')
ORDER BY table_name;
```

**Check index existence:**
```sql
SELECT tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

**Check trigger existence:**
```sql
SELECT trigger_name, event_object_table, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;
```

**Check view existence:**
```sql
SELECT table_name
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;
```

### Common Issues

#### Issue: Generated columns show NULL values

**Cause:** JSONB path doesn't match actual data structure

**Solution:**
```sql
-- Check actual JSONB structure
SELECT business_name, business_data
FROM businesses
WHERE city IS NULL
LIMIT 5;

-- Verify path exists
SELECT business_name,
       business_data->'overview'->>'city' as extracted_city
FROM businesses
WHERE business_data->'overview' ? 'city'
LIMIT 5;
```

#### Issue: Full-text search returns no results

**Cause:** Text search configuration mismatch or empty review_text

**Solution:**
```sql
-- Check review_text extraction
SELECT id, review_text, review_data->>'text'
FROM business_reviews
WHERE review_text IS NULL
LIMIT 5;

-- Test full-text search manually
SELECT to_tsvector('english', 'Great service and quick response');
SELECT to_tsquery('quick & response');

-- Rebuild FTS index
REINDEX INDEX idx_reviews_text_fts;
```

#### Issue: Slow queries on JSONB fields

**Cause:** Missing or unused GIN indexes

**Solution:**
```sql
-- Check if GIN indexes are being used
EXPLAIN ANALYZE
SELECT business_name
FROM businesses
WHERE business_data @> '{"overview": {"city": "Phoenix"}}';

-- Should show "Index Scan using idx_businesses_data_gin"
-- If not, check query structure or rebuild index

REINDEX INDEX idx_businesses_data_gin;
ANALYZE businesses;
```

#### Issue: Execution statistics not updating

**Cause:** Triggers not firing or execution_id mismatch

**Solution:**
```sql
-- Check triggers exist
SELECT trigger_name, event_object_table, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND event_object_table IN ('businesses', 'business_reviews');

-- Manually recalculate statistics
UPDATE market_executions e
SET total_businesses = (
    SELECT COUNT(*)
    FROM businesses b
    WHERE b.execution_id = e.id
),
total_reviews = (
    SELECT COUNT(*)
    FROM business_reviews r
    JOIN businesses b ON b.id = r.business_id
    WHERE b.execution_id = e.id
);
```

#### Issue: Duplicate businesses across executions

**Cause:** `apify_place_id` not being set during insert

**Solution:**
```sql
-- Find duplicates
SELECT apify_place_id, COUNT(*) as duplicate_count
FROM businesses
WHERE apify_place_id IS NOT NULL
GROUP BY apify_place_id
HAVING COUNT(*) > 1;

-- Use UPSERT to prevent duplicates
INSERT INTO businesses (execution_id, business_name, apify_place_id, business_data)
VALUES (1, 'Phoenix Plumbing', 'ChIJAbc123', '{...}'::jsonb)
ON CONFLICT (apify_place_id)
DO UPDATE SET
    business_data = EXCLUDED.business_data,
    updated_at = NOW();
```

### Performance Diagnostics

**Check table sizes:**
```sql
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY size_bytes DESC;
```

**Check index sizes:**
```sql
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
```

**Check slow queries:**
```sql
-- Enable query logging (run once)
-- ALTER DATABASE your_database SET log_min_duration_statement = 1000;

-- View current slow queries
SELECT pid, now() - query_start as duration, query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '5 seconds'
ORDER BY duration DESC;
```

**Check index usage:**
```sql
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan ASC;  -- Indexes with low usage
```

---

## Best Practices

### 1. JSONB Field Access

**DO:**
```sql
-- Use generated columns for common queries
SELECT business_name, city, rating
FROM businesses
WHERE city = 'Phoenix' AND rating > 4.5;
```

**DON'T:**
```sql
-- Avoid extracting JSONB in WHERE clause (slower, no index)
SELECT business_name
FROM businesses
WHERE (business_data->'overview'->>'city') = 'Phoenix'
  AND (business_data->'rating'->>'totalScore')::decimal > 4.5;
```

### 2. Bulk Inserts

**DO:**
```sql
-- Use transactions and batch inserts
BEGIN;
INSERT INTO businesses (execution_id, business_name, apify_place_id, business_data)
VALUES
  (1, 'Business 1', 'id1', '{...}'::jsonb),
  (1, 'Business 2', 'id2', '{...}'::jsonb),
  (1, 'Business 3', 'id3', '{...}'::jsonb);
COMMIT;

-- Run ANALYZE after bulk operations
ANALYZE businesses;
```

### 3. Full-Text Search

**DO:**
```sql
-- Use to_tsvector and to_tsquery for text search
SELECT b.business_name, r.review_text
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE to_tsvector('english', r.review_text) @@ to_tsquery('quick & professional');
```

**DON'T:**
```sql
-- Avoid LIKE/ILIKE for multi-word searches (slow, no index)
SELECT b.business_name, r.review_text
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE r.review_text ILIKE '%quick%' AND r.review_text ILIKE '%professional%';
```

### 4. Cascade Deletes

Be aware of cascade behavior:
```sql
-- Deleting an execution removes all its businesses AND reviews
DELETE FROM market_executions WHERE id = 1;
-- Cascades to businesses (via execution_id FK)
-- Cascades to business_reviews (via business_id FK)

-- Deleting a business removes all its reviews
DELETE FROM businesses WHERE id = 123;
-- Cascades to business_reviews (via business_id FK)
```

### 5. Monitoring Execution Health

**DO:**
```sql
-- Regular health checks
SELECT * FROM recent_executions WHERE status != 'completed';

-- Check for stale running executions (might be stuck)
SELECT id, search_query, created_at,
       NOW() - created_at as running_duration
FROM market_executions
WHERE status = 'running'
  AND created_at < NOW() - INTERVAL '1 hour';
```

---

## Additional Resources

- **Schema Files:**
  - `/schema/01-tables.sql` - Table definitions, triggers, views
  - `/schema/02-indexes.sql` - Performance indexes
  - `/schema/validate-schema.sql` - Validation script

- **PostgreSQL Documentation:**
  - [JSONB Functions](https://www.postgresql.org/docs/current/functions-json.html)
  - [GIN Indexes](https://www.postgresql.org/docs/current/gin.html)
  - [Full-Text Search](https://www.postgresql.org/docs/current/textsearch.html)
  - [Generated Columns](https://www.postgresql.org/docs/current/ddl-generated-columns.html)

- **Related Documentation:**
  - `README.md` - System overview and quick start
  - `docs/ARCHITECTURE.md` - High-level architecture

---

**Last Updated:** 2025-10-11
**Schema Version:** 1.0
