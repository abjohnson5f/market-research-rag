# Knowledge Graph Implementation Checklist

> **Step-by-step validation checklist for Issue #13**

Use this checklist to verify your knowledge graph integration is complete and working correctly.

## Prerequisites

- [ ] Graphiti MCP server installed and configured
- [ ] Neo4j database (Desktop or AuraDB) accessible
- [ ] n8n instance running with MCP support
- [ ] Issues #1-5 completed (database + data collection + RAG chat)

### Verification Commands

```bash
# Test Graphiti MCP server
curl http://localhost:3000/health
# Expected: {"status":"ok","graphiti":"connected","neo4j":"connected"}

# Test Neo4j connection
cypher-shell -u neo4j -p your-password
# Expected: neo4j> prompt appears

# Test n8n access
curl http://localhost:5678
# Expected: n8n web interface loads
```

---

## Phase 1: Data Collection Workflow Updates

### Step 1.1: Add Split Node

- [ ] Open n8n workflow: `01-data-collection.json`
- [ ] Locate "Combine Business Data" node
- [ ] Add new "Split Out" node after it
- [ ] Configure Split node:
  - [ ] Mode: `batch`
  - [ ] Name: "Split: Dual Write Path"
  - [ ] Position: [2700, 480]

### Step 1.2: Add "Prepare Graph Entity" Code Node

- [ ] Add new "Code" node in Split path 2
- [ ] Name: "Prepare Graph Entity"
- [ ] Copy JavaScript code from [KNOWLEDGE-GRAPH-SETUP.md](./KNOWLEDGE-GRAPH-SETUP.md) Part A, Step 2
- [ ] Verify code includes:
  - [ ] `graph_entity` object creation
  - [ ] All required attributes (name, type, attributes)
  - [ ] Pass-through of original JSON fields
- [ ] Position: [2900, 360]

### Step 1.3: Add "Write to Knowledge Graph" HTTP Request Node

- [ ] Add new "HTTP Request" node after "Prepare Graph Entity"
- [ ] Name: "Write to Knowledge Graph"
- [ ] Configure:
  - [ ] Method: POST
  - [ ] URL: `http://localhost:3000/graphiti/entities`
  - [ ] Body: `{{ JSON.stringify($json.graph_entity) }}`
  - [ ] Authentication: MCP Client credential
- [ ] Enable error handling:
  - [ ] Continue On Fail: ✅ Enabled
  - [ ] Retry On Fail: 3 attempts
  - [ ] Wait Between Tries: 1000ms
- [ ] Position: [3100, 360]

### Step 1.4: Add Merge Node

- [ ] Add new "Merge" node
- [ ] Name: "Merge: After Dual Write"
- [ ] Configure:
  - [ ] Mode: Combine
  - [ ] Merge by position: ✅ Enabled
- [ ] Position: [3300, 480]

### Step 1.5: Update Connections

- [ ] Connect: "Combine Business Data" → "Split: Dual Write Path"
- [ ] Connect: "Split: Dual Write Path" (output 1) → "Upsert Business"
- [ ] Connect: "Split: Dual Write Path" (output 2) → "Prepare Graph Entity"
- [ ] Connect: "Prepare Graph Entity" → "Write to Knowledge Graph"
- [ ] Connect: "Upsert Business" → "Merge: After Dual Write" (input 1)
- [ ] Connect: "Write to Knowledge Graph" → "Merge: After Dual Write" (input 2)
- [ ] Connect: "Merge: After Dual Write" → "Prepare Reviews for Insert"

### Step 1.6: Test Data Collection

- [ ] Save workflow
- [ ] Set Apify URL `limit=5` for testing
- [ ] Execute workflow manually
- [ ] Verify execution log:
  - [ ] "Upsert Business" shows 5 successes
  - [ ] "Write to Knowledge Graph" shows 5 successes (or graceful failures)
  - [ ] "Merge: After Dual Write" shows 5 items
  - [ ] No blocking errors

### Step 1.7: Verify Dual-Write Results

**Check Postgres:**
```sql
SELECT 
  business_name,
  business_data->'overview'->>'city' as city,
  created_at
FROM businesses
ORDER BY created_at DESC
LIMIT 5;
```
- [ ] 5 businesses returned with recent timestamps

**Check Neo4j:**
```cypher
MATCH (b:Business)
WHERE b.last_updated >= datetime() - duration({hours: 1})
RETURN b.name, b.city, b.apify_place_id
ORDER BY b.last_updated DESC
LIMIT 5;
```
- [ ] 5 Business entities returned
- [ ] Names match Postgres results
- [ ] `apify_place_id` populated

---

## Phase 2: RAG Chat Interface Updates

### Step 2.1: Add Knowledge Graph Tool Node

- [ ] Open n8n workflow: `02-rag-chat-interface.json`
- [ ] Add new "Tool: HTTP Request" node (LangChain)
- [ ] Name: "Tool: Knowledge Graph Search"
- [ ] Configure tool:
  - [ ] Tool name: `search_knowledge_graph`
  - [ ] Method: POST
  - [ ] URL: `http://localhost:3000/graphiti/search`
  - [ ] Send body: ✅ Enabled
  - [ ] Body type: JSON
  - [ ] Body: `{{ JSON.stringify($parameter.toolArguments) }}`
- [ ] Position: [900, 680]

### Step 2.2: Add Tool Description

- [ ] In tool configuration, add description:
```
Search the knowledge graph for entity resolution, semantic similarity, and relationship discovery.

Use this tool when:
- User asks about entity resolution ("Is ABC same as ABC Inc?")
- User wants to find similar businesses ("Find businesses like XYZ")
- Query involves semantic similarity or fuzzy matching

DO NOT use for:
- Exact filters (city, category, rating) → Use query_businesses instead
- Review text search → Use query_reviews instead

Input: {"query_type": "entity_resolution"|"semantic_search", "entity_name": "...", "limit": 10}
```

### Step 2.3: Connect to AI Agent

- [ ] Click connection point on "Tool: Knowledge Graph Search"
- [ ] Select `ai_tool` output
- [ ] Drag to "Market Research AI Agent" node
- [ ] Verify connection established (line appears)
- [ ] Confirm AI Agent now has 4 tool connections

### Step 2.4: Test Chat Interface

- [ ] Save workflow
- [ ] Open chat interface URL (workflow execution URL)
- [ ] Test query: "What tools do you have available?"
- [ ] Verify AI response mentions 4 tools including `search_knowledge_graph`

---

## Phase 3: AI Agent System Prompt Updates

### Step 3.1: Update System Prompt

- [ ] Open "Market Research AI Agent" node
- [ ] Click "Options" → "System Message"
- [ ] Add hybrid query strategy section from [KNOWLEDGE-GRAPH-SETUP.md](./KNOWLEDGE-GRAPH-SETUP.md) Part C
- [ ] Verify prompt includes:
  - [ ] List of 4 tools (SQL + Graph)
  - [ ] Clear decision rules for tool selection
  - [ ] Hybrid query pattern examples
  - [ ] When to use graph vs SQL

### Step 3.2: Test Tool Selection

**Test Case 1: SQL Query (Should NOT use graph)**
- [ ] Ask: "How many Phoenix HVAC businesses are there?"
- [ ] Verify execution log shows `query_businesses` used
- [ ] Verify `search_knowledge_graph` NOT used

**Test Case 2: Graph Query (Should use graph)**
- [ ] Ask: "Is ABC Cooling the same as ABC Cooling & Heating Inc?"
- [ ] Verify execution log shows `search_knowledge_graph` used
- [ ] Response includes entity resolution reasoning

**Test Case 3: Hybrid Query (Should use both)**
- [ ] Ask: "Find the best Phoenix HVAC businesses and similar competitors"
- [ ] Verify execution log shows BOTH:
  - [ ] `query_businesses` OR `analyze_opportunities` (SQL)
  - [ ] `search_knowledge_graph` (Graph)
- [ ] Response synthesizes both SQL and Graph results

---

## Phase 4: Testing & Validation

### Test 4.1: Entity Extraction

- [ ] Run full test suite from [KNOWLEDGE-GRAPH-TESTING.md](./KNOWLEDGE-GRAPH-TESTING.md) Test 2
- [ ] Verify all business attributes mapped correctly
- [ ] Check for null values in required fields
- [ ] Confirm data types correct (rating as float, etc.)

### Test 4.2: Entity Resolution

- [ ] Create test duplicate in Neo4j (see [KNOWLEDGE-GRAPH-TESTING.md](./KNOWLEDGE-GRAPH-TESTING.md) Test 3)
- [ ] Ask: "Is [Business A] the same as [Business B]?"
- [ ] Verify AI:
  - [ ] Uses `search_knowledge_graph` tool
  - [ ] Returns similarity score or reasoning
  - [ ] Identifies potential duplicate

### Test 4.3: Semantic Search

- [ ] Ask: "Find businesses similar to [specific business name]"
- [ ] Verify response includes:
  - [ ] At least 3 similar businesses
  - [ ] Similarity scores or reasoning
  - [ ] Relevant businesses (same/related category)

### Test 4.4: Hybrid Query

- [ ] Ask: "Find top [city] [category] businesses and their competitors"
- [ ] Verify response shows:
  - [ ] SQL results first (filtered, ranked)
  - [ ] Graph results second (similar entities)
  - [ ] Synthesized strategic insight

### Test 4.5: Performance

- [ ] Measure SQL-only query time (should be <500ms)
- [ ] Measure Graph-only query time (should be <1500ms)
- [ ] Measure Hybrid query time (should be <2000ms)
- [ ] Verify no timeout errors

### Test 4.6: Error Handling

**Test: Graph Server Down**
- [ ] Stop Graphiti MCP server
- [ ] Run data collection workflow
- [ ] Verify:
  - [ ] Workflow completes successfully
  - [ ] Postgres write succeeds
  - [ ] Graph write logged as error (not blocking)
  - [ ] Reviews inserted correctly

**Test: Graph Query with No Results**
- [ ] Ask: "Find businesses similar to NonexistentBusiness12345"
- [ ] Verify:
  - [ ] No error thrown
  - [ ] Clear message about no results
  - [ ] Suggestions for alternative queries

---

## Phase 5: Production Readiness

### Step 5.1: Full Dataset Processing

- [ ] Remove `limit=5` from Apify URL
- [ ] Run data collection workflow on full dataset
- [ ] Monitor execution:
  - [ ] Check execution time (baseline for future)
  - [ ] Verify no memory issues
  - [ ] Confirm all businesses written to both systems

### Step 5.2: Verify Data Consistency

**Count Check:**
```sql
-- Postgres count
SELECT COUNT(*) FROM businesses;
```
```cypher
// Neo4j count
MATCH (b:Business) RETURN count(b);
```
- [ ] Counts match (or explain discrepancy)

**Sample Check:**
- [ ] Pick 10 random businesses
- [ ] Verify attributes match in both systems
- [ ] Check for data quality issues

### Step 5.3: Performance Optimization

**Add Neo4j Indexes:**
```cypher
CREATE INDEX ON :Business(apify_place_id);
CREATE INDEX ON :Business(name);
CREATE INDEX ON :Business(city);
CREATE INDEX ON :Business(category);
```
- [ ] Indexes created
- [ ] Query performance improved (measure before/after)

**Add Postgres Indexes (if not already present):**
```sql
CREATE INDEX idx_businesses_city ON businesses USING GIN ((business_data->'overview'->>'city'));
CREATE INDEX idx_businesses_category ON businesses USING GIN ((business_data->'overview'->>'category'));
```
- [ ] Indexes created

### Step 5.4: Monitoring Setup

- [ ] Document baseline metrics:
  - [ ] Average query time (SQL)
  - [ ] Average query time (Graph)
  - [ ] Dual-write overhead
  - [ ] Entity count in both systems

- [ ] Set up alerts (optional):
  - [ ] Graph server down
  - [ ] Sync lag >1 hour
  - [ ] Query time >3 seconds

---

## Phase 6: Documentation

### Step 6.1: Update README

- [ ] Add Knowledge Graph section to main README.md
- [ ] Link to setup guide
- [ ] Mention 4 available tools
- [ ] Include example queries

### Step 6.2: Create Operational Runbook

- [ ] Document how to restart Graphiti MCP server
- [ ] Document how to re-sync Postgres → Neo4j
- [ ] Document how to verify data consistency
- [ ] Document troubleshooting steps

### Step 6.3: Team Training (if applicable)

- [ ] Explain when to use graph vs SQL
- [ ] Show example queries
- [ ] Demo entity resolution capabilities
- [ ] Review error handling

---

## Final Verification

### Acceptance Criteria

- [ ] Data collection workflow includes dual-write (Postgres + Neo4j)
- [ ] RAG chat interface has 4 tools (3 SQL + 1 Graph)
- [ ] AI Agent system prompt explains tool selection
- [ ] Entity extraction working (all attributes mapped)
- [ ] Entity resolution working (detects duplicates)
- [ ] Semantic search working (finds similar businesses)
- [ ] Hybrid queries working (combines SQL + Graph)
- [ ] Performance acceptable (<2s for hybrid queries)
- [ ] Error handling graceful (Postgres succeeds even if graph fails)
- [ ] Documentation complete (setup, testing, architecture)

### Sign-Off

- [ ] All tests passing
- [ ] No critical bugs
- [ ] Performance acceptable
- [ ] Documentation complete
- [ ] Ready for production use

**Completed by:** _________________  
**Date:** _________________  
**Notes:** _________________

---

## Troubleshooting Common Issues

### Issue: Split node not sending to both paths

**Check:**
- [ ] Split mode is "batch" not "single"
- [ ] Both output connections exist
- [ ] Merge node has 2 input connections

**Fix:** Reconnect paths, ensure batch mode enabled

---

### Issue: Graph write always failing

**Check:**
- [ ] Graphiti MCP server running: `curl http://localhost:3000/health`
- [ ] Neo4j accessible: `cypher-shell`
- [ ] MCP credential configured in n8n
- [ ] HTTP Request URL correct (including port)

**Fix:** Restart services, verify credentials

---

### Issue: AI Agent not using graph tool

**Check:**
- [ ] Tool connected to AI Agent via `ai_tool` input
- [ ] Tool description clear about when to use
- [ ] System prompt includes hybrid query strategy
- [ ] Query phrasing matches tool description

**Fix:** Update system prompt with more explicit examples

---

### Issue: Data mismatch between Postgres and Neo4j

**Check:**
- [ ] Dual-write completed successfully (check logs)
- [ ] No partial failures (Continue On Fail may hide errors)
- [ ] Graph entity mapping includes all required fields

**Fix:** Re-run data collection, verify both writes succeed

---

### Issue: Performance degradation

**Check:**
- [ ] Neo4j indexes created
- [ ] Graph query not called for SQL-appropriate queries
- [ ] No N+1 query pattern (calling graph in loop)

**Fix:** Add indexes, update system prompt to prefer SQL for filters

---

## Next Steps After Completion

1. **Monitor Usage:**
   - Track which tool is used most often
   - Identify common query patterns
   - Optimize based on actual usage

2. **Expand Graph Schema:**
   - Add City and Category entity types
   - Create LOCATED_IN and BELONGS_TO relationships
   - Enable graph traversal queries

3. **Advanced Features:**
   - Vector embeddings for semantic review search
   - Graph algorithms (PageRank, community detection)
   - Real-time sync with change data capture

4. **Integration:**
   - Connect permit databases
   - Ingest PDF documents
   - Link social media data

---

**Related Documentation:**
- [KNOWLEDGE-GRAPH-SETUP.md](./KNOWLEDGE-GRAPH-SETUP.md) - Setup instructions
- [KNOWLEDGE-GRAPH-TESTING.md](./KNOWLEDGE-GRAPH-TESTING.md) - Testing procedures
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture diagrams
