# Knowledge Graph Integration Guide

## Overview

This guide explains how the Graphiti + Neo4j knowledge graph is integrated into the market-research-rag system for entity resolution and semantic search.

## Architecture

### Dual-Write Pipeline

When Data Collection workflow runs:
1. Fetch business data from Apify API
2. Transform data (ETL Code nodes)
3. **SPLIT** execution into two parallel paths:
   - Path A: Write to Postgres (UPSERT for idempotency)
   - Path B: Prepare entity → Write to Knowledge Graph (via MCP)
4. **MERGE** paths before continuing to reviews

### AI Agent Tools

RAG Chat Interface now has 4 tools:
- `query_businesses` - SQL exact filters
- `query_reviews` - SQL review search
- `analyze_opportunities` - SQL strategic views (Issue #12)
- `search_knowledge_graph` - Graph entity resolution ← NEW

## Use Cases

### Entity Resolution

**Question:** "Is 'ABC Cooling' the same business as 'ABC Cooling & Heating Inc'?"

**AI Agent Process:**
1. Detects "same as" pattern → Chooses `search_knowledge_graph` tool
2. Queries Graphiti: `{query: "ABC Cooling vs ABC Cooling & Heating Inc"}`
3. Graphiti returns semantic similarity score + entity match confidence
4. AI responds: "Based on entity resolution, these appear to be the same business (confidence: 94%). Both have matching address and phone number."

### Semantic Similarity

**Question:** "Find businesses similar to Smith HVAC Services"

**AI Agent Process:**
1. Detects "similar to" pattern → Chooses `search_knowledge_graph` tool
2. Queries Graphiti: `{query: "businesses similar to Smith HVAC Services", limit: 10}`
3. Graphiti returns ranked list based on:
   - Category similarity
   - Location proximity
   - Rating patterns
   - Service offerings
4. AI responds with ranked list of similar businesses

### Hybrid Analysis

**Question:** "Best Phoenix HVAC contractors and their competitors"

**AI Agent Process:**
1. Step 1 (SQL): Filter Phoenix + HVAC + rating>4.5
2. Step 2 (SQL): Query `market_leaders` view for INC scores
3. Step 3 (Graph): For each leader, find similar businesses
4. Step 4: Synthesize results into comprehensive answer

## Prerequisites

### 1. Graphiti MCP Server

Must be running and accessible:
```bash
# Test health
curl http://localhost:3000/health

# Expected response
{"status": "healthy"}
```

### 2. Neo4j Database

Connected to Graphiti:
```bash
# Test Neo4j
cypher-shell -u neo4j -p your-password
MATCH (n) RETURN count(n);
```

### 3. n8n Environment Variables

Set in n8n settings:
- `GRAPHITI_URL` - MCP server URL (default: http://localhost:3000)

## Testing

### Test 1: Verify Dual-Write

Run Data Collection workflow with limit=5:
1. Check Postgres: `SELECT count(*) FROM businesses;` → 5 rows
2. Check Neo4j: `MATCH (n:Business) RETURN count(n);` → 5 nodes
3. Both should have matching counts

### Test 2: Test Entity Resolution

Ask RAG Chat: "Search the knowledge graph for all business entities"

Expected: AI uses `search_knowledge_graph` tool and returns list of businesses

### Test 3: Test Semantic Search

Ask RAG Chat: "Find businesses similar to [business name from your data]"

Expected: AI returns ranked list of similar businesses with similarity scores

### Test 4: Test Hybrid Query

Ask RAG Chat: "What are the best Phoenix HVAC businesses and who are their competitors?"

Expected:
1. AI uses SQL to filter Phoenix HVAC
2. AI uses SQL views to rank by INC score
3. AI uses Graph to find similar businesses
4. AI synthesizes comprehensive answer

## Troubleshooting

### "Knowledge graph write fails"

**Symptoms:** Workflow continues but no entities in Neo4j

**Solution:**
1. Check MCP server health: `curl http://localhost:3000/health`
2. Verify "Add to Knowledge Graph" node has "Continue On Fail" enabled
3. Check node execution output for error messages
4. Test MCP directly:
   ```bash
   curl -X POST http://localhost:3000/graphiti/add_memory \
     -H "Content-Type: application/json" \
     -d '{"name": "Test", "episode_body": "Test business description"}'
   ```

### "AI never uses knowledge graph tool"

**Symptoms:** AI always chooses SQL tools

**Solution:**
1. Update system prompt to include more explicit graph use cases
2. Ask explicit graph question: "Use the knowledge graph to find..."
3. Verify tool is connected to AI Agent node (check connections)
4. Review AI Agent execution log to see tool selection reasoning

### "Empty graph results"

**Symptoms:** Tool executes but returns no entities

**Solution:**
1. Verify entities exist in Neo4j: `MATCH (n:Business) RETURN count(n);`
2. Check entity descriptions are human-readable (not raw JSON)
3. Verify MCP server is processing entities (check logs)
4. Try simpler query: "Search for any business"

## Performance

### Expected Latencies

- SQL queries: <100ms (indexed)
- Graph queries: 200-500ms (semantic processing)
- Hybrid queries: 500-1000ms (multiple tool calls)

### Optimization Tips

1. **Use SQL for filters first**: Narrow dataset before graph search
2. **Limit graph results**: Default 10, max 50
3. **Batch writes**: Accumulate 10-20 entities before graph write (future optimization)

## Next Steps

After completing this integration:

1. **Test with real data**: Run Data Collection on 50-100 businesses
2. **Try complex queries**: Test hybrid SQL+Graph patterns
3. **Monitor performance**: Check graph query latencies
4. **Future enhancements**:
   - Add PDF documents → Auto-link to businesses
   - Add permit data → Connect via entity resolution
   - Add temporal relationships → Track business changes over time

## Related Documentation

- [Data Collection Workflow](./WORKFLOW-DATA-COLLECTION.md)
- [RAG Chat Interface](./WORKFLOW-RAG-CHAT.md)
- [Strategic Views](./STRATEGIC-VIEWS-USAGE.md) (Issue #12)
- [Knowledge Graph Setup](./KNOWLEDGE-GRAPH-SETUP.md) - Manual setup instructions
- [Knowledge Graph Testing](./KNOWLEDGE-GRAPH-TESTING.md) - Test suite
- [Graphiti MCP Documentation](https://github.com/getzep/graphiti)