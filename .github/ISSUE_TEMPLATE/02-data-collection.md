---
name: 🔄 Data Collection Workflow
about: Build n8n workflow to collect Apify data and store in Postgres
title: "[WORKFLOW] Data Collection Pipeline"
labels: workflow, n8n, priority-high
assignees: ''
---

## 📋 Objective

Create the n8n workflow that fetches Google Maps business data from Apify and stores it in Postgres using JSONB columns. This **completely replaces** the Google Sheets-based pipeline and eliminates all JSON parsing nodes.

**Time estimate:** 2-3 hours
**Prerequisites:** Issue #1 completed (database ready), n8n instance, Apify account
**Dependencies:** Database schema must exist

---

## 🎯 What You're Building

**Input:** Apify Google Maps Scraper dataset
**Processing:** Your existing 31 Code nodes (keep these!)
**Output:** Postgres tables (businesses, reviews)

**Key changes from original workflow:**
- ❌ **Remove:** All 19 Google Sheets nodes
- ❌ **Remove:** All Parser nodes (Niche ID Parser, Opportunity Parser, etc.)
- ❌ **Remove:** All If nodes checking parsing success
- ❌ **Remove:** All Repair Code nodes
- ❌ **Remove:** All Basic LLM Chain nodes
- ❌ **Remove:** Final AI Agent (newsletter generation)
- ✅ **Add:** 6 Postgres nodes (replaces 19 Sheets nodes)
- ✅ **Keep:** All 31 Code transformation nodes
- ✅ **Keep:** All 29 Merge nodes

---

## 📝 Step-by-Step Implementation

### Step 1: Configure n8n Postgres Credential

In n8n:
1. Go to **Settings** → **Credentials** → **New**
2. Type: `Postgres`
3. Name: `Market Research DB`
4. Fill in from Issue #1:
   - Host: `db.[YOUR-PROJECT].supabase.co` (or localhost)
   - Database: `postgres`
   - User: `postgres`
   - Password: [Your password from Issue #1]
   - Port: `5432`
   - SSL: `enable` (for Supabase) or `disable` (local)
5. **Test Connection** → Should say "Connection successful"
6. Save

### Step 2: Start New Workflow

1. Create new workflow: "Market Research - Data Collection"
2. Add description: "Fetches Apify data and stores in Postgres with JSONB"

### Step 3: Add Manual Trigger

**Copy this JSON and paste as node:**

```json
{
  "parameters": {},
  "type": "n8n-nodes-base.manualTrigger",
  "typeVersion": 1,
  "position": [0, 0],
  "id": "manual-trigger-1",
  "name": "When clicking 'Execute workflow'"
}
```

### Step 4: Add HTTP Request (Apify)

**Keep your existing HTTP Request node** or use this template:

```json
{
  "parameters": {
    "url": "https://api.apify.com/v2/datasets/YOUR_DATASET_ID/items?token=YOUR_APIFY_TOKEN&limit=10",
    "options": {}
  },
  "type": "n8n-nodes-base.httpRequest",
  "typeVersion": 4.2,
  "position": [200, 0],
  "id": "http-request-apify",
  "name": "Fetch Apify Data"
}
```

**⚠️ Important:** Add `&limit=10` for testing! Remove later for full dataset.

### Step 5: Create Execution Tracking

**Node 1: Start Execution Record**

Copy and paste this Postgres node:

```json
{
  "parameters": {
    "operation": "insert",
    "schema": {
      "__rl": true,
      "mode": "list",
      "value": "public"
    },
    "table": {
      "__rl": true,
      "value": "market_executions",
      "mode": "list",
      "cachedResultName": "market_executions"
    },
    "columns": {
      "mappingMode": "defineBelow",
      "value": {
        "search_query": "={{ $json[0]?.searchString || 'Manual execution' }}",
        "apify_dataset_id": "=YOUR_DATASET_ID",
        "status": "running"
      }
    },
    "options": {
      "queryBatching": "off"
    }
  },
  "type": "n8n-nodes-base.postgres",
  "typeVersion": 2.5,
  "position": [400, 0],
  "id": "start-execution",
  "name": "Start Execution",
  "credentials": {
    "postgres": {
      "name": "Market Research DB"
    }
  }
}
```

**Node 2: Store Execution ID**

```json
{
  "parameters": {
    "assignments": {
      "assignments": [
        {
          "id": "execution-id",
          "name": "execution_id",
          "value": "={{ $json.id }}",
          "type": "number"
        }
      ]
    },
    "options": {}
  },
  "type": "n8n-nodes-base.set",
  "typeVersion": 3.4,
  "position": [600, 0],
  "id": "store-execution-id",
  "name": "Store Execution ID"
}
```

**Connect:** `Fetch Apify Data` → `Start Execution` → `Store Execution ID`

### Step 6: Keep Your Existing ETL Layer

**⚠️ IMPORTANT:** Do NOT replace your 31 Code nodes! They're doing good work.

**What to keep:**
- ✅ Overview Code node
- ✅ Contact Code node
- ✅ Social Code node
- ✅ Rating Code node
- ✅ Review Code node
- ✅ Lead enrichment Code node
- ✅ Tags Code node
- ✅ popularTimesHistogram Code node
- ✅ All 29 Merge nodes

**What to change in Code nodes:**

Add execution_id tracking to each Code node output. Example for Overview node:

```javascript
// At the top of each Code node, add:
const executionId = $('Store Execution ID').first().json.execution_id;

// Then in your return statement, add execution_id:
return items.map(item => {
  const d = item.json;

  return {
    json: {
      execution_id: executionId,  // ADD THIS LINE
      title: d.title || null,
      category: d.categoryName || null,
      // ... rest of your existing fields
    }
  };
});
```

**Apply this pattern to all transformation Code nodes.**

### Step 7: Combine Business Dimensions

After your existing ETL merges, add this Code node:

```javascript
// n8n Code node: Combine All Business Dimensions for Postgres
// This merges Overview, Contact, Social, Rating, PopularTimes into single JSONB object

const executionId = $('Store Execution ID').first().json.execution_id;

// Get data from your existing Code nodes
const overview = $('Overview').all()[0]?.json || {};
const contact = $('Contact').all()[0]?.json || {};
const social = $('Social').all()[0]?.json || {};
const rating = $('Rating').all()[0]?.json || {};
const popularTimes = $('popularTimesHistogram').all()[0]?.json || {};
const tags = $('Tags').all()[0]?.json || {};
const leadEnrichment = $('Lead enrichment').all()[0]?.json || {};

return [{
  json: {
    execution_id: executionId,
    business_name: overview.title || contact.title || 'Unknown',
    search_string: overview.searchString || popularTimes.searchString,
    apify_place_id: overview.url || contact.url || `${overview.title}-${Date.now()}`,

    // Single JSONB object with all dimensions
    business_data: {
      overview: overview,
      contact: contact,
      social: social,
      rating: rating,
      popular_times: popularTimes,
      tags: tags,
      lead_enrichment: leadEnrichment,
      scraped_at: new Date().toISOString()
    }
  }
}];
```

**Save as:** "Combine Business Data"

### Step 8: Upsert Business to Postgres

**Use the building block from [`workflows/building-blocks/postgres-upsert.json`](../../workflows/building-blocks/postgres-upsert.json)**

Copy the entire node and paste into your workflow. Update:
- Position: After "Combine Business Data"
- Credentials: Select "Market Research DB"

The node uses `matchingColumns: ["apify_place_id"]` which means:
- If place already exists → UPDATE
- If new → INSERT

This prevents duplicates when re-running searches.

**Connect:** `Combine Business Data` → `Upsert Business`

### Step 9: Prepare Reviews for Postgres

Your existing Review Code node flattens reviews. Modify it to add business reference:

```javascript
// n8n Code node: Prepare Reviews for Postgres Insert
// Flattens reviews from all places + adds business_id reference

const executionId = $('Store Execution ID').first().json.execution_id;
const results = [];

for (const place of items) {
  const p = place.json;

  // Get business_id from Upsert Business node
  const businessRecord = $('Upsert Business').all().find(b =>
    b.json.business_name === p.title ||
    b.json.apify_place_id === p.url
  );

  const businessId = businessRecord?.json.id;

  if (!businessId) {
    console.log(`Warning: No business_id found for ${p.title}`);
    continue;
  }

  // Ensure reviews exist
  if (Array.isArray(p.reviews) && p.reviews.length > 0) {
    for (const r of p.reviews) {
      results.push({
        json: {
          business_id: businessId,
          // Store entire review as JSONB
          review_data: JSON.stringify({
            placeName: p.title,
            reviewerId: r.reviewerId,
            reviewerUrl: r.reviewerUrl,
            reviewerName: r.name,
            reviewerNumberOfReviews: r.reviewerNumberOfReviews,
            isLocalGuide: r.isLocalGuide,
            stars: r.stars,
            text: r.text,
            textTranslated: r.textTranslated,
            publishAt: r.publishAt,
            publishedAtDate: r.publishedAtDate,
            likesCount: r.likesCount,
            reviewId: r.reviewId,
            reviewUrl: r.reviewUrl,
            reviewImageUrls: r.reviewImageUrls,
            responseFromOwnerDate: r.responseFromOwnerDate,
            responseFromOwnerText: r.responseFromOwnerText
          })
        }
      });
    }
  }
}

return results;
```

**Save as:** "Prepare Reviews for Insert"

### Step 10: Insert Reviews to Postgres

**Use the building block from [`workflows/building-blocks/postgres-insert-batch.json`](../../workflows/building-blocks/postgres-insert-batch.json)**

Key configuration:
- `queryBatching: "transaction"` → All reviews in single transaction
- If 500 reviews, all succeed or all fail (atomic)

**Connect:** `Prepare Reviews for Insert` → `Insert Reviews Batch`

### Step 11: Complete Execution

Final Postgres node to mark execution complete:

```json
{
  "parameters": {
    "operation": "update",
    "schema": {
      "__rl": true,
      "mode": "list",
      "value": "public"
    },
    "table": {
      "__rl": true,
      "value": "market_executions",
      "mode": "list"
    },
    "updateKey": "id",
    "columns": {
      "mappingMode": "defineBelow",
      "value": {
        "id": "={{ $('Store Execution ID').first().json.execution_id }}",
        "status": "completed",
        "completed_at": "={{ $now.toISO() }}"
      }
    }
  },
  "type": "n8n-nodes-base.postgres",
  "typeVersion": 2.5,
  "position": [2000, 0],
  "id": "complete-execution",
  "name": "Complete Execution",
  "credentials": {
    "postgres": {
      "name": "Market Research DB"
    }
  }
}
```

**Connect:** `Insert Reviews Batch` → `Complete Execution`

---

## 🏗️ Final Workflow Structure

```
Manual Trigger
  ↓
Fetch Apify Data (limit=10 for testing)
  ↓
Start Execution (INSERT market_executions)
  ↓
Store Execution ID (Set node)
  ↓
[Your existing 31 Code nodes - Overview, Contact, Social, etc.]
  ↓
[Your existing 29 Merge nodes]
  ↓
Combine Business Data (Code node)
  ↓
Upsert Business (Postgres UPSERT)
  ↓
Prepare Reviews for Insert (Code node)
  ↓
Insert Reviews Batch (Postgres INSERT with transaction)
  ↓
Complete Execution (UPDATE market_executions)
```

**Node count:** ~70 nodes (down from 106!)

---

## ✅ Testing Checklist

### Test 1: Verify Execution Tracking

```sql
-- Should show one execution
SELECT * FROM market_executions ORDER BY created_at DESC LIMIT 1;
```

Expected: One row with `status = 'completed'`, `total_businesses > 0`

### Test 2: Verify Business Data

```sql
-- Should show 10 businesses (from limit=10)
SELECT
  id,
  business_name,
  city,
  category,
  rating,
  review_count
FROM businesses
WHERE execution_id = (SELECT MAX(id) FROM market_executions);
```

Expected: 10 rows with actual data

### Test 3: Verify JSONB Structure

```sql
-- Check one business's full JSONB data
SELECT
  business_name,
  business_data->'overview'->>'city' as city,
  business_data->'rating'->>'totalScore' as rating,
  business_data->'contact'->>'phone' as phone,
  business_data->'social'->>'instagrams' as instagram
FROM businesses
LIMIT 1;
```

Expected: All fields populated from JSONB

### Test 4: Verify Reviews

```sql
-- Should show reviews linked to businesses
SELECT
  b.business_name,
  r.reviewer_name,
  r.stars,
  r.review_text
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
LIMIT 10;
```

Expected: 10+ reviews with text

### Test 5: Full-Text Search

```sql
-- Test full-text search on reviews
SELECT
  b.business_name,
  r.review_text,
  r.stars
FROM business_reviews r
JOIN businesses b ON b.id = r.business_id
WHERE to_tsvector('english', r.review_text) @@ to_tsquery('parking | location')
LIMIT 5;
```

Expected: Reviews mentioning "parking" or "location"

---

## ✅ Acceptance Criteria

- [ ] Postgres credential configured in n8n
- [ ] Manual trigger added
- [ ] Apify HTTP request working (test with limit=10)
- [ ] Execution tracking nodes added (Start + Store ID + Complete)
- [ ] All 31 existing Code nodes kept and updated with execution_id
- [ ] "Combine Business Data" Code node added
- [ ] Postgres Upsert Business node working
- [ ] "Prepare Reviews" Code node added
- [ ] Postgres Insert Reviews working
- [ ] All 5 test queries pass
- [ ] Workflow executes end-to-end without errors
- [ ] Data visible in Supabase Studio

---

## 🐛 Troubleshooting

**"Column execution_id does not exist"**
- You forgot to add execution_id to your Code node outputs
- Go back to Step 6 and add it to ALL transformation nodes

**"Cannot read property 'json' of undefined" in Combine Business Data**
- One of your Code nodes didn't execute
- Check that all upstream nodes completed successfully
- Use `?.` optional chaining: `$('Overview').all()[0]?.json || {}`

**"Unique constraint violation on apify_place_id"**
- This is GOOD! It means upsert is working
- Same business won't be inserted twice

**"Business_id not found" in Prepare Reviews**
- The business lookup is failing
- Debug: Add `console.log(businessRecord)` to see what's returned
- Verify `Upsert Business` node executed before Review preparation

**"SSL connection error" to Supabase**
- In n8n Postgres credential, set SSL mode to `require` or `prefer`
- Or use connection string with `?sslmode=require`

**Workflow is slow (> 5 minutes)**
- Check if you removed `&limit=10` from Apify URL
- Processing 500 businesses takes 2-3 minutes (normal)
- If slower, check Supabase region (high latency?)

---

## 📚 Additional Resources

- [n8n Postgres Node Docs](https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.postgres/)
- [Postgres UPSERT (ON CONFLICT)](https://www.postgresql.org/docs/current/sql-insert.html#SQL-ON-CONFLICT)
- [JSONB in Postgres](https://www.postgresql.org/docs/current/datatype-json.html)
- [n8n Expression Resolution](https://docs.n8n.io/code-examples/expressions/)

---

## 🔄 Next Steps

After completing this issue:
- ✅ Mark this issue as complete
- ✅ Run workflow with full dataset (remove `limit=10`)
- ➡️ Move to **Issue #3: RAG Chat Interface** to build the AI assistant that queries this data
