# Data Collection Workflow Guide

> **Complete guide to importing, configuring, and testing the n8n data collection workflow**

## Overview

This workflow replaces the Google Sheets-based pipeline with a clean Postgres-backed system. It fetches business data from Apify, transforms it through your existing ETL Code nodes, and stores everything in JSONB columns for flexible querying.

**What it does:**
- Fetches Google Maps business data from Apify API
- Tracks each execution in `market_executions` table
- Transforms data through existing Code nodes (Overview, Contact, Social, etc.)
- Stores businesses with UPSERT (prevents duplicates)
- Stores reviews with batch INSERT (atomic transactions)
- Updates execution statistics automatically via triggers

**What's included:**
- 11 nodes (down from 106 in original workflow!)
- 4 Sticky Note guides embedded in workflow
- Placeholder credentials for easy configuration
- Test-friendly (starts with limit=10)

---

## Prerequisites

Before importing, ensure you have:

- [ ] **Database schema deployed** (Issue #1 completed)
- [ ] **n8n instance** (self-hosted or cloud)
- [ ] **Apify account** with Google Maps Scraper dataset
- [ ] **Postgres/Supabase** connection details

---

## Step 1: Import Workflow

### Option A: Via n8n UI (Recommended)

1. Open n8n web interface
2. Click **Workflows** in sidebar
3. Click **+ Add workflow** button (top right)
4. Click the **⋮** menu → **Import from File**
5. Select `workflows/01-data-collection.json`
6. Click **Import**

### Option B: Via n8n CLI

```bash
# If using n8n CLI
n8n import:workflow --input=workflows/01-data-collection.json
```

**Expected result:** Workflow opens in canvas with 11 nodes and 4 sticky notes

---

## Step 2: Configure Credentials

### A. Postgres Database Credential

1. In n8n, go to **Settings** → **Credentials** → **New**
2. Search for and select `Postgres`
3. Fill in connection details:

   **For Supabase:**
   ```
   Name: Market Research DB
   Host: db.[YOUR-PROJECT].supabase.co
   Database: postgres
   User: postgres
   Password: [your-password-from-issue-1]
   Port: 5432
   SSL Mode: require
   ```

   **For local Postgres:**
   ```
   Name: Market Research DB
   Host: localhost
   Database: market_research
   User: postgres
   Password: [your-local-password]
   Port: 5432
   SSL Mode: disable
   ```

4. Click **Test Connection** → Should show "Connection successful"
5. Click **Save**

### B. Apify API Credential

n8n uses HTTP Query Authentication for Apify:

1. In n8n, go to **Settings** → **Credentials** → **New**
2. Search for and select `HTTP Query Auth`
3. Fill in:
   ```
   Name: Apify API Token
   Name: token
   Value: [your-apify-api-token]
   ```

   **Where to find Apify token:**
   - Log into Apify Console
   - Go to Settings → Integrations → API
   - Copy your API token

4. Click **Save**

### C. Apply Credentials to Workflow Nodes

The workflow has placeholder credential IDs. Update these:

1. **Start Execution** node
   - Click node → Credentials tab
   - Select "Market Research DB"

2. **Upsert Business** node
   - Click node → Credentials tab
   - Select "Market Research DB"

3. **Insert Reviews Batch** node
   - Click node → Credentials tab
   - Select "Market Research DB"

4. **Complete Execution** node
   - Click node → Credentials tab
   - Select "Market Research DB"

5. **Fetch Apify Data** node
   - Click node → Credentials tab
   - Select "Apify API Token"
   - In Parameters tab, update URL:
     ```
     https://api.apify.com/v2/datasets/YOUR_DATASET_ID/items?limit=10
     ```
     Replace `YOUR_DATASET_ID` with your actual dataset ID from Apify

---

## Step 3: Connect Your Existing ETL Nodes

**IMPORTANT:** This workflow is designed to KEEP your existing Code nodes, not replace them.

### What to Keep

From your original workflow, keep these nodes:
- ✅ All **Code** nodes (Overview, Contact, Social, Rating, Tags, Lead Enrichment, etc.)
- ✅ All **Merge** nodes that combine dimensions
- ✅ Any custom transformation logic you've built

### What to Remove

From your original workflow, remove these:
- ❌ All 19 **Google Sheets** nodes
- ❌ All **Parser** nodes (Niche ID Parser, Opportunity Parser)
- ❌ All **If** nodes checking parsing success
- ❌ All **Repair Code** nodes
- ❌ All **Basic LLM Chain** nodes
- ❌ Final **AI Agent** (newsletter generation)

### How to Connect

1. **Input connection:**
   - Connect `Fetch Apify Data` node → Your first ETL Code node

2. **Modify each Code node to track execution:**

   At the **TOP** of each Code node, add:
   ```javascript
   const executionId = $('Store Execution ID').first().json.execution_id;
   ```

   In your **return statement**, add execution_id:
   ```javascript
   return items.map(item => {
     const d = item.json;

     return {
       json: {
         execution_id: executionId,  // ADD THIS LINE
         // ... rest of your existing fields
         title: d.title || null,
         category: d.categoryName || null,
         // etc.
       }
     };
   });
   ```

   **Apply this to ALL transformation Code nodes.**

3. **Output connection:**
   - Connect your final merged output → `Combine Business Data` node

### Example Connection Flow

```
Fetch Apify Data
  ↓
[Your Overview Code node]
  ↓
[Your Contact Code node]
  ↓
[Your Social Code node]
  ↓
[Your Merge nodes combining dimensions]
  ↓
Combine Business Data  ← Connect here
```

---

## Step 4: Customize "Combine Business Data" Node

The `Combine Business Data` Code node needs to reference YOUR specific node names.

Open the node and update the `getNodeData()` calls to match your actual node names:

```javascript
// Find this section in the Code node:
const overview = $('Overview').all()[0]?.json || {};          // Update 'Overview' to your node name
const contact = $('Contact').all()[0]?.json || {};            // Update 'Contact' to your node name
const social = $('Social').all()[0]?.json || {};              // Update 'Social' to your node name
const rating = $('Rating').all()[0]?.json || {};              // Update 'Rating' to your node name
const popularTimes = $('popularTimesHistogram').all()[0]?.json || {};  // Update to your node name
const tags = $('Tags').all()[0]?.json || {};                  // Update 'Tags' to your node name
const leadEnrichment = $('Lead enrichment').all()[0]?.json || {};      // Update to your node name
```

**Tip:** If you don't have all these dimensions, set to `{}` or remove from business_data object.

---

## Step 5: Test the Workflow

### Initial Test (10 Businesses)

The workflow is pre-configured with `limit=10` for safe testing.

1. Click **Execute workflow** button (top right)
2. Watch nodes light up as they process
3. Check for any red error nodes
4. Should complete in 10-30 seconds

**What to check:**
- ✅ All nodes show green checkmarks
- ✅ `Store Execution ID` node shows `execution_id` in output
- ✅ `Upsert Business` node shows 10 items with `id` field
- ✅ `Insert Reviews Batch` node shows multiple items (reviews flattened)
- ✅ `Complete Execution` node shows success

### Verify in Database

Run these test queries in Supabase Studio or psql:

#### Test 1: Check Execution Record

```sql
SELECT
  id,
  created_at,
  completed_at,
  status,
  search_query,
  total_businesses,
  total_reviews
FROM market_executions
ORDER BY created_at DESC
LIMIT 1;
```

**Expected:**
- `status = 'completed'`
- `total_businesses = 10`
- `total_reviews > 0`

#### Test 2: Check Business Data

```sql
SELECT
  id,
  business_name,
  city,
  category,
  rating,
  review_count,
  website,
  phone
FROM businesses
WHERE execution_id = (SELECT MAX(id) FROM market_executions)
LIMIT 5;
```

**Expected:**
- 10 rows total
- `city`, `category`, `rating` extracted from JSONB
- Real business data visible

#### Test 3: Check JSONB Structure

```sql
SELECT
  business_name,
  business_data->'overview'->>'city' as city,
  business_data->'rating'->>'totalScore' as rating,
  business_data->'contact'->>'phone' as phone,
  business_data->'social'->>'instagrams' as instagram,
  business_data->>'scraped_at' as scraped_at
FROM businesses
WHERE execution_id = (SELECT MAX(id) FROM market_executions)
LIMIT 3;
```

**Expected:**
- All JSONB paths resolve correctly
- Data matches what's in generated columns

#### Test 4: Check Reviews

```sql
SELECT
  b.business_name,
  r.reviewer_name,
  r.stars,
  LEFT(r.review_text, 100) as review_snippet
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE b.execution_id = (SELECT MAX(id) FROM market_executions)
LIMIT 10;
```

**Expected:**
- Multiple reviews per business
- `business_id` foreign key working
- Review text extracted from JSONB

#### Test 5: Full-Text Search

```sql
SELECT
  b.business_name,
  r.review_text,
  r.stars
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE to_tsvector('english', r.review_text) @@ to_tsquery('great | excellent')
LIMIT 5;
```

**Expected:**
- Reviews containing "great" or "excellent"
- Full-text search working (requires index from Issue #1)

---

## Step 6: Scale to Full Dataset

Once testing succeeds:

1. Open `Fetch Apify Data` node
2. In Parameters → Query Parameters
3. **Remove** the `limit` parameter entirely
4. Save workflow
5. Execute

**Performance expectations:**
- 100 businesses: ~1-2 minutes
- 500 businesses: ~3-5 minutes
- 1000+ businesses: ~8-12 minutes

**Monitoring:**
- Watch n8n execution log for errors
- Check Supabase Dashboard → Logs for database issues
- Monitor `market_executions` table for statistics

---

## Troubleshooting

### "Column execution_id does not exist"

**Cause:** You didn't add `execution_id` to your Code node outputs

**Fix:**
1. Open each transformation Code node
2. Add this at the top:
   ```javascript
   const executionId = $('Store Execution ID').first().json.execution_id;
   ```
3. Add to return statement:
   ```javascript
   return items.map(item => ({
     json: {
       execution_id: executionId,  // ADD THIS
       // ... rest of fields
     }
   }));
   ```

### "Cannot read property 'json' of undefined" in Combine Business Data

**Cause:** One of your Code nodes didn't execute or has different name

**Fix:**
1. Check all upstream nodes completed successfully (green checkmarks)
2. Update node name references in `Combine Business Data` to match YOUR actual node names
3. Use optional chaining: `$('YourNode').all()[0]?.json || {}`

### "Unique constraint violation on apify_place_id"

**Cause:** You're re-running the same dataset (this is actually GOOD - upsert is working!)

**Fix:** This is expected behavior! The UPSERT will UPDATE existing businesses instead of failing.

### "Business_id not found" in Prepare Reviews

**Cause:** The business lookup is failing

**Fix:**
1. Verify `Upsert Business` node executed successfully
2. Check that it returned records with `id` field
3. Add debug logging to `Prepare Reviews`:
   ```javascript
   console.log('Business ID map:', businessIdMap);
   console.log('Looking for place_id:', placeId);
   ```

### "SSL connection error" to Supabase

**Cause:** SSL mode not configured correctly

**Fix:**
1. Open Postgres credential
2. Change SSL mode to `require`
3. Test connection again

### Workflow is Slow (> 10 minutes)

**Causes:**
- Processing too many businesses at once
- High network latency to Supabase
- Complex Code node transformations

**Fixes:**
1. Check Supabase region (use closest to your n8n instance)
2. Optimize Code nodes (remove console.logs in production)
3. Consider breaking into batches of 500 businesses
4. Enable connection pooling in Postgres credential

### "Query timeout" Errors

**Cause:** Large batch inserts taking too long

**Fix:**
1. Check if you have indexes from Issue #1 deployed
2. Reduce batch size in reviews insert
3. Increase timeout in n8n Settings → Executions → Timeout

---

## Architecture Notes

### Why JSONB?

Storing business data as JSONB instead of relational columns provides:

- **Flexibility:** Apify schema changes don't break your database
- **Simplicity:** No need for 8 separate dimension tables
- **Performance:** Postgres JSONB is indexed and fast
- **RAG-friendly:** AI agents can easily query semi-structured data

Generated columns give you "best of both worlds" - structured access to common fields while keeping raw data intact.

### Why UPSERT for Businesses?

The `apify_place_id` unique constraint + UPSERT pattern means:

- Re-running same search → Updates existing businesses (not duplicates)
- Running overlapping searches → Shared businesses only stored once
- Idempotent workflow → Safe to retry on failures

### Why Batch INSERT for Reviews?

Using `queryBatching: "transaction"` means:

- All 500 reviews inserted as single database transaction
- If one fails, all roll back (data consistency)
- 10-100x faster than individual inserts
- Atomic operation (all-or-nothing)

### Execution Tracking Benefits

The `market_executions` table provides:

- Audit trail of all workflow runs
- Statistics updated automatically via triggers
- Easy to compare runs ("Which search found most reviews?")
- Failure tracking (status = 'failed' if workflow errors)

---

## Next Steps

After successfully running this workflow:

1. ✅ **Verify data quality** - Spot check a few businesses in Supabase Studio
2. ✅ **Run full dataset** - Remove limit=10 and process all businesses
3. ✅ **Document any customizations** - Note your specific Code node names
4. ✅ **Set up monitoring** - Create Supabase dashboard for execution stats
5. ➡️ **Move to Issue #3** - Build the RAG Chat Interface to query this data

---

## Workflow Modification Tips

### Adding Custom Fields

To add fields to business_data JSONB:

1. Update your ETL Code nodes to include new fields
2. Update `Combine Business Data` to include in business_data object
3. No database migration needed! (JSONB is schema-less)
4. Optionally add generated column if you query it frequently:
   ```sql
   ALTER TABLE businesses
   ADD COLUMN your_field TEXT
   GENERATED ALWAYS AS (business_data->'dimension'->>'field') STORED;
   ```

### Adding Error Handling

To make workflow more robust:

1. Add **If** nodes after critical operations
2. Check for errors: `{{ $json.error }}`
3. Add **Slack** or **Email** notification nodes on failure
4. Update execution status to 'failed':
   ```sql
   UPDATE market_executions
   SET status = 'failed', notes = 'Error details...'
   WHERE id = ...
   ```

### Scheduling Automatic Runs

To run workflow on schedule:

1. Replace **Manual Trigger** with **Cron** or **Schedule Trigger** node
2. Set schedule (e.g., "Every Monday at 9am")
3. Update `Fetch Apify Data` to pull from recurring Actor runs
4. Consider adding deduplication logic for overlapping datasets

---

## Support Resources

- **n8n Postgres Node Docs:** https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.postgres/
- **Postgres JSONB Docs:** https://www.postgresql.org/docs/current/datatype-json.html
- **Supabase Studio:** https://supabase.com/docs/guides/platform/studio
- **Apify API Docs:** https://docs.apify.com/api/v2
- **n8n Community Forum:** https://community.n8n.io/

---

## Checklist: Workflow Ready for Production

- [ ] Postgres credential configured and tested
- [ ] Apify credential configured with valid token
- [ ] All placeholder credential IDs updated in nodes
- [ ] Dataset ID updated in Fetch Apify Data URL
- [ ] Existing ETL Code nodes connected
- [ ] All Code nodes modified with execution_id tracking
- [ ] Combine Business Data node references correct node names
- [ ] Test run with limit=10 completed successfully
- [ ] All 5 test queries pass
- [ ] Data visible in Supabase Studio
- [ ] Full dataset run completed (no limit)
- [ ] Execution times acceptable (< 15 minutes)
- [ ] Error handling considered
- [ ] Workflow saved and documented

---

**Questions?** Check Issue #2 on GitHub or review the building blocks in `workflows/building-blocks/`
