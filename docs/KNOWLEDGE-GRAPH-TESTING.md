# Knowledge Graph Testing Guide

> **Complete testing procedures for knowledge graph integration**

This guide provides step-by-step testing instructions to verify the knowledge graph layer is working correctly with your market-research-rag system.

## Prerequisites Checklist

Before testing, verify:

- [ ] Graphiti MCP server running (`curl http://localhost:3000/health`)
- [ ] Neo4j database accessible (`cypher-shell` connects successfully)
- [ ] n8n MCP credentials configured
- [ ] Data Collection workflow updated with dual-write
- [ ] RAG Chat Interface updated with graph tool
- [ ] AI Agent system prompt updated

## Test Suite

### Test 1: Data Collection Dual-Write

**Goal:** Verify business data is written to both Postgres AND Neo4j

**Steps:**
1. Open n8n workflow: `01-data-collection.json`
2. Ensure Apify URL has `limit=5` for quick test
3. Execute workflow
4. Monitor execution:
   - Check "Upsert Business" node succeeds
   - Check "Write to Knowledge Graph" node succeeds
   - Check "Merge: After Dual Write" node receives data from both paths

**Verification - Postgres:**
```sql
-- Check businesses table
SELECT 
  business_name,
  business_data->'overview'->>'city' as city,
  business_data->'rating'->>'totalScore' as rating,
  created_at
FROM businesses
ORDER BY created_at DESC
LIMIT 5;
```

**Expected:** 5 businesses with recent timestamps

**Verification - Neo4j:**
```cypher
// Check Business entities
MATCH (b:Business)
WHERE b.last_updated >= datetime() - duration({hours: 1})
RETURN 
  b.name, 
  b.city, 
  b.rating, 
  b.apify_place_id
ORDER BY b.last_updated DESC
LIMIT 5;
```

**Expected:** 5 Business nodes with matching names from Postgres

**Success Criteria:**
- ✅ Both Postgres and Neo4j contain same 5 businesses
- ✅ Business names match exactly
- ✅ Core attributes populated (city, rating, category)
- ✅ No errors in workflow execution log

---

### Test 2: Entity Extraction Accuracy

**Goal:** Verify data mapping from Postgres JSONB to Graph entities

**Test Case:**
Pick one business from Test 1 and verify all attributes transferred correctly.

**Postgres Query:**
```sql
SELECT 
  business_name,
  business_data->'overview'->>'category' as category,
  business_data->'overview'->>'city' as city,
  business_data->'overview'->>'state' as state,
  business_data->'contact'->>'phone' as phone,
  business_data->'contact'->>'website' as website,
  business_data->'rating'->>'totalScore' as rating,
  business_data->'rating'->>'reviewsCount' as review_count
FROM businesses
WHERE business_name = 'ABC Cooling'  -- Replace with actual name
LIMIT 1;
```

**Neo4j Query:**
```cypher
MATCH (b:Business {name: 'ABC Cooling'})  // Replace with actual name
RETURN 
  b.name,
  b.category,
  b.city,
  b.state,
  b.phone,
  b.website,
  b.rating,
  b.review_count;
```

**Success Criteria:**
- ✅ All fields match between Postgres and Neo4j
- ✅ No null values for required fields (name, apify_place_id)
- ✅ Data types correct (rating as float, review_count as integer)

---

### Test 3: Entity Resolution Queries

**Goal:** Test knowledge graph's ability to identify duplicate/similar entities

**Test Case 1: Exact Match**

**Chat Query:**
```
Is there a business called "ABC Cooling" in the database?
```

**Expected AI Response:**
```
Yes, I found ABC Cooling in the knowledge graph:
- Name: ABC Cooling
- Location: Phoenix, AZ
- Category: HVAC Service
- Rating: 4.5 stars
- Reviews: 87
```

**Verification:**
Check execution log shows `search_knowledge_graph` tool was called

---

**Test Case 2: Entity Resolution (Similar Names)**

**Setup:** Manually create a variant in Neo4j for testing:
```cypher
CREATE (b:Business {
  name: "ABC Cooling & Heating Inc",
  apify_place_id: "test-duplicate-1",
  city: "Phoenix",
  state: "AZ",
  category: "HVAC Service",
  rating: 4.7,
  review_count: 95
});
```

**Chat Query:**
```
Is "ABC Cooling" the same as "ABC Cooling & Heating Inc"?
```

**Expected AI Response:**
```
Based on knowledge graph entity resolution, these appear to be related or potentially the same business:

1. ABC Cooling (rating: 4.5, 87 reviews)
2. ABC Cooling & Heating Inc (rating: 4.7, 95 reviews)

Similarity factors:
- Name similarity: 85%
- Same city: Phoenix, AZ
- Same category: HVAC Service
- Similar rating range

Recommendation: These may be the same business with different name variations.
```

**Success Criteria:**
- ✅ AI uses `search_knowledge_graph` tool
- ✅ Response includes similarity score/reasoning
- ✅ Both entities mentioned in response

---

### Test 4: Semantic Search

**Goal:** Find businesses similar to a specific business

**Test Case: Similar Business Search**

**Chat Query:**
```
Find businesses similar to "XYZ Plumbing Services"
```

**Expected AI Response:**
```
Based on knowledge graph semantic search, here are businesses similar to XYZ Plumbing Services:

Similar Businesses (similarity > 0.8):
1. ABC Plumbing Co. (similarity: 0.87)
   - Phoenix, AZ
   - Rating: 4.6 stars
   
2. DEF Drain & Pipe (similarity: 0.82)
   - Scottsdale, AZ
   - Rating: 4.4 stars

3. GHI Plumbing Solutions (similarity: 0.81)
   - Tempe, AZ
   - Rating: 4.3 stars

Common characteristics:
- All in plumbing/drain services category
- Similar geographic area (Phoenix metro)
- Comparable rating range (4.3-4.6)
```

**Success Criteria:**
- ✅ AI uses `search_knowledge_graph` tool
- ✅ Results include similarity scores
- ✅ Results are relevant (same/related category)
- ✅ At least 3 similar entities returned

---

### Test 5: Hybrid Query (SQL + Graph)

**Goal:** Verify AI can combine SQL filtering with graph semantic search

**Test Case: Market Leaders + Competitors**

**Chat Query:**
```
Find the top 3 Phoenix HVAC businesses by rating, then find businesses similar to each
```

**Expected AI Response:**
```
Here's a comprehensive analysis combining SQL and knowledge graph data:

Top Phoenix HVAC Businesses (SQL query):
1. XYZ Cooling - 4.8 stars (120 reviews)
2. ABC Heating - 4.7 stars (95 reviews)
3. DEF Climate - 4.6 stars (88 reviews)

Similar Competitors (Knowledge Graph):

For XYZ Cooling (similarity > 0.75):
- GHI Air Conditioning (0.85 similarity)
- JKL HVAC Services (0.78 similarity)

For ABC Heating (similarity > 0.75):
- MNO Heating & Air (0.82 similarity)
- PQR Climate Control (0.76 similarity)

For DEF Climate (similarity > 0.75):
- STU Air Experts (0.79 similarity)

Strategic Insights:
- Total competitive set: 9 businesses
- Average rating across set: 4.5 stars
- Market is competitive with established leaders
```

**Success Criteria:**
- ✅ AI uses BOTH `query_businesses` AND `search_knowledge_graph`
- ✅ SQL results shown first (exact filters)
- ✅ Graph results shown second (semantic similarity)
- ✅ Results synthesized into strategic insight

---

### Test 6: Tool Selection Logic

**Goal:** Verify AI chooses correct tool for each query type

**Test Cases:**

| Query | Expected Tool | Reason |
|-------|--------------|--------|
| "How many Phoenix HVAC businesses?" | `query_businesses` (SQL) | Exact filter + count aggregation |
| "Show me reviews mentioning 'price'" | `query_reviews` (SQL) | Review text search |
| "Best market opportunities?" | `analyze_opportunities` (SQL) | Predefined SQL view |
| "Is ABC same as ABC Inc?" | `search_knowledge_graph` (Graph) | Entity resolution |
| "Find businesses like XYZ" | `search_knowledge_graph` (Graph) | Semantic similarity |

**Execution:**
Run each query in chat interface and verify correct tool used (check execution logs)

**Success Criteria:**
- ✅ 5/5 queries use correct tool
- ✅ No tool fallback errors
- ✅ Response quality appropriate for query type

---

### Test 7: Performance Validation

**Goal:** Ensure knowledge graph doesn't degrade system performance

**Test Metrics:**

**Before (SQL-only):**
```
User: "Find Phoenix HVAC businesses"
Expected time: <500ms
```

**After (with graph available):**
```
User: "Find Phoenix HVAC businesses"
Expected time: <500ms (should NOT use graph for this query)

User: "Find businesses similar to XYZ"
Expected time: <1500ms (graph query acceptable)
```

**Benchmark Test:**
1. Run 10 SQL-only queries (exact filters, aggregations)
2. Measure average response time
3. Compare to baseline (<500ms acceptable)

**Success Criteria:**
- ✅ SQL queries unchanged in performance
- ✅ Graph queries complete in <1500ms
- ✅ No timeout errors
- ✅ System remains responsive

---

### Test 8: Error Handling

**Goal:** Verify graceful failure when graph unavailable

**Test Case: Graph Server Down**

**Setup:**
1. Stop Graphiti MCP server: `kill $(lsof -t -i:3000)`
2. Run data collection workflow

**Expected Behavior:**
- ✅ Workflow continues (Continue On Fail enabled)
- ✅ Postgres write succeeds
- ✅ Graph write logged as error but doesn't block
- ✅ Reviews still inserted

**Test Case: Graph Query with No Results**

**Chat Query:**
```
Find businesses similar to "NonexistentBusiness12345"
```

**Expected AI Response:**
```
I searched the knowledge graph for businesses similar to "NonexistentBusiness12345" but found no matching entities.

This could mean:
- The business name doesn't exist in our database
- The name may have a typo
- Try searching with a different query or check available businesses first
```

**Success Criteria:**
- ✅ No error thrown
- ✅ Clear explanation of no results
- ✅ Suggestions for alternative queries

---

## Automated Test Script

**Optional:** Create bash script for regression testing

```bash
#!/bin/bash
# test-knowledge-graph.sh

echo "Testing Knowledge Graph Integration..."

# Test 1: MCP Server Health
echo "1. Checking MCP server..."
curl -f http://localhost:3000/health || echo "FAIL: MCP server not responding"

# Test 2: Neo4j Connection
echo "2. Checking Neo4j..."
cypher-shell -u neo4j -p your-password "MATCH (n) RETURN count(n) LIMIT 1;" || echo "FAIL: Neo4j not accessible"

# Test 3: Entity Count
echo "3. Checking entity count..."
ENTITY_COUNT=$(cypher-shell -u neo4j -p your-password --format plain "MATCH (b:Business) RETURN count(b);" | grep -oE '[0-9]+')
echo "Found $ENTITY_COUNT Business entities"
[[ $ENTITY_COUNT -gt 0 ]] || echo "FAIL: No entities in graph"

# Test 4: Postgres-Neo4j Sync
echo "4. Checking Postgres-Neo4j sync..."
PG_COUNT=$(psql -U postgres -d market_research -t -c "SELECT COUNT(*) FROM businesses;")
echo "Postgres: $PG_COUNT businesses, Neo4j: $ENTITY_COUNT businesses"
[[ $PG_COUNT -eq $ENTITY_COUNT ]] || echo "WARN: Count mismatch between Postgres and Neo4j"

echo "Tests complete!"
```

**Run with:** `bash test-knowledge-graph.sh`

---

## Test Report Template

After completing all tests, document results:

```markdown
# Knowledge Graph Integration Test Report

**Date:** 2025-10-13
**Tester:** Alex Johnson
**Environment:** Local n8n + Supabase + Neo4j Desktop

## Test Results Summary

| Test | Status | Notes |
|------|--------|-------|
| Dual-Write | ✅ PASS | 5/5 businesses in both systems |
| Entity Extraction | ✅ PASS | All attributes mapped correctly |
| Entity Resolution | ✅ PASS | Correctly identified similar names |
| Semantic Search | ✅ PASS | Returned 3 similar businesses |
| Hybrid Query | ✅ PASS | Used both SQL and Graph |
| Tool Selection | ✅ PASS | 5/5 correct tool choices |
| Performance | ✅ PASS | SQL <500ms, Graph <1200ms |
| Error Handling | ✅ PASS | Graceful degradation when graph down |

## Issues Found
- None

## Performance Metrics
- Average SQL query time: 287ms
- Average Graph query time: 1089ms
- Dual-write overhead: +230ms per business

## Recommendations
- ✅ Ready for production
- Consider adding graph indexes for faster similarity search
- Monitor Neo4j memory usage as dataset grows
```

---

## Troubleshooting Common Test Failures

### Test 1 Fails: No data in Neo4j

**Check:**
1. MCP server logs for errors
2. "Write to Knowledge Graph" node has correct endpoint
3. Neo4j bolt connection string correct
4. Firewall not blocking port 7687

**Fix:**
```bash
# Restart Neo4j
neo4j restart

# Check logs
tail -f /path/to/neo4j/logs/neo4j.log
```

### Test 3 Fails: Entity resolution not working

**Check:**
1. Similarity threshold too high (lower to 0.7 for testing)
2. Entity names don't match exactly
3. Graph embedding model configured correctly

**Fix:**
Update Graphiti config to use more lenient matching

### Test 5 Fails: AI doesn't use both tools

**Check:**
1. System prompt includes hybrid query strategy
2. Tool descriptions clear about when to use each
3. Query phrasing explicit enough

**Fix:**
Update system prompt with more explicit examples

---

## Next Steps After Testing

1. **Production Deployment:**
   - Remove `limit=5` from Apify URL
   - Process full dataset
   - Monitor performance under load

2. **Advanced Features:**
   - Add relationship edges (COMPETES_WITH, LOCATED_IN)
   - Enable graph algorithms (PageRank, community detection)
   - Integrate with pgvector for hybrid vector+graph search

3. **Monitoring:**
   - Set up Grafana dashboards for graph metrics
   - Track entity resolution accuracy
   - Monitor query performance over time

---

**Related Documentation:**
- [KNOWLEDGE-GRAPH-SETUP.md](./KNOWLEDGE-GRAPH-SETUP.md) - Setup instructions
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture
- [IMPLEMENTATION-CHECKLIST-13.md](./IMPLEMENTATION-CHECKLIST-13.md) - Implementation steps
