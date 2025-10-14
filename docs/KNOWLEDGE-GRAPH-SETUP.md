# Knowledge Graph Integration Setup Guide

> **Adds Graphiti + Neo4j entity resolution layer to market-research-rag system**

This guide provides step-by-step instructions for integrating knowledge graph capabilities into your n8n workflows to enable entity resolution, semantic search, and multi-source synthesis.

## Overview

### What This Adds

**Current State:** SQL-only queries on business data
**New Capabilities:**
- Entity resolution ("Is ABC Cooling same as ABC Cooling & Heating Inc?")
- Semantic search ("Find businesses similar to XYZ Company")
- Relationship discovery ("What businesses have similar complaint patterns?")
- Multi-source integration (link permit data, PDFs, Apify records)

### Architecture Changes

```
Before (SQL-Only):
Apify API → Postgres (JSONB) → SQL Views → AI Agent

After (Hybrid SQL + Graph):
Multi-Source Data → Dual-Write Pipeline
  ├─ Postgres (JSONB) → SQL Views → Quantitative analysis
  └─ Graphiti + Neo4j → Knowledge Graph → Semantic reasoning

AI Agent (4 tools):
  ├─ query_businesses (SQL)
  ├─ query_reviews (SQL)
  ├─ analyze_opportunities (SQL views)
  └─ search_knowledge_graph (Graph) ← NEW
```

## Prerequisites

### 1. Graphiti MCP Server Running

Verify installation:
```bash
curl http://localhost:3000/health
```

### 2. Neo4j Database Connected

Test connection:
```bash
cypher-shell -u neo4j -p your-password
MATCH (n) RETURN count(n) LIMIT 1;
```

### 3. n8n MCP Credentials Configured

Add "MCP Client" credential in n8n Settings with server URL `http://localhost:3000`

## Part A: Data Collection Workflow Updates

### Step 1: Add Split Node

**Location:** Between "Combine Business Data" and "Upsert Business"

**Configuration:**
- Type: Split Out
- Mode: batch
- Position: [2700, 480]

### Step 2: Add "Prepare Graph Entity" Code Node

**Purpose:** Transform business data for knowledge graph

**JavaScript Code:**
```javascript
const businessData = $json.business_data;

return {
  json: {
    ...$json,
    graph_entity: {
      name: $json.business_name,
      type: "Business",
      attributes: {
        apify_place_id: $json.apify_place_id,
        place_url: businessData.overview?.url,
        category: businessData.overview?.category,
        city: businessData.overview?.city,
        state: businessData.overview?.state,
        phone: businessData.contact?.phone,
        website: businessData.contact?.website,
        rating: businessData.rating?.totalScore,
        review_count: businessData.rating?.reviewsCount,
        last_updated: new Date().toISOString()
      }
    }
  }
};
```

### Step 3: Add "Write to Knowledge Graph" HTTP Request Node

**Configuration:**
- Method: POST
- URL: `http://localhost:3000/graphiti/entities`
- Body: `{{ JSON.stringify($json.graph_entity) }}`
- Continue On Fail: true
- Retries: 3

### Step 4: Add Merge Node

Recombine Postgres and Graph paths before "Prepare Reviews for Insert"

### Updated Flow

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

## Part B: RAG Chat Interface Updates

### Add Knowledge Graph Tool Node

**Node Type:** Tool: HTTP Request (LangChain)

**Configuration:**
- Name: `search_knowledge_graph`
- Method: POST
- URL: `http://localhost:3000/graphiti/search`
- Description: "Search the knowledge graph for entity resolution, semantic similarity, and relationship discovery. Use when user asks about similar businesses or entity matching."

**Connection:**
Connect this tool to "Market Research AI Agent" via ai_tool input

## Part C: AI Agent System Prompt Updates

Add this section to the existing system prompt:

```
## Hybrid Query Strategy

You now have 4 tools:
1. query_businesses (SQL) - Exact filters, aggregations
2. query_reviews (SQL) - Review text search
3. analyze_opportunities (SQL) - Market analysis views
4. search_knowledge_graph (Graph) - Entity resolution, semantic search

When to use Knowledge Graph:
- Entity resolution ("Is ABC same as ABC Inc?")
- Semantic search ("Find similar businesses")
- Relationship discovery ("Similar complaint patterns")

When to use SQL:
- Exact filters (city, category, rating)
- Review analysis (keyword search)
- Market metrics (opportunity scores)

Hybrid Pattern: Use both for comprehensive analysis
Example: "Best Phoenix HVAC + competitors"
1. Filter with SQL (Phoenix, HVAC, rating > 4.5)
2. Get metrics with SQL (market_leaders view)
3. Find similar with Graph (semantic search)
4. Synthesize results
```

## Testing

### Test 1: Verify Dual-Write
Run data collection workflow and check both Postgres and Neo4j receive data.

### Test 2: Test Knowledge Graph Tool
Ask: "Is there a business called ABC Cooling?"
Verify AI uses knowledge graph tool for entity resolution.

### Test 3: Test Hybrid Query
Ask: "Find best Phoenix HVAC businesses and similar competitors"
Verify AI uses both SQL (for filtering) and Graph (for similarity).

See [KNOWLEDGE-GRAPH-TESTING.md](./KNOWLEDGE-GRAPH-TESTING.md) for detailed test procedures.

## Troubleshooting

**Issue:** Knowledge graph write fails
**Solution:** Enable "Continue On Fail" so Postgres write succeeds

**Issue:** Empty graph results
**Solution:** Verify entities in Neo4j: `MATCH (n:Business) RETURN count(n);`

**Issue:** AI uses wrong tool
**Solution:** Update system prompt with clearer decision rules

---

**Next:** See [KNOWLEDGE-GRAPH-TESTING.md](./KNOWLEDGE-GRAPH-TESTING.md) for testing procedures
