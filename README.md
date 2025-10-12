# Market Research RAG System

> **Transform local business data from Apify into an AI-powered market intelligence assistant**

This repository contains n8n workflows and database schemas to replace Google Sheets-based market research analysis with a RAG (Retrieval-Augmented Generation) chat interface powered by Postgres/Supabase.

## 🎯 What This Does

Instead of:
- ❌ Fighting JSON parsing errors
- ❌ Manually analyzing Google Sheets
- ❌ Static, pre-generated insights

You get:
- ✅ Clean data pipeline (Apify → Postgres)
- ✅ Interactive AI chat interface
- ✅ On-demand market analysis
- ✅ SQL-powered insights

## 🏗️ Architecture

### Data Collection Workflow
```
Manual Trigger → Apify API → ETL (Code nodes) → Postgres (JSONB storage)
```

**What it stores:**
- Business profiles (overview, contact, social, ratings)
- Customer reviews (with full-text search)
- Popular times and traffic patterns
- Market execution metadata

### RAG Chat Interface
```
User Question → AI Agent → Postgres Tools → SQL Queries → Natural Language Answer
```

**What you can ask:**
- "What are the best opportunities for local newsletters in Phoenix?"
- "Analyze reviews for auto repair shops - what are customers complaining about?"
- "Generate 30 newsletter ideas for home services businesses"

## 📁 Repository Structure

```
market-research-rag/
├── workflows/
│   ├── 01-data-collection.json          # Main ETL pipeline
│   ├── 02-rag-chat-interface.json       # AI chat assistant
│   └── building-blocks/                 # Reusable node templates
│       ├── postgres-create-table.json
│       ├── postgres-upsert.json
│       ├── postgres-insert-batch.json
│       └── postgres-tool-nodes.json
├── schema/
│   ├── 01-tables.sql                    # Database schema
│   ├── 02-indexes.sql                   # Performance indexes
│   └── 03-optional-pgvector.sql         # Vector search (optional)
├── docs/
│   ├── SETUP.md                         # Installation guide
│   ├── MIGRATION.md                     # From Google Sheets
│   └── QUERIES.md                       # Example SQL queries
└── README.md                            # This file
```

## 🚀 Quick Start

### Prerequisites
- n8n instance (self-hosted or cloud)
- Postgres/Supabase database
- Apify account with Google Maps Scraper
- OpenAI API key (for embeddings and chat)

### Installation

1. **Set up database** (5 minutes)
   ```bash
   # Create Supabase project or Postgres database
   # Run schema/01-tables.sql
   # Run schema/02-indexes.sql
   ```

2. **Import workflows** (2 minutes)
   - Import `workflows/01-data-collection.json` to n8n
   - Import `workflows/02-rag-chat-interface.json` to n8n
   - Update credentials (Postgres, Apify, OpenAI)

3. **Test data collection** (10 minutes)
   - Run workflow #1 with small dataset (10 businesses)
   - Verify data in Supabase Studio

4. **Start chatting** (immediate)
   - Open workflow #2 chat interface
   - Ask: "What businesses did we find?"

See [docs/SETUP.md](docs/SETUP.md) for detailed instructions.

## 📊 Database Schema

### Core Tables

**`market_executions`** - Tracks each workflow run
- `id`, `created_at`, `status`, `total_businesses`, `search_query`

**`businesses`** - One row per business
- `id`, `execution_id`, `business_name`, `business_data` (JSONB)
- Generated columns: `city`, `category`, `rating`, `review_count`

**`business_reviews`** - One-to-many reviews
- `id`, `business_id`, `review_data` (JSONB)
- Full-text search on review text

See [schema/01-tables.sql](schema/01-tables.sql) for complete DDL.

## 🎓 Inspired By

This architecture is based on **Cole Medin's RAG AI Agent Template V5**, adapting his patterns for market research:

- JSONB storage for semi-structured data
- Postgres Tool nodes for AI agent queries
- Upsert patterns for idempotent operations
- Chat interface for interactive analysis

**Key differences from Cole's template:**
- Optimized for business/review data (not documents)
- Batch processing for Apify datasets
- Market-specific analysis tools

## 📝 GitHub Issues

Implementation is broken down into digestible issues:

1. **Database Schema Setup** - Create tables, indexes, views
2. **Data Collection Workflow** - Build ETL pipeline with Postgres nodes
3. **RAG Chat Interface** - Set up AI agent and chat trigger
4. **Postgres Tool Nodes** - Create SQL query tools for agent
5. **Testing & Validation** - Verify end-to-end functionality

Each issue includes:
- Complete node JSON (copy-paste ready)
- Step-by-step instructions
- Testing checklist
- Expected outcomes

## 🤝 Contributing

This is a personal project, but issues and suggestions are welcome!

## 📄 License

MIT

---

**Built with:** n8n • Postgres/Supabase • OpenAI • Apify
