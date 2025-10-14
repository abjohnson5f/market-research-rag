# Strategic Analysis Views - Usage Guide

## Overview

8 SQL views that materialize market intelligence insights from raw business data collected via Apify. These views replace manual Excel analysis with queryable SQL interfaces that the RAG AI Agent can use to answer strategic business questions.

**Architecture Layer:** Intelligence Layer (between raw data storage and AI execution)

**Data Source:** Excel strategic framework ("Niches related to Clay's Core Services.xlsx")

**Performance:** Most queries complete in <100ms due to pre-computed aggregations and indexes

---

## Quick Reference

| View | Purpose | Key Metrics | Example Query |
|------|---------|-------------|---------------|
| **niche_opportunities** | Market gaps & saturation | opportunity_score (0-10), business_count | `SELECT * FROM niche_opportunities WHERE opportunity_score >= 8;` |
| **customer_pain_points** | Unmet needs from complaints | primary_pain_point, complaint percentages | `SELECT * FROM customer_pain_points ORDER BY total_complaints DESC;` |
| **market_leaders** | Top incumbents to avoid | inc_score (0-100), market_position | `SELECT * FROM market_leaders WHERE inc_score >= 70;` |
| **vulnerable_players** | Disruption targets | vulnerability_score (0-100), rating_momentum | `SELECT * FROM vulnerable_players WHERE vulnerability_score >= 60;` |
| **review_velocity_trends** | Growth momentum | momentum_ratio, market_temperature | `SELECT * FROM review_velocity_trends WHERE momentum_ratio >= 1.5;` |
| **niche_service_gaps** | Sub-specialty opportunities | demand_supply_ratio, gap_status | `SELECT * FROM niche_service_gaps WHERE gap_status = 'CRITICAL_GAP';` |
| **business_model_opportunities** | Newsletter viability | newsletter_viability_score (0-100), arbitrage_potential | `SELECT * FROM business_model_opportunities WHERE newsletter_viability_score >= 70;` |
| **niche_swot_analysis** | Competitive positioning | primary_strength/weakness/opportunity | `SELECT * FROM niche_swot_analysis ORDER BY total_negative_reviews DESC;` |

---

## Detailed View Documentation

### 1. niche_opportunities

**Purpose:** Identify underserved market categories with high opportunity potential

**Excel Mapping:** Sheet 1 "Niches" - Provider density, avg rating, review velocity

**Key Fields:**
- `opportunity_score` (0-10): Inverse saturation score (10 = wide open, 2 = saturated)
- `saturation_level`: WIDE_OPEN, LOW_COMPETITION, MEDIUM_SATURATION, HIGH_SATURATION
- `business_count`: Number of providers in category
- `top_players`: Array of top 3 businesses (rating >= 4.5)

**Example Queries:**

```sql
-- Find wide open niches in Phoenix
SELECT category, business_count, opportunity_score, saturation_level
FROM niche_opportunities
WHERE city = 'Phoenix'
  AND opportunity_score >= 8
ORDER BY opportunity_score DESC;

-- Compare saturation across cities for HVAC
SELECT city, business_count, avg_category_rating, opportunity_score
FROM niche_opportunities
WHERE category = 'HVAC'
ORDER BY opportunity_score DESC;

-- Find niches with strong demand but few providers
SELECT category, city, business_count, total_category_reviews
FROM niche_opportunities
WHERE business_count < 10
  AND total_category_reviews > 100
ORDER BY total_category_reviews DESC;
```

**AI Agent Usage:**
- User: "What are the underserved niches in Phoenix?"
- Query: `niche_opportunities WHERE city = 'Phoenix' AND opportunity_score >= 7`
- Response: Lists categories with low competition and high demand

---

### 2. customer_pain_points

**Purpose:** Extract unmet customer needs from negative review sentiment analysis

**Excel Mapping:** Sheet 3 "Niches related to Clay's Core S" - Weaknesses column

**Key Fields:**
- `primary_pain_point`: Top complaint category (Pricing, Scheduling, Quality, Communication, Availability)
- `*_complaints` and `*_pct`: Count and percentage for each pain category
- `sample_complaints`: Actual review excerpts (truncated to 100 chars)

**Example Queries:**

```sql
-- Find categories with pricing transparency issues
SELECT category, city, total_complaints, pricing_pct, sample_complaints
FROM customer_pain_points
WHERE primary_pain_point = 'Pricing Transparency'
ORDER BY pricing_pct DESC
LIMIT 10;

-- Compare pain points across categories
SELECT category, primary_pain_point, total_complaints
FROM customer_pain_points
WHERE city = 'Phoenix'
ORDER BY total_complaints DESC;

-- Find availability pain points (24/7 opportunity)
SELECT category, city, availability_complaints, availability_pct
FROM customer_pain_points
WHERE availability_pct >= 20
ORDER BY availability_pct DESC;
```

**AI Agent Usage:**
- User: "What are customers complaining about in HVAC services?"
- Query: `customer_pain_points WHERE category = 'HVAC'`
- Response: Breaks down top pain points with percentages and examples

---

### 3. market_leaders

**Purpose:** Identify dominant incumbents you should NOT compete with directly

**Excel Mapping:** Sheet 3 "Niches related to Clay's Core S" - Top businesses to watch

**Key Fields:**
- `inc_score` (0-100): Incumbent strength score (rating 40%, volume 30%, consistency 20%, momentum 10%)
- `market_position`: DOMINANT_LEADER, STRONG_INCUMBENT, ESTABLISHED_PLAYER, EMERGING_BUSINESS
- `digital_presence_score` (0-3): Website + Instagram + Facebook presence
- `rating_variance`: Lower = more consistent quality

**Example Queries:**

```sql
-- Find dominant leaders to avoid
SELECT business_name, category, city, rating, review_count, inc_score, market_position
FROM market_leaders
WHERE market_position = 'DOMINANT_LEADER'
ORDER BY inc_score DESC;

-- Find emerging businesses gaining momentum
SELECT business_name, category, recent_reviews_90d, inc_score
FROM market_leaders
WHERE market_position = 'EMERGING_BUSINESS'
  AND recent_reviews_90d >= 10
ORDER BY recent_reviews_90d DESC;

-- Check market leader consistency
SELECT business_name, category, rating, rating_variance, inc_score
FROM market_leaders
WHERE rating >= 4.5
ORDER BY rating_variance ASC
LIMIT 10;
```

**AI Agent Usage:**
- User: "Who are the market leaders in Phoenix HVAC I should avoid?"
- Query: `market_leaders WHERE category = 'HVAC' AND city = 'Phoenix' AND inc_score >= 70`
- Response: Lists top incumbents with INC scores and market positions

---

### 4. vulnerable_players

**Purpose:** Find underperforming businesses vulnerable to disruption

**Excel Mapping:** Sheet 3 "Niches related to Clay's Core S" - Top but underperforming

**Key Fields:**
- `vulnerability_score` (0-100): Higher = more vulnerable (rating decline + negative sentiment)
- `rating_momentum`: Negative values indicate decline
- `vulnerability_classification`: HIGH_DISRUPTION_TARGET, DECLINING_INCUMBENT, REPUTATION_CRISIS, MODERATE_VULNERABILITY
- `recent_negative_reviews`: Surge in poor ratings

**Example Queries:**

```sql
-- Find high disruption targets
SELECT business_name, category, city, overall_rating, recent_rating_90d,
       rating_momentum, vulnerability_score, vulnerability_classification
FROM vulnerable_players
WHERE vulnerability_classification = 'HIGH_DISRUPTION_TARGET'
ORDER BY vulnerability_score DESC;

-- Track declining incumbents
SELECT business_name, category, overall_rating, recent_rating_90d,
       rating_momentum, review_count
FROM vulnerable_players
WHERE rating_momentum < -0.5
ORDER BY rating_momentum ASC;

-- Find reputation crises (negative review surges)
SELECT business_name, category, recent_negative_reviews,
       recent_review_count, vulnerability_score
FROM vulnerable_players
WHERE vulnerability_classification = 'REPUTATION_CRISIS'
ORDER BY recent_negative_reviews DESC;
```

**AI Agent Usage:**
- User: "Which established HVAC businesses are vulnerable?"
- Query: `vulnerable_players WHERE category = 'HVAC' AND vulnerability_score >= 60`
- Response: Lists businesses with declining ratings and market position

---

### 5. review_velocity_trends

**Purpose:** Track market growth momentum and activity levels

**Excel Mapping:** Sheet 1 "Niches" - Avg Review velocity column

**Key Fields:**
- `momentum_ratio`: Current vs previous 90 days (>1.0 = growing, <1.0 = declining)
- `velocity_per_business_per_day`: Reviews/day/business (activity metric)
- `trend_classification`: RAPID_GROWTH, GROWING, STABLE, DECLINING, RAPID_DECLINE
- `market_temperature`: HOT, WARM, COOL, COLD

**Example Queries:**

```sql
-- Find rapidly growing markets
SELECT category, city, business_count, momentum_ratio,
       trend_classification, market_temperature
FROM review_velocity_trends
WHERE trend_classification IN ('RAPID_GROWTH', 'GROWING')
ORDER BY momentum_ratio DESC;

-- Compare market activity levels
SELECT category, city, velocity_per_business_per_day, market_temperature
FROM review_velocity_trends
WHERE city = 'Phoenix'
ORDER BY velocity_per_business_per_day DESC;

-- Track declining markets
SELECT category, city, reviews_current_90d, reviews_previous_90d,
       momentum_ratio, trend_classification
FROM review_velocity_trends
WHERE momentum_ratio < 0.9
ORDER BY momentum_ratio ASC;
```

**AI Agent Usage:**
- User: "Which categories are gaining momentum in Phoenix?"
- Query: `review_velocity_trends WHERE city = 'Phoenix' AND momentum_ratio >= 1.2`
- Response: Lists categories with accelerating growth and market temperature

---

### 6. niche_service_gaps (NEW)

**Purpose:** Identify sub-specialty opportunities within each category

**Excel Mapping:** Sheet 1 "Niches" - "Missing high potential niches" column

**Key Fields:**
- `specialty_type`: repair, restoration, maintenance, custom, design, emergency, 24/7, weekend, etc.
- `demand_supply_ratio`: Customer demand divided by current providers (higher = bigger gap)
- `gap_status`: CRITICAL_GAP, HIGH_OPPORTUNITY, MODERATE_GAP, SERVED
- `positioning_strategy`: Tactical recommendation for entering gap

**Example Queries:**

```sql
-- Find critical service gaps
SELECT category, city, specialty_type, customer_demand,
       current_providers, demand_supply_ratio, gap_status
FROM niche_service_gaps
WHERE gap_status = 'CRITICAL_GAP'
ORDER BY demand_supply_ratio DESC;

-- Find 24/7 emergency service opportunities
SELECT category, city, customer_demand, current_providers,
       positioning_strategy
FROM niche_service_gaps
WHERE specialty_type IN ('emergency', '24/7', 'weekend')
  AND gap_status IN ('CRITICAL_GAP', 'HIGH_OPPORTUNITY')
ORDER BY customer_demand DESC;

-- Find premium custom service gaps
SELECT category, city, specialty_type, customer_demand,
       sentiment_when_mentioned, positioning_strategy
FROM niche_service_gaps
WHERE specialty_type IN ('custom', 'design', 'consultation')
  AND current_providers <= 2
ORDER BY customer_demand DESC;
```

**AI Agent Usage:**
- User: "What specialized HVAC services are customers looking for in Phoenix?"
- Query: `niche_service_gaps WHERE category = 'HVAC' AND city = 'Phoenix' AND gap_status IN ('CRITICAL_GAP', 'HIGH_OPPORTUNITY')`
- Response: Lists missing specialties with demand levels and positioning strategies

---

### 7. business_model_opportunities (NEW)

**Purpose:** Validate newsletter/intermediary business model viability

**Excel Mapping:** Sheet 2 "Opportunities & TG" - Arbitrage, AOV, end customer columns

**Key Fields:**
- `newsletter_viability_score` (0-100): Overall viability (arbitrage 40%, high-ticket 30%, trust gap 20%, market size 10%)
- `arbitrage_potential`: EXCELLENT_ARBITRAGE, GOOD_ARBITRAGE, MODERATE_ARBITRAGE, LOW_ARBITRAGE
- `ticket_classification`: PREMIUM_PRICING, HIGH_TICKET, MID_TICKET, LOW_TICKET
- `customer_type`: B2B_FOCUSED, B2C_FOCUSED, B2B_LEANING, B2C_LEANING, MIXED_MARKET
- `business_model_recommendation`: Specific strategic guidance

**Example Queries:**

```sql
-- Find best newsletter opportunities
SELECT category, city, newsletter_viability_score,
       arbitrage_potential, ticket_classification,
       customer_type, business_model_recommendation
FROM business_model_opportunities
WHERE newsletter_viability_score >= 70
ORDER BY newsletter_viability_score DESC;

-- Find high-ticket B2B opportunities
SELECT category, city, high_ticket_pct, ticket_classification,
       customer_type, b2b_signals
FROM business_model_opportunities
WHERE ticket_classification IN ('PREMIUM_PRICING', 'HIGH_TICKET')
  AND customer_type IN ('B2B_FOCUSED', 'B2B_LEANING')
ORDER BY newsletter_viability_score DESC;

-- Find markets with trust deficits (intermediary opportunity)
SELECT category, city, trust_issues, trust_issue_pct,
       arbitrage_potential, business_model_recommendation
FROM business_model_opportunities
WHERE trust_issue_pct >= 10
ORDER BY trust_issue_pct DESC;
```

**AI Agent Usage:**
- User: "Can I launch a profitable HVAC newsletter in Phoenix?"
- Query: `business_model_opportunities WHERE category = 'HVAC' AND city = 'Phoenix'`
- Response: Provides viability score, arbitrage analysis, target customer profile, and strategic recommendation

---

### 8. niche_swot_analysis (NEW)

**Purpose:** Category-level SWOT analysis for competitive positioning

**Excel Mapping:** Sheet 3 "Niches related to Clay's Core S" - Strengths, Weaknesses, Opportunities

**Key Fields:**
- `primary_strength/weakness`: Dominant theme from reviews (Professionalism, Speed, Pricing, Quality)
- `strength_list/weakness_list`: Comma-separated detailed themes
- `strategic_opportunity`: Tactical recommendation for differentiation
- `market_maturity`: MATURE_MARKET, FRAGMENTED_MARKET, DEVELOPING_MARKET

**Example Queries:**

```sql
-- Get complete SWOT for a category
SELECT category, city, primary_strength, strength_list,
       primary_weakness, weakness_list,
       strategic_opportunity, market_maturity
FROM niche_swot_analysis
WHERE category = 'HVAC' AND city = 'Phoenix';

-- Find fragmented markets (high opportunity)
SELECT category, city, primary_weakness, strategic_opportunity,
       total_positive_reviews, total_negative_reviews
FROM niche_swot_analysis
WHERE market_maturity = 'FRAGMENTED_MARKET'
ORDER BY total_negative_reviews DESC;

-- Find weaknesses to exploit across markets
SELECT category, city, primary_weakness, strategic_opportunity
FROM niche_swot_analysis
WHERE primary_weakness IN ('Unprofessional Conduct', 'Pricing Issues')
ORDER BY total_negative_reviews DESC;
```

**AI Agent Usage:**
- User: "What are the competitive strengths and weaknesses in Phoenix HVAC?"
- Query: `niche_swot_analysis WHERE category = 'HVAC' AND city = 'Phoenix'`
- Response: Provides SWOT analysis with market strengths, weaknesses, opportunities, and maturity assessment

---

## Integration with AI Agent

These views are queried via the `analyze_opportunities` tool in the RAG chat interface. The AI Agent uses a cascading query strategy:

### Query Strategy Flow

```
User Question → AI Agent Decision Tree

1. "What niches are underserved?"
   └─> Query: niche_opportunities (broad market scan)

2. "What are customers complaining about?"
   └─> Query: customer_pain_points (sentiment analysis)

3. "Who are the market leaders?"
   └─> Query: market_leaders (competitive intelligence)

4. "Which businesses are vulnerable?"
   └─> Query: vulnerable_players (disruption targets)

5. "Which markets are growing?"
   └─> Query: review_velocity_trends (momentum analysis)

6. "What specialties are missing?"
   └─> Query: niche_service_gaps (sub-category opportunities)

7. "Can I launch a newsletter?"
   └─> Query: business_model_opportunities (viability validation)

8. "What are market strengths/weaknesses?"
   └─> Query: niche_swot_analysis (competitive positioning)
```

### Multi-View Query Example

**User:** "Should I launch an HVAC newsletter in Phoenix? What specialties are underserved?"

**AI Agent Execution:**

```sql
-- Step 1: Check market saturation
SELECT opportunity_score, saturation_level, business_count
FROM niche_opportunities
WHERE category = 'HVAC' AND city = 'Phoenix';

-- Step 2: Find missing specialties
SELECT specialty_type, customer_demand, current_providers, gap_status
FROM niche_service_gaps
WHERE category = 'HVAC' AND city = 'Phoenix'
  AND gap_status IN ('CRITICAL_GAP', 'HIGH_OPPORTUNITY')
ORDER BY demand_supply_ratio DESC;

-- Step 3: Validate business model
SELECT newsletter_viability_score, arbitrage_potential,
       ticket_classification, customer_type,
       business_model_recommendation
FROM business_model_opportunities
WHERE category = 'HVAC' AND city = 'Phoenix';

-- Step 4: Understand competitive landscape
SELECT primary_strength, primary_weakness,
       strategic_opportunity, market_maturity
FROM niche_swot_analysis
WHERE category = 'HVAC' AND city = 'Phoenix';
```

**Response Synthesis:**
"Phoenix HVAC shows [opportunity_score] market potential with [saturation_level]. Missing specialties include [specialty_type list]. Newsletter viability scores [score]/100 with [arbitrage_potential] arbitrage potential and [ticket_classification] pricing. Market is [market_maturity] with primary weakness of [primary_weakness]. Recommendation: [business_model_recommendation]."

---

## Performance Optimization

### Indexes Created

The schema includes 4 performance indexes:

1. **idx_review_text_trgm** - Trigram index for text search in `niche_service_gaps`
2. **idx_business_social_data** - GIN index for JSONB social data in `business_model_opportunities`
3. **idx_reviews_published_at** - Time-based queries in `review_velocity_trends`
4. **idx_reviews_business_published** - Composite index for `vulnerable_players` performance tracking

### Query Performance Tips

```sql
-- Use EXPLAIN ANALYZE to check query plans
EXPLAIN ANALYZE
SELECT * FROM niche_opportunities WHERE city = 'Phoenix';

-- Filter early for best performance
SELECT category, opportunity_score
FROM niche_opportunities
WHERE city = 'Phoenix' AND opportunity_score >= 7  -- Filter reduces result set
ORDER BY opportunity_score DESC
LIMIT 10;  -- Limit prevents full scan

-- Verify indexes are being used
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;
```

**Expected Performance:**
- Simple queries (single city filter): <50ms
- Complex aggregations (SWOT analysis): <200ms
- Full table scans: <500ms

---

## Testing Queries

### Validate All Views Exist

```sql
SELECT table_name, table_type
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name IN (
    'niche_opportunities',
    'customer_pain_points',
    'market_leaders',
    'vulnerable_players',
    'review_velocity_trends',
    'niche_service_gaps',
    'business_model_opportunities',
    'niche_swot_analysis'
  )
ORDER BY table_name;
-- Expected: 8 rows
```

### Validate Views Return Data

```sql
SELECT 'niche_opportunities' as view, count(*) as rows FROM niche_opportunities
UNION ALL SELECT 'customer_pain_points', count(*) FROM customer_pain_points
UNION ALL SELECT 'market_leaders', count(*) FROM market_leaders
UNION ALL SELECT 'vulnerable_players', count(*) FROM vulnerable_players
UNION ALL SELECT 'review_velocity_trends', count(*) FROM review_velocity_trends
UNION ALL SELECT 'niche_service_gaps', count(*) FROM niche_service_gaps
UNION ALL SELECT 'business_model_opportunities', count(*) FROM business_model_opportunities
UNION ALL SELECT 'niche_swot_analysis', count(*) FROM niche_swot_analysis;
-- Expected: All counts > 0 (with real data loaded)
```

### Validate Scoring Ranges

```sql
-- Check opportunity_score range (0-10)
SELECT MIN(opportunity_score), MAX(opportunity_score)
FROM niche_opportunities;

-- Check inc_score range (0-100)
SELECT MIN(inc_score), MAX(inc_score)
FROM market_leaders;

-- Check vulnerability_score range (0-100)
SELECT MIN(vulnerability_score), MAX(vulnerability_score)
FROM vulnerable_players;

-- Check newsletter_viability_score range (0-100)
SELECT MIN(newsletter_viability_score), MAX(newsletter_viability_score)
FROM business_model_opportunities;
```

---

## Common Use Cases

### 1. Market Entry Analysis

**Question:** "Where should I enter the home services market?"

**Query Strategy:**
1. Find underserved niches: `niche_opportunities` (opportunity_score >= 7)
2. Check growth momentum: `review_velocity_trends` (momentum_ratio >= 1.0)
3. Identify gaps: `niche_service_gaps` (gap_status = 'CRITICAL_GAP')
4. Avoid strong incumbents: `market_leaders` (inc_score < 70)

### 2. Competitive Intelligence

**Question:** "Who are my competitors and how do I differentiate?"

**Query Strategy:**
1. Find market leaders: `market_leaders` (by category/city)
2. Analyze SWOT: `niche_swot_analysis` (strengths to match, weaknesses to exploit)
3. Find pain points: `customer_pain_points` (unmet needs)
4. Identify vulnerable targets: `vulnerable_players` (potential acquisition targets)

### 3. Business Model Validation

**Question:** "Can I launch a newsletter/platform in this niche?"

**Query Strategy:**
1. Check viability: `business_model_opportunities` (newsletter_viability_score >= 60)
2. Validate arbitrage: `business_model_opportunities` (arbitrage_potential, market_fragmentation)
3. Confirm ticket size: `business_model_opportunities` (ticket_classification)
4. Define ICP: `business_model_opportunities` (customer_type)

### 4. Product Development

**Question:** "What services should I offer?"

**Query Strategy:**
1. Find service gaps: `niche_service_gaps` (CRITICAL_GAP specialties)
2. Prioritize pain points: `customer_pain_points` (primary_pain_point)
3. Check demand: `niche_service_gaps` (customer_demand, sentiment_when_mentioned)
4. Get positioning: `niche_service_gaps` (positioning_strategy)

---

## Next Steps

1. **Import SQL to Production:**
   ```bash
   psql "postgresql://your-connection-string" -f schema/03-strategic-views.sql
   ```

2. **Load Test Data:**
   ```bash
   psql "postgresql://your-connection-string" -f schema/test-data.sql
   ```

3. **Test Views:**
   Run validation queries above to confirm all views return data

4. **Update AI Agent:**
   Add view documentation to RAG system prompt (see Integration section)

5. **Test End-to-End:**
   Ask strategic questions via RAG chat interface and verify AI uses correct views

---

## Troubleshooting

### View Returns No Rows

**Cause:** Insufficient test data or filters too restrictive

**Solution:**
```sql
-- Check base table counts
SELECT COUNT(*) FROM businesses;
SELECT COUNT(*) FROM business_reviews;

-- Relax filters
SELECT * FROM niche_opportunities LIMIT 10;  -- Remove WHERE clause
```

### Slow Query Performance

**Cause:** Missing indexes or full table scans

**Solution:**
```sql
-- Check index usage
EXPLAIN ANALYZE SELECT * FROM niche_service_gaps WHERE city = 'Phoenix';

-- Verify indexes exist
SELECT indexname FROM pg_indexes WHERE tablename IN ('businesses', 'business_reviews');
```

### View Definition Error

**Cause:** Missing pg_trgm extension for text search

**Solution:**
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

---

**Last Updated:** 10/13/2025

**Schema Version:** 03-strategic-views.sql

**Dependencies:** 01-tables.sql, 02-indexes.sql, test-data.sql
