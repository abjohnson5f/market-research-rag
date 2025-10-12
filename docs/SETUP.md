# Setup Guide

Quick start guide for implementing the Market Research RAG system.

## Prerequisites

- n8n instance (self-hosted or cloud)
- Postgres 14+ or Supabase account
- Apify account with Google Maps Scraper access
- OpenAI API key

## Implementation Order

Follow the GitHub issues in sequence:

### Issue #1: Database Schema Setup (30 min)
✅ Create Postgres/Supabase database
✅ Run `schema/01-tables.sql`
✅ Run `schema/02-indexes.sql`
✅ Test with sample data

**Outcome:** Database ready to receive data

---

### Issue #2: Data Collection Workflow (2-3 hours)
✅ Configure n8n Postgres credential
✅ Import workflow or build from building blocks
✅ Connect to Apify API
✅ Test with `limit=10`
✅ Verify data in database

**Outcome:** Automated data pipeline from Apify → Postgres

---

### Issue #3: RAG Chat Interface (2 hours)
✅ Configure OpenAI credential
✅ Add Chat Trigger node
✅ Add AI Agent with system prompt
✅ Add OpenAI Chat Model
✅ Add Postgres Chat Memory
✅ Test basic conversation

**Outcome:** Working chat interface (without database access yet)

---

### Issue #4: Postgres Tool Nodes (1-2 hours)
✅ Add Query Businesses Tool
✅ Add Query Reviews Tool
✅ Add Analyze Opportunities Tool
✅ Connect all tools to AI Agent
✅ Test SQL generation

**Outcome:** AI can query your data dynamically

---

### Issue #5: Testing & Validation (1-2 hours)
✅ Run all test queries
✅ Test end-to-end scenarios
✅ Verify performance benchmarks
✅ Document results

**Outcome:** Production-ready system

---

## Total Time: 8-12 hours

## Quick Start (if experienced with n8n)

```bash
# 1. Clone repo
git clone https://github.com/abjohnson5f/market-research-rag.git
cd market-research-rag

# 2. Set up database
psql "YOUR_POSTGRES_URL" -f schema/01-tables.sql
psql "YOUR_POSTGRES_URL" -f schema/02-indexes.sql

# 3. Import workflows to n8n
# - Import workflows/01-data-collection.json (when created)
# - Import workflows/02-rag-chat-interface.json (when created)

# 4. Configure credentials in n8n
# - Postgres: Your database connection
# - OpenAI: Your API key
# - Apify: Your API token

# 5. Test
# - Run data collection workflow with limit=10
# - Open chat interface and ask questions
```

## Need Help?

1. Check [docs/TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
2. Review the relevant GitHub issue
3. Search n8n community forum
4. Check Cole Medin's YouTube tutorials

## Architecture Overview

```
Apify Google Maps Scraper
  ↓
n8n Data Collection Workflow
  ↓
Postgres Database (JSONB storage)
  ↓
n8n RAG Chat Workflow
  ├─ AI Agent (GPT-4o-mini)
  ├─ Postgres Tools (SQL generation)
  └─ Chat Memory
  ↓
You (natural language interface)
```

## What You Get

- 📊 **Data Pipeline:** Apify → Postgres (automated)
- 💬 **Chat Interface:** Ask questions in natural language
- 🤖 **AI Agent:** Writes SQL queries dynamically
- 🔍 **Full-Text Search:** Find patterns in reviews
- 📈 **Analytics:** Market gaps, opportunities, insights
- 💡 **Newsletter Ideas:** On-demand generation
- 🚫 **No More JSON Parsing:** JSONB handles variable schemas

## Migration from Google Sheets

If you have an existing LOCAL MARKET RESEARCH workflow with Google Sheets:

1. **Backup your current workflow** (export as JSON)
2. **Follow Issue #2** to replace Sheets nodes with Postgres nodes
3. **Keep your 31 Code nodes** (they're good!)
4. **Remove:** All Parser nodes, If nodes, Repair nodes, Basic LLM Chains
5. **Test parallel:** Run old workflow once more, compare results in Sheets vs new Postgres queries
6. **Switch over:** Once validated, deactivate old workflow

## Production Checklist

Before going live:

- [ ] Database backups configured (daily snapshots)
- [ ] Error notifications set up (Slack/email)
- [ ] Scheduled executions configured (weekly market scans)
- [ ] Credentials secured (not in git)
- [ ] Chat interface access controlled (authentication if public)
- [ ] Performance benchmarks met (see Issue #5)
- [ ] Documentation updated with your custom queries
- [ ] Stakeholders trained on chat interface

## Support

- **GitHub Issues:** https://github.com/abjohnson5f/market-research-rag/issues
- **n8n Community:** https://community.n8n.io/
- **Supabase Docs:** https://supabase.com/docs
