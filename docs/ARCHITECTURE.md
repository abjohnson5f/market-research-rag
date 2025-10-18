# Market Research RAG System Architecture

> **System architecture documentation showing SQL + Knowledge Graph integration**

This document provides visual and technical architecture diagrams for the market-research-rag system, focusing on the hybrid SQL + Knowledge Graph approach.

## Table of Contents
- [System Overview](#system-overview)
- [Layer Architecture](#layer-architecture)
- [Data Flow Diagrams](#data-flow-diagrams)
- [Component Interactions](#component-interactions)
- [Technology Stack](#technology-stack)

---

## System Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                          │
│                    (n8n Chat Trigger UI)                        │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      EXECUTION LAYER                            │
│              (AI Agent + Tool Orchestration)                    │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  OpenAI GPT-4o-mini                                      │  │
│  │  - Natural language understanding                        │  │
│  │  - Tool selection logic                                  │  │
│  │  - Response synthesis                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                     INTELLIGENCE LAYER                          │
│              (SQL Views + Business Logic)                       │
│                                                                 │
│  ┌─────────────────────┐  ┌─────────────────────────────────┐  │
│  │  SQL Views          │  │  Business Rules                 │  │
│  │  - market_leaders   │  │  - Opportunity scoring          │  │
│  │  - underserved      │  │  - Competitive analysis         │  │
│  │  - high_potential   │  │  - Trend detection              │  │
│  └─────────────────────┘  └─────────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      KNOWLEDGE LAYER                            │
│           (Entity Resolution + Semantic Search)                 │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Knowledge Graph (Graphiti + Neo4j)                       │ │
│  │  - Entity resolution                                      │ │
│  │  - Semantic similarity                                    │ │
│  │  - Relationship discovery                                 │ │
│  │  - Multi-source integration                               │ │
│  └───────────────────────────────────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                        DATA LAYER                               │
│              (Postgres/Supabase JSONB Storage)                  │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐ │
│  │  businesses     │  │ business_reviews│  │market_executions│ │
│  │  - JSONB data   │  │  - JSONB data   │  │  - Audit trail │ │
│  │  - Generated    │  │  - Full-text    │  │  - Status      │ │
│  │    columns      │  │    search       │  │    tracking    │ │
│  └─────────────────┘  └─────────────────┘  └────────────────┘ │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      INGESTION LAYER                            │
│                 (ETL Pipeline + Dual Write)                     │
│                                                                 │
│  Apify API → Transform → Split → [Postgres + Neo4j] → Merge   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
                    [External Data Sources]
                    - Apify Google Maps Scraper
                    - Manual uploads (PDFs)
                    - Future: Permit databases, etc.
```

---

## Layer Architecture

### 1. Data Layer (Foundation)

**Purpose:** Persistent storage for raw and transformed data

**Components:**
- **Postgres/Supabase Database**
  - `businesses` table (JSONB storage)
  - `business_reviews` table (JSONB + full-text search)
  - `market_executions` table (audit trail)
  - Generated columns for fast filtering

**Characteristics:**
- Schema-flexible (JSONB)
- ACID compliant
- Indexed for performance
- Full-text search enabled

**Access Patterns:**
- High read, moderate write
- Batch inserts for reviews
- Upserts for businesses (idempotent)

---

### 2. Knowledge Layer (Entity Resolution)

**Purpose:** Semantic understanding and entity relationships

**Components:**
- **Neo4j Graph Database**
  - Business entities
  - City/Category nodes
  - Relationship edges

- **Graphiti MCP Server**
  - Entity extraction
  - Similarity calculation
  - Relationship inference

**Characteristics:**
- Graph-native storage
- Semantic search capabilities
- Entity resolution algorithms
- Relationship traversal

**Access Patterns:**
- Medium read, low write
- Similarity queries
- Path finding
- Entity matching

---

### 3. Intelligence Layer (Business Logic)

**Purpose:** Transform raw data into strategic insights

**Components:**
- **SQL Views**
  - `market_leaders` - Top performers by category
  - `underserved_markets` - Low competition opportunities
  - `high_potential_businesses` - Growth candidates

- **Business Rules**
  - Opportunity scoring formulas
  - Competitive thresholds
  - Quality filters

**Characteristics:**
- Derived from data layer
- Pre-computed for performance
- Updated on data refresh
- Business-specific logic

**Access Patterns:**
- High read, no write
- Complex aggregations
- Multi-table joins
- Cached results

---

### 4. Execution Layer (AI Orchestration)

**Purpose:** Coordinate tools and synthesize results

**Components:**
- **AI Agent (n8n LangChain)**
  - Tool selection
  - Query planning
  - Result synthesis

- **Available Tools**
  - `query_businesses` (SQL)
  - `query_reviews` (SQL)
  - `analyze_opportunities` (SQL Views)
  - `search_knowledge_graph` (Graph)

**Characteristics:**
- Stateless (chat memory separate)
- Multi-tool coordination
- Natural language interface
- Error handling

**Access Patterns:**
- User-initiated
- Variable complexity
- Hybrid queries (SQL + Graph)
- Response streaming

---

## Data Flow Diagrams

### Data Collection Flow

```
┌─────────────┐
│ Manual      │
│ Trigger     │
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│ Fetch Apify Data │
│ (HTTP Request)   │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Start Execution  │
│ (Insert record)  │
└──────┬───────────┘
       │
       ▼
┌────────────────────────────────────────┐
│ ETL Layer (7 Code Nodes)               │
│ - Overview                             │
│ - Contact                              │
│ - Social                               │
│ - Rating                               │
│ - Popular Times                        │
│ - Tags                                 │
│ - Lead Enrichment                      │
└──────┬─────────────────────────────────┘
       │
       ▼
┌──────────────────┐
│ Merge Layer      │
│ (6 Merge Nodes)  │
└──────┬───────────┘
       │
       ▼
┌──────────────────────┐
│ Combine Business Data│
│ (Create JSONB object)│
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Split: Dual Write    │
└──────┬───────────────┘
       │
   ┌───┴────┐
   ▼        ▼
┌────────┐ ┌─────────────────────┐
│Postgres│ │Prepare Graph Entity │
│ Upsert │ └──────┬──────────────┘
└────┬───┘        ▼
     │     ┌──────────────────────┐
     │     │ Write to Knowledge   │
     │     │ Graph (HTTP Request) │
     │     └──────┬───────────────┘
     │            │
     └────────┬───┘
              ▼
     ┌────────────────┐
     │ Merge Paths    │
     └────────┬───────┘
              ▼
     ┌────────────────────┐
     │ Prepare Reviews    │
     └────────┬───────────┘
              ▼
     ┌────────────────────┐
     │ Insert Reviews     │
     │ (Batch transaction)│
     └────────┬───────────┘
              ▼
     ┌────────────────────┐
     │ Complete Execution │
     │ (Update status)    │
     └────────────────────┘
```

---

### Chat Query Flow

```
┌──────────────┐
│ User Message │
└──────┬───────┘
       │
       ▼
┌───────────────────┐
│ Chat Trigger Node │
└──────┬────────────┘
       │
       ▼
┌────────────────────────────┐
│ AI Agent                   │
│ - Parse intent             │
│ - Select tool(s)           │
│ - Plan query strategy      │
└──────┬─────────────────────┘
       │
       ▼
   Decision Point
       │
   ┌───┴────────────────────┐
   │                        │
   ▼                        ▼
SQL Query               Graph Query
   │                        │
   ▼                        ▼
┌─────────────┐      ┌──────────────┐
│ query_      │      │ search_      │
│ businesses  │      │ knowledge_   │
│ (SQL)       │      │ graph        │
└──────┬──────┘      └──────┬───────┘
       │                    │
       ▼                    ▼
┌─────────────┐      ┌──────────────┐
│ Postgres    │      │ Neo4j        │
│ Database    │      │ + Graphiti   │
└──────┬──────┘      └──────┬───────┘
       │                    │
       │    ┌───────────────┘
       │    │
       ▼    ▼
   ┌─────────────────┐
   │ AI Agent        │
   │ - Synthesize    │
   │ - Format        │
   │ - Cite sources  │
   └────────┬────────┘
            │
            ▼
   ┌─────────────────┐
   │ Natural Language│
   │ Response        │
   └─────────────────┘
```

---

### Hybrid Query Pattern

**Example:** "Find best Phoenix HVAC businesses and similar competitors"

```
User Query: "Best Phoenix HVAC + competitors"
       │
       ▼
┌────────────────────────────┐
│ AI Agent Decomposition     │
│ - Part 1: Best Phoenix HVAC│
│ - Part 2: Similar entities │
└──────┬─────────────────────┘
       │
   ┌───┴────┐
   │        │
   ▼        ▼
[Step 1]  [Step 2]
SQL       SQL Views
Filter    Analysis
   │        │
   ▼        ▼
Phoenix   market_leaders
 HVAC     view
rating>4.5   │
   │         │
   └────┬────┘
        │
   Result: Top 3 businesses
   [XYZ, ABC, DEF]
        │
        ▼
   ┌────────────────┐
   │ [Step 3]       │
   │ Graph Search   │
   │ For each top 3:│
   │ - Find similar │
   └────────┬───────┘
            │
            ▼
   ┌─────────────────────┐
   │ Neo4j Similarity    │
   │ - XYZ → [GHI, JKL]  │
   │ - ABC → [MNO, PQR]  │
   │ - DEF → [STU]       │
   └────────┬────────────┘
            │
            ▼
   ┌─────────────────────┐
   │ [Step 4]            │
   │ Synthesize Results  │
   │ - Top 3 leaders     │
   │ - 6 competitors     │
   │ - Strategic insight │
   └─────────────────────┘
```

---

## Component Interactions

### Tool Selection Matrix

| Query Type | Primary Tool | Secondary Tool | Reasoning |
|------------|-------------|----------------|-----------|
| "Phoenix HVAC businesses" | `query_businesses` | None | Exact filter (city + category) |
| "Reviews mentioning price" | `query_reviews` | None | Text search on reviews |
| "Best market opportunities" | `analyze_opportunities` | None | Pre-computed SQL view |
| "Is ABC same as ABC Inc?" | `search_knowledge_graph` | None | Entity resolution |
| "Find similar to XYZ" | `search_knowledge_graph` | None | Semantic similarity |
| "Best HVAC + competitors" | `query_businesses` | `search_knowledge_graph` | Hybrid: filter + similarity |

---

### Data Synchronization

**Postgres → Neo4j Flow:**

```
New Business Data
       │
       ▼
┌──────────────────┐
│ Combine Business │
│ Data (Code Node) │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Split Node       │
└──────┬───────────┘
       │
   ┌───┴────┐
   ▼        ▼
Path 1    Path 2
Postgres  Neo4j
   │        │
   ▼        ▼
[Upsert] [HTTP POST]
   │        │
   │    ┌───┴────────────────┐
   │    │ Graphiti MCP       │
   │    │ - Parse entity     │
   │    │ - Extract attrs    │
   │    │ - Create/update    │
   │    └────────┬───────────┘
   │             │
   │             ▼
   │      ┌──────────────┐
   │      │ Neo4j Write  │
   │      │ CREATE/MERGE │
   │      └──────┬───────┘
   │             │
   └─────────┬───┘
             ▼
    ┌────────────────┐
    │ Merge Node     │
    │ - Rejoin paths │
    │ - Continue ETL │
    └────────────────┘
```

**Consistency Model:**
- **Eventual consistency** between Postgres and Neo4j
- **Postgres as source of truth** for raw data
- **Neo4j as derived knowledge** layer
- **Dual-write with graceful degradation** (Postgres succeeds even if Neo4j fails)

---

## Technology Stack

### Core Infrastructure

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Orchestration** | n8n | Workflow automation |
| **SQL Database** | Postgres/Supabase | Relational + JSONB storage |
| **Graph Database** | Neo4j | Entity relationships |
| **Graph MCP** | Graphiti | Entity resolution |
| **AI Model** | OpenAI GPT-4o-mini | Natural language processing |
| **AI Framework** | LangChain (n8n nodes) | Agent orchestration |

### Data Ingestion

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Scraper** | Apify Google Maps | Business data collection |
| **ETL** | n8n Code nodes (JavaScript) | Data transformation |
| **Storage** | Postgres JSONB | Flexible schema storage |

### Intelligence Layer

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **SQL Views** | Postgres Views | Pre-computed insights |
| **Full-text Search** | Postgres tsvector | Review text search |
| **Entity Resolution** | Graphiti + Neo4j | Duplicate detection |
| **Semantic Search** | Neo4j + Embeddings | Similarity matching |

### Execution Layer

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **AI Agent** | n8n LangChain Agent | Tool orchestration |
| **Chat Interface** | n8n Chat Trigger | User interaction |
| **Memory** | Postgres Chat Memory | Conversation history |
| **Tools** | n8n LangChain Tools | SQL + Graph queries |

---

## Deployment Architecture

### Local Development

```
┌─────────────────────────────────────┐
│ Developer Machine                   │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ n8n (Docker)                 │  │
│  │ http://localhost:5678        │  │
│  └──────────────────────────────┘  │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ Postgres (Local)             │  │
│  │ port 5432                    │  │
│  └──────────────────────────────┘  │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ Neo4j Desktop                │  │
│  │ bolt://localhost:7687        │  │
│  └──────────────────────────────┘  │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ Graphiti MCP Server          │  │
│  │ http://localhost:3000        │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Production Deployment

```
┌─────────────────────────────────────────┐
│ Cloud Infrastructure                    │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ n8n Cloud / Self-hosted           │  │
│  │ https://your-instance.n8n.cloud   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ Supabase                          │  │
│  │ - Managed Postgres                │  │
│  │ - Connection pooling              │  │
│  │ - Automatic backups               │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ Neo4j AuraDB                      │  │
│  │ - Managed graph database          │  │
│  │ - Automatic scaling               │  │
│  │ - bolt+s:// secure connection     │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ Graphiti MCP (Cloud Run/Heroku)  │  │
│  │ - Serverless deployment           │  │
│  │ - Auto-scaling                    │  │
│  │ - HTTPS endpoint                  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

---

## Design Decisions

### Why JSONB for Business Data?

**Pros:**
- Schema flexibility for varying Apify responses
- No parsing errors (direct storage)
- Fast nested queries with operators (->>, @>)
- GIN indexes for performance

**Cons:**
- Requires generated columns for common filters
- Less strict validation than normalized tables

**Decision:** JSONB optimal for semi-structured scraper data

---

### Why Dual-Write (Postgres + Neo4j)?

**Pros:**
- Postgres for exact queries (city, category, rating)
- Neo4j for semantic queries (similarity, relationships)
- Best tool for each job

**Cons:**
- Eventual consistency risk
- Additional infrastructure complexity

**Decision:** Benefits outweigh complexity for entity resolution use case

---

### Why Knowledge Graph vs Vector Similarity?

| Approach | Pros | Cons |
|----------|------|------|
| **Vector Embeddings** | Fast similarity, cheap storage | No relationships, semantic drift |
| **Knowledge Graph** | Explicit relationships, explainable | Setup complexity, query learning curve |

**Decision:** Graph for entity resolution (duplicate detection), vectors for document similarity (future feature)

---

## Performance Characteristics

### Expected Query Times

| Query Type | Target Latency | Notes |
|------------|----------------|-------|
| SQL exact filter | <200ms | With proper indexes |
| SQL aggregation | <500ms | Pre-computed views help |
| Graph entity lookup | <300ms | By apify_place_id |
| Graph similarity search | <1000ms | Depends on similarity algorithm |
| Hybrid (SQL + Graph) | <1500ms | Sequential execution |

### Scalability Limits

| Component | Current Limit | Notes |
|-----------|---------------|-------|
| Businesses (Postgres) | ~1M rows | JSONB + indexes scale well |
| Reviews (Postgres) | ~10M rows | Batch inserts required |
| Entities (Neo4j) | ~100K nodes | Desktop edition limits |
| Relationships (Neo4j) | ~1M edges | Performance degrades >10M |

**Recommendation:** For >100K businesses, consider Neo4j Enterprise

---

## Future Enhancements

### Planned Features

1. **Vector Search Integration**
   - Add pgvector extension to Postgres
   - Embed review text for semantic search
   - Combine with graph for hybrid relevance

2. **Real-time Sync**
   - Webhook triggers for data updates
   - Incremental graph updates
   - Change data capture (CDC)

3. **Multi-Source Integration**
   - Permit databases
   - PDF document ingestion
   - Social media data

4. **Advanced Graph Features**
   - Community detection algorithms
   - PageRank for business importance
   - Shortest path for supply chain analysis

---

**Related Documentation:**
- [KNOWLEDGE-GRAPH-SETUP.md](./KNOWLEDGE-GRAPH-SETUP.md) - Setup instructions
- [KNOWLEDGE-GRAPH-TESTING.md](./KNOWLEDGE-GRAPH-TESTING.md) - Testing guide
- [IMPLEMENTATION-CHECKLIST-13.md](./IMPLEMENTATION-CHECKLIST-13.md) - Implementation steps
