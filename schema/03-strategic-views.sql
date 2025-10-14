-- ============================================================================
-- Strategic Analysis Views - Intelligence Layer
-- ============================================================================
-- Purpose: Materialize market intelligence insights from raw business data
-- Dependencies: schema/01-tables.sql (businesses, business_reviews)
-- Layer: Intelligence Layer (separates insights from raw data)
-- Source: Excel strategic analysis framework (3-sheet workbook)
-- ============================================================================

-- ============================================================================
-- VIEW 1: niche_opportunities
-- ============================================================================
-- Purpose: Identify market gaps and saturation levels per category
-- Excel source: Sheet 1 "Niches" - Provider density, avg rating, review velocity
-- Use case: "What niches are underserved in Phoenix?"
-- ============================================================================

CREATE OR REPLACE VIEW niche_opportunities AS
SELECT
  category,
  city,
  COUNT(*) as business_count,
  ROUND(AVG(rating), 2) as avg_category_rating,
  SUM(review_count) as total_category_reviews,

  -- Saturation classification (Excel: Provider density)
  CASE
    WHEN COUNT(*) >= 50 THEN 'HIGH_SATURATION'
    WHEN COUNT(*) BETWEEN 10 AND 49 THEN 'MEDIUM_SATURATION'
    WHEN COUNT(*) BETWEEN 5 AND 9 THEN 'LOW_COMPETITION'
    ELSE 'WIDE_OPEN'
  END as saturation_level,

  -- Opportunity scoring (inverse of saturation + demand signal)
  CASE
    WHEN COUNT(*) < 5 AND SUM(review_count) > 100 THEN 10
    WHEN COUNT(*) < 10 THEN 8
    WHEN COUNT(*) BETWEEN 10 AND 30 THEN 6
    WHEN COUNT(*) BETWEEN 31 AND 50 THEN 4
    ELSE 2
  END as opportunity_score,

  -- Top 3 players in this niche
  (ARRAY_AGG(
    business_name ORDER BY rating DESC, review_count DESC
  ) FILTER (WHERE rating >= 4.5))[1:3] as top_players,

  MAX(created_at) as last_updated

FROM businesses
WHERE category IS NOT NULL
GROUP BY category, city
HAVING COUNT(*) >= 1
ORDER BY opportunity_score DESC, business_count ASC;

COMMENT ON VIEW niche_opportunities IS
'Market gap analysis: identifies underserved categories with high opportunity scores.
Higher scores = fewer competitors + strong demand signals. Maps to Excel Sheet 1: Provider density analysis.';


-- ============================================================================
-- VIEW 2: customer_pain_points
-- ============================================================================
-- Purpose: Extract unmet needs from negative reviews
-- Excel source: Sheet 3 "Niches related to Clay's Core S" - Weaknesses column
-- Use case: "What are customers complaining about most in HVAC?"
-- ============================================================================

CREATE OR REPLACE VIEW customer_pain_points AS
WITH negative_reviews AS (
  SELECT
    b.category,
    b.city,
    r.review_text,
    r.stars
  FROM business_reviews r
  JOIN businesses b ON b.id = r.business_id
  WHERE r.stars <= 2 AND r.review_text IS NOT NULL
),
pain_categories AS (
  SELECT
    category,
    city,

    COUNT(*) FILTER (
      WHERE review_text ~* '\y(expensive|overpriced|cost|price|fee|charge|hidden|ripoff)\y'
    ) as pricing_complaints,

    COUNT(*) FILTER (
      WHERE review_text ~* '\y(late|delayed|wait|schedule|appointment|time|slow)\y'
    ) as scheduling_complaints,

    COUNT(*) FILTER (
      WHERE review_text ~* '\y(poor|bad|terrible|awful|shoddy|cheap|broken|wrong)\y'
    ) as quality_complaints,

    COUNT(*) FILTER (
      WHERE review_text ~* '\y(rude|unprofessional|ignored|communication|response|callback)\y'
    ) as communication_complaints,

    COUNT(*) FILTER (
      WHERE review_text ~* '\y(unavailable|closed|weekend|emergency|24/7|never|busy)\y'
    ) as availability_complaints,

    COUNT(*) as total_complaints,

    STRING_AGG(
      SUBSTRING(review_text, 1, 100),
      ' | '
    ) FILTER (WHERE stars = 1) as sample_complaints

  FROM negative_reviews
  GROUP BY category, city
)
SELECT
  category,
  city,
  total_complaints,

  pricing_complaints,
  ROUND(100.0 * pricing_complaints / NULLIF(total_complaints, 0), 1) as pricing_pct,

  scheduling_complaints,
  ROUND(100.0 * scheduling_complaints / NULLIF(total_complaints, 0), 1) as scheduling_pct,

  quality_complaints,
  ROUND(100.0 * quality_complaints / NULLIF(total_complaints, 0), 1) as quality_pct,

  communication_complaints,
  ROUND(100.0 * communication_complaints / NULLIF(total_complaints, 0), 1) as communication_pct,

  availability_complaints,
  ROUND(100.0 * availability_complaints / NULLIF(total_complaints, 0), 1) as availability_pct,

  CASE
    WHEN pricing_complaints >= ALL(ARRAY[scheduling_complaints, quality_complaints, communication_complaints, availability_complaints])
      THEN 'Pricing Transparency'
    WHEN scheduling_complaints >= ALL(ARRAY[pricing_complaints, quality_complaints, communication_complaints, availability_complaints])
      THEN 'Scheduling Flexibility'
    WHEN quality_complaints >= ALL(ARRAY[pricing_complaints, scheduling_complaints, communication_complaints, availability_complaints])
      THEN 'Service Quality'
    WHEN communication_complaints >= ALL(ARRAY[pricing_complaints, scheduling_complaints, quality_complaints, availability_complaints])
      THEN 'Professional Communication'
    ELSE 'Availability & Hours'
  END as primary_pain_point,

  sample_complaints

FROM pain_categories
WHERE total_complaints >= 3
ORDER BY total_complaints DESC;

COMMENT ON VIEW customer_pain_points IS
'Sentiment analysis of negative reviews to identify unmet customer needs.
Extracts pain points by category: pricing, scheduling, quality, communication, availability.
Maps to Excel Sheet 3: Weaknesses analysis.';


-- ============================================================================
-- VIEW 3: market_leaders
-- ============================================================================
-- Purpose: Identify dominant incumbents to avoid direct competition
-- Excel source: Sheet 3 "Niches related to Clay's Core S" - Top businesses to watch
-- Use case: "Who are the market leaders I should NOT compete with?"
-- ============================================================================

CREATE OR REPLACE VIEW market_leaders AS
WITH business_metrics AS (
  SELECT
    b.id,
    b.business_name,
    b.category,
    b.city,
    b.rating,
    b.review_count,
    b.website,
    b.phone,

    -- Rating consistency (lower variance = more consistent quality)
    COALESCE(
      SQRT(
        (
          POWER(1 - COALESCE(b.rating, 3.0), 2) * COALESCE((b.business_data->'rating'->'reviewsDistribution'->>'oneStar')::int, 0) +
          POWER(2 - COALESCE(b.rating, 3.0), 2) * COALESCE((b.business_data->'rating'->'reviewsDistribution'->>'twoStar')::int, 0) +
          POWER(3 - COALESCE(b.rating, 3.0), 2) * COALESCE((b.business_data->'rating'->'reviewsDistribution'->>'threeStar')::int, 0) +
          POWER(4 - COALESCE(b.rating, 3.0), 2) * COALESCE((b.business_data->'rating'->'reviewsDistribution'->>'fourStar')::int, 0) +
          POWER(5 - COALESCE(b.rating, 3.0), 2) * COALESCE((b.business_data->'rating'->'reviewsDistribution'->>'fiveStar')::int, 0)
        )::float / NULLIF(b.review_count, 0)
      ),
      0.5
    ) as rating_variance,

    -- Recent activity (growth momentum)
    COUNT(r.id) FILTER (
      WHERE r.published_at >= CURRENT_DATE - INTERVAL '90 days'
    ) as recent_reviews_90d,

    -- Digital presence
    (CASE WHEN b.business_data->'social'->>'instagrams' IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN b.business_data->'social'->>'facebookPages' IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN b.website IS NOT NULL AND b.website != '' THEN 1 ELSE 0 END) as digital_presence_score

  FROM businesses b
  LEFT JOIN business_reviews r ON r.business_id = b.id
  GROUP BY b.id, b.business_name, b.category, b.city, b.rating, b.review_count, b.website, b.phone, b.business_data
)
SELECT
  *,

  -- INC (Incumbent) Score: 0-100 scale
  ROUND(
    (
      -- Rating weight (40 points)
      (COALESCE(rating, 0) / 5.0) * 40 +

      -- Volume weight (30 points)
      LEAST((COALESCE(review_count, 0)::float / 200), 1.0) * 30 +

      -- Consistency weight (20 points) - inverse of variance
      (1.0 - LEAST(rating_variance, 1.0)) * 20 +

      -- Growth momentum weight (10 points)
      LEAST((recent_reviews_90d::float / 20), 1.0) * 10
    )::numeric,
    1
  ) as inc_score,

  -- Market position classification
  CASE
    WHEN rating >= 4.5 AND review_count >= 100 THEN 'DOMINANT_LEADER'
    WHEN rating >= 4.3 AND review_count >= 50 THEN 'STRONG_INCUMBENT'
    WHEN rating >= 4.0 AND review_count >= 30 THEN 'ESTABLISHED_PLAYER'
    ELSE 'EMERGING_BUSINESS'
  END as market_position

FROM business_metrics
WHERE review_count >= 20  -- Minimum threshold for leadership consideration
ORDER BY inc_score DESC;

COMMENT ON VIEW market_leaders IS
'Identifies dominant incumbents using INC (Incumbent) score (0-100).
Factors: rating (40%), volume (30%), consistency (20%), momentum (10%).
Maps to Excel Sheet 3: Top businesses to watch.';


-- ============================================================================
-- VIEW 4: vulnerable_players
-- ============================================================================
-- Purpose: Find underperforming businesses ripe for disruption
-- Excel source: Sheet 3 "Niches related to Clay's Core S" - Top but underperforming
-- Use case: "Which established businesses are vulnerable to new competition?"
-- ============================================================================

CREATE OR REPLACE VIEW vulnerable_players AS
WITH recent_performance AS (
  SELECT
    b.id,
    b.business_name,
    b.category,
    b.city,
    b.rating as overall_rating,
    b.review_count,

    -- Recent vs historical performance
    AVG(r.stars) FILTER (
      WHERE r.published_at >= CURRENT_DATE - INTERVAL '90 days'
    ) as recent_rating_90d,

    AVG(r.stars) FILTER (
      WHERE r.published_at < CURRENT_DATE - INTERVAL '90 days'
    ) as historical_rating,

    COUNT(*) FILTER (
      WHERE r.published_at >= CURRENT_DATE - INTERVAL '90 days'
    ) as recent_review_count,

    -- Negative sentiment surge
    COUNT(*) FILTER (
      WHERE r.stars <= 2
        AND r.published_at >= CURRENT_DATE - INTERVAL '90 days'
    ) as recent_negative_reviews

  FROM businesses b
  LEFT JOIN business_reviews r ON r.business_id = b.id
  GROUP BY b.id, b.business_name, b.category, b.city, b.rating, b.review_count
  HAVING COUNT(*) >= 10  -- Minimum review threshold
)
SELECT
  *,

  -- Decline momentum (negative = declining)
  ROUND((recent_rating_90d - historical_rating)::numeric, 2) as rating_momentum,

  -- Vulnerability score (0-100, higher = more vulnerable)
  ROUND(
    (
      -- Declining rating (40 points)
      GREATEST(
        ((historical_rating - recent_rating_90d) / 2.0) * 40,
        0
      ) +

      -- Low recent rating (30 points)
      (1.0 - (COALESCE(recent_rating_90d, overall_rating) / 5.0)) * 30 +

      -- High negative review ratio (20 points)
      (recent_negative_reviews::float / NULLIF(recent_review_count, 0)) * 20 +

      -- Established presence penalty (10 points - bigger fall)
      LEAST((review_count::float / 100), 1.0) * 10
    )::numeric,
    1
  ) as vulnerability_score,

  -- Classification
  CASE
    WHEN recent_rating_90d < historical_rating - 0.5
      AND review_count > 50
      THEN 'HIGH_DISRUPTION_TARGET'
    WHEN recent_rating_90d < 3.5
      AND review_count > 30
      THEN 'DECLINING_INCUMBENT'
    WHEN recent_negative_reviews::float / NULLIF(recent_review_count, 0) > 0.3
      THEN 'REPUTATION_CRISIS'
    ELSE 'MODERATE_VULNERABILITY'
  END as vulnerability_classification

FROM recent_performance
WHERE recent_rating_90d < historical_rating - 0.2  -- At least 0.2 star decline
   OR recent_rating_90d < 3.5  -- Or low absolute rating
ORDER BY vulnerability_score DESC;

COMMENT ON VIEW vulnerable_players IS
'Identifies underperforming businesses vulnerable to disruption.
Tracks rating decline, negative sentiment surges, and reputation crises.
Maps to Excel Sheet 3: Top but underperforming businesses.';


-- ============================================================================
-- VIEW 5: review_velocity_trends
-- ============================================================================
-- Purpose: Track growth momentum and market activity levels
-- Excel source: Sheet 1 "Niches" - Avg Review velocity column
-- Use case: "Which categories are gaining momentum vs declining?"
-- ============================================================================

CREATE OR REPLACE VIEW review_velocity_trends AS
WITH time_periods AS (
  SELECT
    b.category,
    b.city,

    -- Current period (last 90 days)
    COUNT(*) FILTER (
      WHERE r.published_at >= CURRENT_DATE - INTERVAL '90 days'
    ) as reviews_current_90d,

    -- Previous period (91-180 days ago)
    COUNT(*) FILTER (
      WHERE r.published_at >= CURRENT_DATE - INTERVAL '180 days'
        AND r.published_at < CURRENT_DATE - INTERVAL '90 days'
    ) as reviews_previous_90d,

    -- Historical baseline (181-360 days ago)
    COUNT(*) FILTER (
      WHERE r.published_at >= CURRENT_DATE - INTERVAL '360 days'
        AND r.published_at < CURRENT_DATE - INTERVAL '180 days'
    ) as reviews_historical_180d,

    -- Total review volume
    COUNT(*) as total_reviews,

    -- Business count
    COUNT(DISTINCT b.id) as business_count

  FROM businesses b
  LEFT JOIN business_reviews r ON r.business_id = b.id
  WHERE b.category IS NOT NULL
  GROUP BY b.category, b.city
  HAVING COUNT(DISTINCT b.id) >= 3  -- Minimum 3 businesses
)
SELECT
  category,
  city,
  business_count,
  total_reviews,
  reviews_current_90d,
  reviews_previous_90d,

  -- Review velocity (reviews per day per business)
  ROUND(
    (reviews_current_90d::float / NULLIF(business_count, 0) / 90)::numeric,
    3
  ) as velocity_per_business_per_day,

  -- Momentum ratio (>1.0 = accelerating, <1.0 = decelerating)
  ROUND(
    (reviews_current_90d::float / NULLIF(reviews_previous_90d, 0))::numeric,
    2
  ) as momentum_ratio,

  -- Trend classification
  CASE
    WHEN reviews_current_90d::float / NULLIF(reviews_previous_90d, 0) >= 1.5
      THEN 'RAPID_GROWTH'
    WHEN reviews_current_90d::float / NULLIF(reviews_previous_90d, 0) >= 1.1
      THEN 'GROWING'
    WHEN reviews_current_90d::float / NULLIF(reviews_previous_90d, 0) >= 0.9
      THEN 'STABLE'
    WHEN reviews_current_90d::float / NULLIF(reviews_previous_90d, 0) >= 0.7
      THEN 'DECLINING'
    ELSE 'RAPID_DECLINE'
  END as trend_classification,

  -- Market temperature (activity level)
  CASE
    WHEN reviews_current_90d::float / business_count >= 30 THEN 'HOT'
    WHEN reviews_current_90d::float / business_count >= 15 THEN 'WARM'
    WHEN reviews_current_90d::float / business_count >= 5 THEN 'COOL'
    ELSE 'COLD'
  END as market_temperature

FROM time_periods
WHERE reviews_previous_90d > 0  -- Need historical data for comparison
ORDER BY momentum_ratio DESC;

COMMENT ON VIEW review_velocity_trends IS
'Tracks market momentum through review velocity and trend analysis.
Maps to Excel Sheet 1: Avg Review velocity (reviews per period per business).';


-- ============================================================================
-- VIEW 6: niche_service_gaps (NEW - from Excel)
-- ============================================================================
-- Purpose: Identify sub-specialty opportunities within each category
-- Excel source: Sheet 1 "Niches" - "Missing high potential niches" column
-- Use case: "What specialized services are customers looking for but can't find?"
-- Example: "hardscape design" missing "Specialized Hardscape Repair & Restoration"
-- ============================================================================

CREATE OR REPLACE VIEW niche_service_gaps AS
WITH service_keywords AS (
  -- Extract service specialty keywords from reviews
  SELECT
    b.category,
    b.city,
    UNNEST(
      regexp_matches(
        LOWER(r.review_text),
        '\y(repair|restoration|maintenance|custom|design|emergency|24/7|weekend|consultation|installation|inspection|warranty)\y',
        'g'
      )
    ) as service_keyword,
    r.stars
  FROM businesses b
  JOIN business_reviews r ON r.business_id = b.id
  WHERE r.review_text IS NOT NULL
),
demand_signals AS (
  -- Count how often each specialty is mentioned
  SELECT
    category,
    city,
    service_keyword,
    COUNT(*) as mention_frequency,
    AVG(stars) as avg_mention_sentiment
  FROM service_keywords
  GROUP BY category, city, service_keyword
),
current_supply AS (
  -- Count how many businesses explicitly offer each specialty
  SELECT
    category,
    city,
    service_keyword,
    COUNT(DISTINCT b.id) as provider_count
  FROM businesses b
  CROSS JOIN LATERAL (
    SELECT UNNEST(ARRAY['repair', 'restoration', 'maintenance', 'custom', 'design',
                         'emergency', '24/7', 'weekend', 'consultation', 'installation',
                         'inspection', 'warranty']) as keyword
  ) keywords
  WHERE LOWER(b.business_name) LIKE '%' || keywords.keyword || '%'
     OR LOWER(b.business_data::text) LIKE '%' || keywords.keyword || '%'
  GROUP BY b.category, b.city, keywords.keyword
)
SELECT
  ds.category,
  ds.city,
  ds.service_keyword as specialty_type,
  ds.mention_frequency as customer_demand,
  COALESCE(cs.provider_count, 0) as current_providers,
  ROUND(ds.avg_mention_sentiment::numeric, 2) as sentiment_when_mentioned,

  -- Gap severity (high demand + low supply = big opportunity)
  ROUND(
    (ds.mention_frequency::float / GREATEST(COALESCE(cs.provider_count, 0), 1))::numeric,
    2
  ) as demand_supply_ratio,

  -- Gap classification
  CASE
    WHEN COALESCE(cs.provider_count, 0) = 0 AND ds.mention_frequency >= 10
      THEN 'CRITICAL_GAP'
    WHEN COALESCE(cs.provider_count, 0) <= 2 AND ds.mention_frequency >= 15
      THEN 'HIGH_OPPORTUNITY'
    WHEN COALESCE(cs.provider_count, 0) <= 5 AND ds.mention_frequency >= 20
      THEN 'MODERATE_GAP'
    ELSE 'SERVED'
  END as gap_status,

  -- Strategic recommendation
  CASE
    WHEN ds.service_keyword IN ('emergency', '24/7', 'weekend')
      THEN 'Position as always-available specialist'
    WHEN ds.service_keyword IN ('custom', 'design', 'consultation')
      THEN 'Emphasize premium, personalized service'
    WHEN ds.service_keyword IN ('repair', 'restoration', 'maintenance')
      THEN 'Focus on reliability and warranty guarantees'
    ELSE 'Differentiate on ' || ds.service_keyword || ' expertise'
  END as positioning_strategy

FROM demand_signals ds
LEFT JOIN current_supply cs USING (category, city, service_keyword)
WHERE ds.mention_frequency >= 5  -- Minimum demand threshold
ORDER BY
  CASE
    WHEN COALESCE(cs.provider_count, 0) = 0 AND ds.mention_frequency >= 10 THEN 1
    WHEN COALESCE(cs.provider_count, 0) <= 2 AND ds.mention_frequency >= 15 THEN 2
    ELSE 3
  END,
  ds.mention_frequency DESC;

COMMENT ON VIEW niche_service_gaps IS
'Identifies sub-specialty gaps within categories by comparing customer demand (review mentions)
to current supply (businesses offering that specialty). Maps to Excel Sheet 1:
"Missing high potential niches" column. Example: HVAC category missing "24/7 emergency repair" specialty.';


-- ============================================================================
-- VIEW 7: business_model_opportunities (NEW - from Excel)
-- ============================================================================
-- Purpose: Validate newsletter/intermediary business model viability (arbitrage + AOV)
-- Excel source: Sheet 2 "Opportunities & TG" - Arbitrage, AOV, end customer columns
-- Use case: "Can I launch a profitable newsletter connecting customers to vendors?"
-- Key metrics: Market fragmentation, price points, customer clarity
-- ============================================================================

CREATE OR REPLACE VIEW business_model_opportunities AS
WITH price_signals AS (
  SELECT
    b.category,
    b.city,

    -- High-ticket indicators (AOV analysis)
    COUNT(*) FILTER (
      WHERE r.review_text ~* '\$[0-9]{3,5}'  -- $100-$99,999 mentions
        OR r.review_text ~* '\y(thousand|expensive|quote|estimate|bid|consultation|custom)\y'
    ) as high_ticket_mentions,

    COUNT(*) as total_reviews,

    -- Market fragmentation (arbitrage viability)
    COUNT(DISTINCT b.id) as provider_count,
    STDDEV(b.rating) as rating_inconsistency,

    -- Customer type clarity (ICP definition)
    COUNT(*) FILTER (
      WHERE r.review_text ~* '\y(property manager|landlord|commercial|business|company|office)\y'
    ) as b2b_signals,

    COUNT(*) FILTER (
      WHERE r.review_text ~* '\y(homeowner|house|my home|residential|family|personal)\y'
    ) as b2c_signals,

    -- Trust deficit indicators (opportunity for trusted intermediary)
    COUNT(*) FILTER (
      WHERE r.stars <= 2
        AND r.review_text ~* '\y(scam|ripoff|dishonest|overcharge|hidden fee|bait)\y'
    ) as trust_issues

  FROM businesses b
  JOIN business_reviews r ON r.business_id = b.id
  GROUP BY b.category, b.city
)
SELECT
  category,
  city,
  provider_count,
  total_reviews,

  -- AOV (Average Order Value) Classification
  ROUND(100.0 * high_ticket_mentions / NULLIF(total_reviews, 0), 1) as high_ticket_pct,
  CASE
    WHEN high_ticket_mentions::float / NULLIF(total_reviews, 0) > 0.25 THEN 'PREMIUM_PRICING'
    WHEN high_ticket_mentions::float / NULLIF(total_reviews, 0) > 0.15 THEN 'HIGH_TICKET'
    WHEN high_ticket_mentions::float / NULLIF(total_reviews, 0) > 0.08 THEN 'MID_TICKET'
    ELSE 'LOW_TICKET'
  END as ticket_classification,

  -- Arbitrage Potential (newsletter/platform viability)
  ROUND(rating_inconsistency::numeric, 2) as market_fragmentation,
  CASE
    WHEN provider_count > 20
      AND rating_inconsistency > 0.6
      AND high_ticket_mentions::float / NULLIF(total_reviews, 0) > 0.15
      AND trust_issues > 5
    THEN 'EXCELLENT_ARBITRAGE'
    WHEN provider_count > 15
      AND rating_inconsistency > 0.4
      AND high_ticket_mentions::float / NULLIF(total_reviews, 0) > 0.10
    THEN 'GOOD_ARBITRAGE'
    WHEN provider_count > 10 AND rating_inconsistency > 0.3
    THEN 'MODERATE_ARBITRAGE'
    ELSE 'LOW_ARBITRAGE'
  END as arbitrage_potential,

  -- Target Customer Profile (ICP)
  b2b_signals,
  b2c_signals,
  CASE
    WHEN b2b_signals > b2c_signals * 3 THEN 'B2B_FOCUSED'
    WHEN b2c_signals > b2b_signals * 3 THEN 'B2C_FOCUSED'
    WHEN b2b_signals > b2c_signals * 1.5 THEN 'B2B_LEANING'
    WHEN b2c_signals > b2b_signals * 1.5 THEN 'B2C_LEANING'
    ELSE 'MIXED_MARKET'
  END as customer_type,

  -- Trust deficit (higher = more need for trusted intermediary)
  trust_issues,
  ROUND(100.0 * trust_issues / NULLIF(total_reviews, 0), 1) as trust_issue_pct,

  -- Overall newsletter viability score (0-100)
  ROUND(
    (
      -- Arbitrage weight (40 points)
      LEAST(rating_inconsistency * 40, 40) +

      -- High-ticket weight (30 points)
      (high_ticket_mentions::float / NULLIF(total_reviews, 0)) * 30 +

      -- Trust gap weight (20 points)
      LEAST((trust_issues::float / NULLIF(total_reviews, 0)) * 100, 20) +

      -- Market size weight (10 points)
      LEAST((provider_count::float / 50) * 10, 10)
    )::numeric,
    1
  ) as newsletter_viability_score,

  -- Strategic recommendation
  CASE
    WHEN rating_inconsistency > 0.6 AND high_ticket_mentions::float / NULLIF(total_reviews, 0) > 0.15
      THEN 'High-value curation newsletter: "Vetted Premium Providers"'
    WHEN trust_issues > 5 AND provider_count > 15
      THEN 'Trust-focused aggregator: "Certified & Reviewed Professionals"'
    WHEN b2b_signals > b2c_signals * 2
      THEN 'B2B lead generation platform targeting property managers'
    WHEN provider_count > 30 AND rating_inconsistency > 0.4
      THEN 'Local marketplace with quality guarantees'
    ELSE 'Standard directory/referral newsletter'
  END as business_model_recommendation

FROM price_signals
WHERE total_reviews >= 20  -- Minimum data for analysis
ORDER BY newsletter_viability_score DESC;

COMMENT ON VIEW business_model_opportunities IS
'Validates newsletter/intermediary business model viability. Analyzes market fragmentation (arbitrage),
price points (AOV), customer segments (ICP), and trust gaps. Maps to Excel Sheet 2:
"Opportunity that is underserved", "Arbitrage", "AOV", "Who are their end customers" columns.';


-- ============================================================================
-- VIEW 8: niche_swot_analysis (NEW - from Excel)
-- ============================================================================
-- Purpose: Category-level SWOT analysis for competitive positioning
-- Excel source: Sheet 3 "Niches related to Clay's Core S" - Strengths, Weaknesses, Opportunities
-- Use case: "What are the competitive strengths and weaknesses in the HVAC market?"
-- ============================================================================

CREATE OR REPLACE VIEW niche_swot_analysis AS
WITH positive_themes AS (
  -- Extract strengths from high-rated reviews
  SELECT
    b.category,
    b.city,

    COUNT(*) FILTER (
      WHERE r.review_text ~* '\y(professional|expert|knowledgeable|certified|experienced|skilled)\y'
        AND r.stars >= 4
    ) as professionalism_strength,

    COUNT(*) FILTER (
      WHERE r.review_text ~* '\y(fast|quick|timely|on time|punctual|responsive|immediate)\y'
        AND r.stars >= 4
    ) as speed_strength,

    COUNT(*) FILTER (
      WHERE r.review_text ~* '\y(fair price|reasonable|affordable|value|transparent|upfront)\y'
        AND r.stars >= 4
    ) as pricing_strength,

    COUNT(*) FILTER (
      WHERE r.review_text ~* '\y(quality|excellent|perfect|outstanding|thorough|detailed)\y'
        AND r.stars >= 4
    ) as quality_strength,

    COUNT(*) as total_positive_reviews

  FROM businesses b
  JOIN business_reviews r ON r.business_id = b.id
  WHERE r.stars >= 4
  GROUP BY b.category, b.city
),
negative_themes AS (
  -- Extract weaknesses from low-rated reviews
  SELECT
    b.category,
    b.city,

    COUNT(*) FILTER (
      WHERE r.review_text ~* '\y(unprofessional|rude|disrespectful|arrogant|dismissive)\y'
    ) as professionalism_weakness,

    COUNT(*) FILTER (
      WHERE r.review_text ~* '\y(slow|late|delayed|waiting|never showed|missed appointment)\y'
    ) as speed_weakness,

    COUNT(*) FILTER (
      WHERE r.review_text ~* '\y(expensive|overpriced|ripoff|hidden fee|upcharge)\y'
    ) as pricing_weakness,

    COUNT(*) FILTER (
      WHERE r.review_text ~* '\y(poor quality|shoddy|incomplete|mistake|damage|broken)\y'
    ) as quality_weakness,

    COUNT(*) as total_negative_reviews

  FROM businesses b
  JOIN business_reviews r ON r.business_id = b.id
  WHERE r.stars <= 3
  GROUP BY b.category, b.city
)
SELECT
  COALESCE(p.category, n.category) as category,
  COALESCE(p.city, n.city) as city,

  -- STRENGTHS (top positive theme)
  CASE
    WHEN p.professionalism_strength >= GREATEST(p.speed_strength, p.pricing_strength, p.quality_strength)
      THEN 'Professionalism & Expertise'
    WHEN p.speed_strength >= GREATEST(p.professionalism_strength, p.pricing_strength, p.quality_strength)
      THEN 'Speed & Responsiveness'
    WHEN p.pricing_strength >= GREATEST(p.professionalism_strength, p.speed_strength, p.quality_strength)
      THEN 'Fair & Transparent Pricing'
    ELSE 'Quality Workmanship'
  END as primary_strength,

  ARRAY_TO_STRING(
    ARRAY[
      CASE WHEN p.professionalism_strength > p.total_positive_reviews * 0.1 THEN 'Professional service' END,
      CASE WHEN p.speed_strength > p.total_positive_reviews * 0.1 THEN 'Fast response' END,
      CASE WHEN p.pricing_strength > p.total_positive_reviews * 0.1 THEN 'Fair pricing' END,
      CASE WHEN p.quality_strength > p.total_positive_reviews * 0.1 THEN 'Quality work' END
    ]::text[],
    ', '
  ) as strength_list,

  -- WEAKNESSES (top negative theme)
  CASE
    WHEN n.professionalism_weakness >= GREATEST(n.speed_weakness, n.pricing_weakness, n.quality_weakness)
      THEN 'Unprofessional Conduct'
    WHEN n.speed_weakness >= GREATEST(n.professionalism_weakness, n.pricing_weakness, n.quality_weakness)
      THEN 'Slow/Unreliable Service'
    WHEN n.pricing_weakness >= GREATEST(n.professionalism_weakness, n.speed_weakness, n.quality_weakness)
      THEN 'Pricing Issues'
    ELSE 'Quality Concerns'
  END as primary_weakness,

  ARRAY_TO_STRING(
    ARRAY[
      CASE WHEN n.professionalism_weakness > n.total_negative_reviews * 0.15 THEN 'Unprofessional behavior' END,
      CASE WHEN n.speed_weakness > n.total_negative_reviews * 0.15 THEN 'Delays & no-shows' END,
      CASE WHEN n.pricing_weakness > n.total_negative_reviews * 0.15 THEN 'Overpricing & hidden fees' END,
      CASE WHEN n.quality_weakness > n.total_negative_reviews * 0.15 THEN 'Poor workmanship' END
    ]::text[],
    ', '
  ) as weakness_list,

  -- OPPORTUNITIES (how to exploit weaknesses)
  CASE
    WHEN n.professionalism_weakness >= GREATEST(n.speed_weakness, n.pricing_weakness, n.quality_weakness)
      THEN 'Differentiate on professionalism: Certified technicians, background checks, communication standards'
    WHEN n.speed_weakness >= GREATEST(n.professionalism_weakness, n.pricing_weakness, n.quality_weakness)
      THEN 'Guarantee response times: Same-day service, real-time tracking, automated scheduling'
    WHEN n.pricing_weakness >= GREATEST(n.professionalism_weakness, n.speed_weakness, n.quality_weakness)
      THEN 'Transparent pricing model: Upfront quotes, price-match guarantees, no hidden fees'
    ELSE 'Quality assurance program: Warranties, inspections, satisfaction guarantees'
  END as strategic_opportunity,

  -- Market maturity assessment
  CASE
    WHEN p.total_positive_reviews > n.total_negative_reviews * 5
      THEN 'MATURE_MARKET'  -- High satisfaction
    WHEN n.total_negative_reviews > p.total_positive_reviews * 0.5
      THEN 'FRAGMENTED_MARKET'  -- High dissatisfaction = opportunity
    ELSE 'DEVELOPING_MARKET'
  END as market_maturity,

  p.total_positive_reviews,
  n.total_negative_reviews

FROM positive_themes p
FULL OUTER JOIN negative_themes n USING (category, city)
WHERE COALESCE(p.total_positive_reviews, 0) + COALESCE(n.total_negative_reviews, 0) >= 15
ORDER BY n.total_negative_reviews DESC NULLS LAST;

COMMENT ON VIEW niche_swot_analysis IS
'Category-level SWOT analysis. Identifies market strengths (what competitors do well),
weaknesses (pain points), and strategic opportunities (how to differentiate).
Maps to Excel Sheet 3: "Strengths", "Weaknesses", "Opportunities" columns.';


-- ============================================================================
-- Performance Indexes (recommended)
-- ============================================================================
-- These indexes improve view query performance significantly

-- For niche_service_gaps (review text search)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_review_text_trgm
  ON business_reviews USING gin (review_text gin_trgm_ops);

-- For business_model_opportunities (JSONB social data)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_business_social_data
  ON businesses USING gin ((business_data->'social'));

-- For review_velocity_trends (time-based queries)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reviews_published_at
  ON business_reviews (published_at DESC);

-- For vulnerable_players (recent performance tracking)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_reviews_business_published
  ON business_reviews (business_id, published_at DESC, stars);

COMMENT ON INDEX idx_review_text_trgm IS
'Trigram index for fast text search in niche_service_gaps view';

-- ============================================================================
-- Grant Permissions
-- ============================================================================

GRANT SELECT ON niche_opportunities TO PUBLIC;
GRANT SELECT ON customer_pain_points TO PUBLIC;
GRANT SELECT ON market_leaders TO PUBLIC;
GRANT SELECT ON vulnerable_players TO PUBLIC;
GRANT SELECT ON review_velocity_trends TO PUBLIC;
GRANT SELECT ON niche_service_gaps TO PUBLIC;
GRANT SELECT ON business_model_opportunities TO PUBLIC;
GRANT SELECT ON niche_swot_analysis TO PUBLIC;
