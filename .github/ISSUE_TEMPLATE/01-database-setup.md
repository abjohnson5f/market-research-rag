---
name: 🗄️ Database Schema Setup
about: Create Postgres/Supabase database schema
title: "[SETUP] Database Schema & Tables"
labels: setup, database, priority-high
assignees: ''
---

## 📋 Objective

Set up the Postgres/Supabase database schema for the Market Research RAG system. This replaces Google Sheets with a proper relational database that stores business data in JSONB columns.

**Time estimate:** 30 minutes
**Prerequisites:** Postgres 14+ or Supabase account
**Dependencies:** None (start here)

---

## 🎯 What You're Building

Three tables:
1. **`market_executions`** - Tracks each workflow run
2. **`businesses`** - One row per business with JSONB data
3. **`business_reviews`** - One-to-many reviews with full-text search

Plus indexes, triggers, and views for performance.

---

## 📝 Step-by-Step Instructions

### Step 1: Create Database

**Option A: Supabase (Recommended)**
1. Go to [supabase.com](https://supabase.com)
2. Click "New Project"
3. Project name: `market-research-rag`
4. Database password: **Save this securely**
5. Region: Choose closest to you
6. Wait 2-3 minutes for provisioning

**Option B: Self-Hosted Postgres**
```bash
# Create database
createdb market_research_rag

# Or via SQL
psql -U postgres
CREATE DATABASE market_research_rag;
\c market_research_rag
```

### Step 2: Get Connection String

**Supabase:**
1. Go to Project Settings → Database
2. Copy "Connection string" (transaction mode)
3. Replace `[YOUR-PASSWORD]` with your database password
4. Save as: `postgresql://postgres:[PASSWORD]@db.[PROJECT].supabase.co:5432/postgres`

**Self-Hosted:**
```
postgresql://postgres:password@localhost:5432/market_research_rag
```

### Step 3: Run Schema SQL

Copy [`schema/01-tables.sql`](../../schema/01-tables.sql) and execute:

**Via Supabase Studio:**
1. Open SQL Editor
2. Paste `01-tables.sql` contents
3. Click "Run"
4. Verify: "Success. No rows returned"

**Via command line:**
```bash
psql "postgresql://..." -f schema/01-tables.sql
```

**Verify tables created:**
```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public';
```

Expected output:
```
 table_name
------------------
 market_executions
 businesses
 business_reviews
```

### Step 4: Create Indexes

Copy [`schema/02-indexes.sql`](../../schema/02-indexes.sql) and execute same way.

**Verify indexes:**
```sql
SELECT tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

You should see ~15-20 indexes.

### Step 5: Test with Sample Data

Run this to verify everything works:

```sql
-- Insert test execution
INSERT INTO market_executions (search_query, status)
VALUES ('test search', 'completed')
RETURNING id;

-- Remember the ID (let's say it's 1)

-- Insert test business
INSERT INTO businesses (
  execution_id,
  business_name,
  apify_place_id,
  business_data
) VALUES (
  1,
  'Test Coffee Shop',
  'test-place-123',
  '{
    "overview": {"city": "Phoenix", "category": "Coffee Shop"},
    "rating": {"totalScore": 4.5, "reviewsCount": 42},
    "contact": {"phone": "555-1234", "website": "test.com"}
  }'::jsonb
) RETURNING id;

-- Insert test review
INSERT INTO business_reviews (business_id, review_data)
VALUES (
  1,
  '{
    "reviewerName": "John Doe",
    "stars": 5,
    "text": "Great coffee and parking!",
    "publishedAtDate": "2025-01-01"
  }'::jsonb
);

-- Query it back
SELECT
  b.business_name,
  b.city,
  b.rating,
  r.review_text,
  r.stars
FROM businesses b
JOIN business_reviews r ON r.business_id = b.id
WHERE b.business_name = 'Test Coffee Shop';
```

Expected output:
```
    business_name     |  city   | rating |        review_text        | stars
----------------------+---------+--------+---------------------------+-------
 Test Coffee Shop     | Phoenix |    4.5 | Great coffee and parking! |     5
```

### Step 6: Clean Up Test Data

```sql
-- Remove test data (cascades to reviews automatically)
DELETE FROM market_executions WHERE search_query = 'test search';
```

### Step 7: Save Connection String for n8n

Create a note with your connection details:

```
Postgres Connection (for n8n credential)
----------------------------------------
Type: Postgres
Host: db.[PROJECT].supabase.co (or localhost)
Port: 5432
Database: postgres (or market_research_rag)
User: postgres
Password: [YOUR-PASSWORD]
SSL: true (for Supabase) / false (for localhost)

Full connection string:
postgresql://postgres:[PASSWORD]@[HOST]:5432/[DATABASE]
```

You'll need this in the next issue when configuring n8n.

---

## ✅ Acceptance Criteria

- [ ] Database created (Supabase or self-hosted)
- [ ] `01-tables.sql` executed successfully
- [ ] `02-indexes.sql` executed successfully
- [ ] 3 tables exist: `market_executions`, `businesses`, `business_reviews`
- [ ] Test query with sample data works
- [ ] Connection string saved for n8n
- [ ] Can access database via Supabase Studio or pgAdmin

---

## 🐛 Troubleshooting

**"Role does not exist"**
- Solution: Use `postgres` user, not your system username
- Command: `psql -U postgres -d market_research_rag`

**"Permission denied for schema public"**
- Supabase: Make sure you're using the transaction pooler connection string
- Self-hosted: Grant permissions: `GRANT ALL ON SCHEMA public TO postgres;`

**"Generated column cannot have a default value"**
- This means you're on Postgres < 12
- Upgrade to Postgres 14+ (required for generated columns)

**Indexes taking long time**
- Normal! GIN indexes on JSONB can take 10-30 seconds on first creation
- Subsequent runs use `IF NOT EXISTS` so they're instant

---

## 📚 Additional Resources

- [Supabase Quickstart](https://supabase.com/docs/guides/getting-started)
- [Postgres JSONB Documentation](https://www.postgresql.org/docs/current/datatype-json.html)
- [GIN Indexes Explained](https://www.postgresql.org/docs/current/gin-intro.html)
- [Generated Columns](https://www.postgresql.org/docs/current/ddl-generated-columns.html)

---

## 🔄 Next Steps

After completing this issue:
- ✅ Mark this issue as complete
- ➡️ Move to **Issue #2: Data Collection Workflow** to build the n8n pipeline that populates these tables
