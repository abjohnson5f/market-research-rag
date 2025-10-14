# Knowledge Graph Integration - Implementation Instructions

## Overview

This directory contains the resources needed to integrate Graphiti knowledge graph capabilities into the market-research-rag workflows. The integration enables entity resolution, semantic search, and hybrid SQL+Graph queries.

## Implementation Approach

**IMPORTANT:** n8n workflows are complex JSON structures best modified through the n8n UI, not programmatically. This implementation uses a **patch-based approach**:

1. Patch files (`workflows/patches/`) describe the nodes to add
2. Building blocks (`workflows/building-blocks/`) provide reusable node templates
3. Implementation checklist (`docs/IMPLEMENTATION-CHECKLIST-13.md`) provides step-by-step UI instructions

## Files in This Integration

### Patch Files (`workflows/patches/`)

**`13-knowledge-graph-data-collection.json`**
- Describes nodes to add to Data Collection workflow
- Implements dual-write: Postgres + Neo4j
- Includes: Split node, Prepare Graph Entity, Write to KG, Merge node

**`13-knowledge-graph-rag-chat.json`**
- Describes nodes to add to RAG Chat Interface
- Adds 4th tool: `search_knowledge_graph`
- Includes: System prompt updates, tool connection instructions

### Building Blocks (`workflows/building-blocks/`)

**`mcp-add-to-graph.json`**
- HTTP Request node template for writing to Graphiti MCP
- Inputs: `entity_name`, `entity_description`
- Features: Auto-retry (3x), Continue On Fail, environment variable support

**`graphiti-add-business.json`**
- MCP Client node (alternative to HTTP Request)
- Uses n8n MCP integration for Graphiti
- Auto-formats business data for knowledge graph

### Tools (`workflows/tools/`)

**`search-knowledge-graph-tool.json`**
- LangChain Tool for AI Agent
- Enables knowledge graph queries
- MCP-based for direct Graphiti communication

### Documentation (`docs/`)

**`KNOWLEDGE-GRAPH-SETUP.md`**
- Complete setup guide with prerequisites
- Step-by-step node configuration
- Code snippets for each node

**`KNOWLEDGE-GRAPH-INTEGRATION.md`**
- Architecture overview
- Use case examples
- Troubleshooting guide

**`KNOWLEDGE-GRAPH-TESTING.md`**
- 8-test validation suite
- Performance benchmarks
- Test result templates

**`IMPLEMENTATION-CHECKLIST-13.md`**
- Comprehensive implementation checklist
- Phase-by-phase validation
- Acceptance criteria

## Implementation Steps

### Quick Start (30-60 minutes)

1. **Prerequisites** (10 min)
   ```bash
   # Verify Graphiti MCP server
   curl http://localhost:3000/health

   # Verify Neo4j connection
   cypher-shell -u neo4j -p your-password

   # Set n8n environment variable
   # In n8n Settings → Environment:
   # GRAPHITI_URL=http://localhost:3000
   ```

2. **Data Collection Workflow** (15 min)
   - Open `workflows/01-data-collection.json` in n8n
   - Follow `workflows/patches/13-knowledge-graph-data-collection.json`
   - Add 4 nodes: Split → Prepare Entity → Write KG → Merge
   - Use code from `KNOWLEDGE-GRAPH-SETUP.md` Part A
   - Test with limit=5

3. **RAG Chat Interface** (10 min)
   - Open `workflows/02-rag-chat-interface.json` in n8n
   - Import `workflows/tools/search-knowledge-graph-tool.json`
   - Connect to AI Agent as 4th tool
   - Update system prompt (see patch file)

4. **Testing** (15 min)
   - Run 8-test suite from `KNOWLEDGE-GRAPH-TESTING.md`
   - Verify dual-write (Postgres + Neo4j)
   - Test entity resolution queries
   - Test hybrid SQL+Graph queries

### Detailed Implementation

Follow the complete checklist in `docs/IMPLEMENTATION-CHECKLIST-13.md`:

**Phase 1:** Data Collection Workflow (Steps 1.1-1.7)
**Phase 2:** RAG Chat Interface (Steps 2.1-2.4)
**Phase 3:** System Prompt Updates (Steps 3.1-3.2)
**Phase 4:** Testing & Validation (Tests 4.1-4.6)
**Phase 5:** Production Readiness (Steps 5.1-5.4)
**Phase 6:** Documentation (Steps 6.1-6.3)

## Architecture Changes

### Before (SQL-Only)
```
Apify API → Postgres → SQL Views → AI Agent (3 tools)
```

### After (Hybrid SQL + Graph)
```
Apify API → Dual-Write Pipeline
  ├─ Postgres → SQL Views → Quantitative analysis
  └─ Graphiti → Neo4j → Semantic reasoning

AI Agent (4 tools):
  ├─ query_businesses (SQL)
  ├─ query_reviews (SQL)
  ├─ analyze_opportunities (SQL views)
  └─ search_knowledge_graph (Graph) ← NEW
```

## Data Flow

### Data Collection (Dual-Write)

```
[Combine Business Data]
        ↓
[Split: Dual Write Path]
        ↓
    ┌───┴───┐
    ↓       ↓
[Upsert   [Prepare Graph Entity]
Business]      ↓
    ↓     [Write to Knowledge Graph]
    └───┬───┘
        ↓
[Merge: After Dual Write]
        ↓
[Prepare Reviews for Insert]
```

### RAG Chat (Tool Selection)

```
User Question
     ↓
AI Agent analyzes intent
     ↓
  ┌──┴──┐
  ↓     ↓
SQL?   Graph?
  ↓     ↓
Use exact  Use semantic
filters    similarity
```

## Key Design Decisions

### Why Dual-Write (Postgres + Graph)?

**Postgres (SQL):**
- ✅ Fast exact filters (city, category, rating)
- ✅ Aggregations (COUNT, AVG, GROUP BY)
- ✅ Strategic views (Issue #12 - opportunity scores)
- ❌ Poor at fuzzy matching
- ❌ No entity resolution

**Neo4j (Graph via Graphiti):**
- ✅ Entity resolution ("ABC Cooling" = "ABC Cooling & Heating Inc?")
- ✅ Semantic similarity (find similar businesses)
- ✅ Relationship discovery (complaint patterns, supply chains)
- ✅ Cross-source linking (PDFs, permits, Apify)
- ❌ Slower for exact filters
- ❌ Requires careful query design

**Both Together:**
- SQL narrows dataset (fast filters)
- SQL provides quantitative metrics (opportunity scores)
- Graph finds relationships (similar entities)
- AI synthesizes comprehensive insights

### Why HTTP Request Instead of Native MCP Node?

Two building blocks provided:

1. **`mcp-add-to-graph.json`** (HTTP Request) ← **Recommended**
   - More portable across n8n versions
   - Easier to debug (HTTP logs)
   - Works without MCP credential configuration
   - Environment variable support

2. **`graphiti-add-business.json`** (MCP Client)
   - Uses n8n's native MCP integration
   - Cleaner abstraction
   - Requires MCP credential setup
   - Better for complex MCP operations

Choose HTTP Request for simplicity, MCP Client for integration.

### Why Continue On Fail?

The "Write to Knowledge Graph" node has `continueOnFail: true` because:

1. **Postgres is source of truth** - SQL writes must succeed
2. **Graph is enhancement** - Failures shouldn't block workflow
3. **Resilience** - If Graphiti MCP is down, data collection continues
4. **Graceful degradation** - RAG chat works with SQL-only until graph available

Trade-off: Silent failures unless execution logs monitored.

## Performance Characteristics

### Latency Targets

| Query Type | Target Latency | Typical Latency |
|-----------|----------------|-----------------|
| SQL exact filter | <100ms | 20-50ms |
| SQL view aggregation | <200ms | 80-150ms |
| Graph entity search | <500ms | 200-400ms |
| Hybrid SQL+Graph | <1000ms | 500-800ms |

### Optimization Strategies

1. **SQL First**: Filter with SQL before graph search
2. **Limit Graph Results**: Default 10, max 50
3. **Index Heavily**: Neo4j indexes on name, category, city
4. **Batch Writes**: Future enhancement for bulk inserts
5. **Cache Common Queries**: Future enhancement for repeated searches

## Troubleshooting Quick Reference

| Symptom | Check | Fix |
|---------|-------|-----|
| No entities in Neo4j | MCP server health | Restart Graphiti service |
| AI never uses graph tool | Tool connections | Verify 4th ai_tool connection |
| Graph query empty results | Entity extraction | Check entity_description format |
| Workflow fails on graph write | Continue On Fail | Enable in node settings |
| Slow hybrid queries | Query order | SQL filter first, then graph |

Full troubleshooting in `KNOWLEDGE-GRAPH-INTEGRATION.md`.

## Validation Checklist

Before marking complete:

- [ ] Graphiti MCP server healthy
- [ ] Neo4j connected and accessible
- [ ] n8n GRAPHITI_URL environment variable set
- [ ] Data Collection workflow has dual-write nodes
- [ ] RAG Chat Interface has 4th tool connected
- [ ] System prompt includes hybrid query strategy
- [ ] Test 1: Dual-write verification (Postgres + Neo4j)
- [ ] Test 2: Entity resolution query works
- [ ] Test 3: Semantic similarity query works
- [ ] Test 4: Hybrid query uses both SQL and Graph
- [ ] Documentation reviewed and understood
- [ ] Performance acceptable (<2s for hybrid queries)

## Next Steps After Implementation

1. **Monitor Usage**: Track which tool used most often
2. **Expand Schema**: Add City, Category entity types
3. **Advanced Features**: Vector embeddings, graph algorithms
4. **Integration**: Connect permit data, PDFs, social media

## Support Resources

- **Setup Issues**: See `KNOWLEDGE-GRAPH-SETUP.md`
- **Testing Problems**: See `KNOWLEDGE-GRAPH-TESTING.md`
- **Architecture Questions**: See `KNOWLEDGE-GRAPH-INTEGRATION.md`
- **Implementation Help**: See `IMPLEMENTATION-CHECKLIST-13.md`
- **Graphiti Docs**: https://github.com/getzep/graphiti
- **Neo4j Docs**: https://neo4j.com/docs/
- **n8n MCP Docs**: https://docs.n8n.io/integrations/mcp/

## Rollback Instructions

If issues arise:

### Rollback Data Collection
1. Delete 4 new nodes (Split, Prepare Entity, Write KG, Merge)
2. Reconnect "Combine Business Data" → "Upsert Business"
3. Save workflow

### Rollback RAG Chat
1. Delete "Tool: Knowledge Graph Search" node
2. Remove hybrid query section from system prompt
3. Save workflow

### Rollback is Safe
- Postgres data unaffected (SQL-only queries work)
- Neo4j data can be cleared: `MATCH (n) DETACH DELETE n;`
- No schema changes to databases
- Workflows return to Issue #12 state

---

**Related Issues:**
- Completes: #13 (Knowledge Graph Integration)
- Builds on: #1-5 (Database + workflows)
- Complements: #12 (Strategic Views - SQL intelligence)
- Enables: #14-16 (Multi-source integration)
