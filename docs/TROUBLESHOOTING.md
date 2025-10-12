# Troubleshooting Guide - Market Research RAG System

Common issues and solutions for the Market Research RAG system, compiled from implementation experience and testing.

---

## Table of Contents

- [Database Issues](#database-issues)
- [Data Collection Workflow Issues](#data-collection-workflow-issues)
- [RAG Chat Interface Issues](#rag-chat-interface-issues)
- [AI Tool Execution Issues](#ai-tool-execution-issues)
- [Performance Issues](#performance-issues)
- [n8n Workflow Issues](#n8n-workflow-issues)
- [Credentials and Authentication](#credentials-and-authentication)
- [Data Quality Issues](#data-quality-issues)

---

## Database Issues

### Issue: "relation 'businesses' does not exist"

**Symptom:** Queries fail with "relation does not exist" error.

**Cause:** Database schema not created.

**Solution:**
```bash
# Run schema creation scripts in order
psql "YOUR_POSTGRES_URL" -f schema/01-tables.sql
psql "YOUR_POSTGRES_URL" -f schema/02-indexes.sql
```

**Verification:**
```sql
\dt  -- List all tables
-- Should show: market_executions, businesses, business_reviews
```

---

### Issue: Slow Queries (> 10 seconds)

**Symptom:** Database queries take longer than expected, AI responses are slow.

**Cause:** Missing indexes or indexes not being used.

**Solution:**

1. **Verify indexes exist:**
```sql
SELECT tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```

2. **Check if indexes are being used:**
```sql
EXPLAIN ANALYZE
SELECT business_name, city, rating
FROM businesses
WHERE city = 'Phoenix' AND rating > 4.5;
```

Look for "Index Scan" in output. If you see "Seq Scan", indexes aren't being used.

3. **Recreate indexes:**
```bash
psql "YOUR_POSTGRES_URL" -f schema/02-indexes.sql
```

4. **Update statistics:**
```sql
ANALYZE businesses;
ANALYZE business_reviews;
ANALYZE market_executions;
```

**Prevention:**
- Run `ANALYZE` after inserting large datasets
- Monitor query performance with `EXPLAIN ANALYZE`

---

### Issue: "permission denied for table businesses"

**Symptom:** Queries fail with permission denied errors.

**Cause:** Postgres user doesn't have required permissions.

**Solution:**
```sql
-- Grant all permissions to your user
GRANT ALL ON ALL TABLES IN SCHEMA public TO your_username;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO your_username;

-- Grant execute on functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO your_username;
```

**For Supabase:**
- Usually not an issue as Supabase auto-manages permissions
- If using service role key, ensure it's configured in n8n credentials

---

### Issue: Generated Columns Not Updating

**Symptom:** `city`, `category`, `rating` columns are NULL despite JSONB data existing.

**Cause:** Generated columns are computed at INSERT time. If you update `business_data` JSONB directly, generated columns don't automatically update.

**Solution:**

1. **For new inserts:** Generated columns will populate automatically.

2. **For updates:** Force regeneration by updating the row:
```sql
UPDATE businesses
SET business_data = business_data
WHERE city IS NULL AND business_data->'overview'->>'city' IS NOT NULL;
```

3. **Verify:**
```sql
SELECT
  business_name,
  city,
  business_data->'overview'->>'city' as city_from_json,
  city = business_data->'overview'->>'city' as match
FROM businesses
LIMIT 5;
```

---

### Issue: Duplicate Businesses on Re-run

**Symptom:** Running data collection workflow multiple times creates duplicate businesses.

**Cause:** `apify_place_id` is NULL or not being set correctly.

**Solution:**

1. **Check if place_id is being captured:**
```sql
SELECT business_name, apify_place_id
FROM businesses
WHERE apify_place_id IS NULL
LIMIT 10;
```

2. **Ensure Apify data includes place_id:**
- In n8n data collection workflow, verify Apify response contains `placeId` field
- Map `placeId` to `apify_place_id` column in INSERT statement

3. **Use UPSERT for deduplication:**
```sql
INSERT INTO businesses (execution_id, business_name, apify_place_id, business_data)
VALUES ($1, $2, $3, $4)
ON CONFLICT (apify_place_id)
DO UPDATE SET
  business_data = EXCLUDED.business_data,
  updated_at = NOW();
```

---

## Data Collection Workflow Issues

### Issue: Workflow Fails with "Invalid JSON"

**Symptom:** n8n workflow execution fails with JSON parsing errors.

**Cause:** Apify response structure changed or unexpected data format.

**Solution:**

1. **Check Apify raw output:**
   - In n8n, click on the Apify node
   - View "Output" tab
   - Inspect JSON structure

2. **Add error handling:**
   - Add "If" node after Apify to check for valid data
   - Use "Error Trigger" to catch and log failures

3. **Use JSONB safely:**
   - JSONB columns accept variable schemas
   - Don't assume fields exist - use null checks:
   ```sql
   business_data->'social'->>'instagrams'  -- Returns NULL if path doesn't exist
   ```

---

### Issue: "Execution marked as 'failed' but no error message"

**Symptom:** n8n shows workflow execution failed, but no clear error.

**Cause:** Silent failure in a node or timeout.

**Solution:**

1. **Check node-by-node:**
   - Click each node in failed execution
   - Look for red error indicators
   - Check "Output" and "Input" tabs

2. **Common culprits:**
   - **Postgres node:** Connection timeout or invalid SQL
   - **Code node:** JavaScript error not caught
   - **Apify node:** API rate limit or quota exceeded

3. **Add explicit error handling:**
```javascript
// In Code node
try {
  // Your logic
  return items;
} catch (error) {
  console.error('Error:', error);
  throw new Error(`Custom error message: ${error.message}`);
}
```

4. **Enable workflow error notifications:**
   - Add "Error Trigger" node
   - Connect to Slack/Email notification
   - Include execution details in message

---

### Issue: Apify Returns 0 Results

**Symptom:** Workflow completes but no businesses inserted.

**Cause:** Invalid Apify search URL or search returned no results.

**Solution:**

1. **Test Apify URL directly:**
   - Copy Apify Actor run URL
   - Open in browser
   - Check dataset preview

2. **Common Apify issues:**
   - **Location not found:** "restaurants in Atlantis" returns 0 results
   - **maxCrawledPlacesPerSearch = 0:** Check URL parameter
   - **API quota exceeded:** Check Apify account usage

3. **Add validation in workflow:**
```javascript
// After Apify node, add Code node to check results
if (!items || items.length === 0) {
  throw new Error('Apify returned 0 results. Check search parameters.');
}
return items;
```

---

### Issue: Reviews Not Linking to Businesses

**Symptom:** Reviews inserted but `business_id` is NULL or incorrect.

**Cause:** Foreign key relationship broken or ID mismatch.

**Solution:**

1. **Verify business was inserted and get ID:**
```sql
SELECT id, business_name, apify_place_id
FROM businesses
WHERE business_name = 'Expected Business Name';
```

2. **Check n8n workflow:**
   - Ensure business INSERT returns the `id`
   - Use `RETURNING id` in Postgres INSERT
   - Pass `id` to review INSERT nodes

3. **Fix orphaned reviews:**
```sql
-- Find reviews without valid business_id
SELECT COUNT(*) FROM business_reviews
WHERE NOT EXISTS (
  SELECT 1 FROM businesses WHERE id = business_reviews.business_id
);

-- Delete orphaned reviews (if appropriate)
DELETE FROM business_reviews
WHERE NOT EXISTS (
  SELECT 1 FROM businesses WHERE id = business_reviews.business_id
);
```

---

## RAG Chat Interface Issues

### Issue: Chat Interface Doesn't Load

**Symptom:** Opening webhook URL shows blank page or 404 error.

**Cause:** Workflow not activated or incorrect webhook URL.

**Solution:**

1. **Check workflow activation:**
   - Open "Market Research - RAG Chat" workflow
   - Toggle switch in top-right must be ON (blue)

2. **Verify webhook URL:**
   - Click "When chat message received" node (Chat Trigger)
   - Copy "Test URL" or "Production URL"
   - URL format: `https://your-n8n.com/webhook/chat-xxxxx`

3. **Test webhook manually:**
```bash
curl -X POST "YOUR_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"action": "sendMessage", "sessionId": "test123", "chatInput": "Hello"}'
```

Expected: JSON response with AI message.

4. **Check n8n logs:**
   - In n8n UI, go to Executions
   - Filter by workflow name
   - Look for recent failed executions

---

### Issue: AI Doesn't Respond

**Symptom:** Chat interface loads, but AI doesn't reply to messages.

**Cause:** OpenAI credential invalid, model configuration issue, or workflow error.

**Solution:**

1. **Test OpenAI credential:**
   - n8n → Credentials → OpenAI
   - Click "Test" button
   - Should show "Connection successful"

2. **Check OpenAI API key:**
   - Verify key starts with `sk-proj-...` or `sk-...`
   - Check API key has credits (https://platform.openai.com/usage)
   - Ensure no rate limits exceeded

3. **Verify AI Agent configuration:**
   - Open AI Agent node
   - Check connections:
     - `ai_languageModel` → OpenAI Chat Model
     - `ai_memory` → Postgres Chat Memory
     - `ai_tool` → (3 Postgres Tool nodes)

4. **Test without tools:**
   - Temporarily disconnect all tool nodes
   - Test if AI responds to simple "Hello"
   - If works, reconnect tools one by one to find issue

---

### Issue: Memory Doesn't Work (AI Forgets Context)

**Symptom:** AI doesn't remember previous messages in the conversation.

**Cause:** Postgres Chat Memory not configured or sessionId not being passed.

**Solution:**

1. **Verify Postgres Chat Memory node:**
   - Connection string correct
   - Table name: `n8n_chat_histories` (or your chosen name)
   - sessionId parameter: `={{ $json.sessionId }}`

2. **Check sessionId flow:**
   - Chat Trigger generates sessionId
   - AI Agent receives sessionId
   - Memory node uses same sessionId

3. **Test memory manually:**
```sql
-- Check if chat history is being stored
SELECT * FROM n8n_chat_histories
ORDER BY created_at DESC
LIMIT 10;
```

4. **Create memory table if missing:**
```sql
CREATE TABLE IF NOT EXISTS n8n_chat_histories (
    id SERIAL PRIMARY KEY,
    session_id TEXT NOT NULL,
    message TEXT NOT NULL,
    role TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_chat_histories_session ON n8n_chat_histories(session_id);
```

---

### Issue: AI Responds with "I don't have access to data"

**Symptom:** AI says it can't access database despite tools being configured.

**Cause:** Tools not connected to AI Agent via `ai_tool` port.

**Solution:**

1. **Visual check in n8n:**
   - AI Agent node should have 5 incoming connections:
     - 1 from OpenAI Chat Model (ai_languageModel)
     - 1 from Postgres Chat Memory (ai_memory)
     - 3 from Postgres Tool nodes (ai_tool)

2. **Reconnect tools:**
   - Drag from each Postgres Tool node's output
   - Connect to AI Agent's `ai_tool` input port
   - You should see multiple `ai_tool` ports (n8n creates them dynamically)

3. **Test tool execution:**
   - Ask: "Show me 3 businesses"
   - In n8n Execution view, check if Postgres Tool node executed
   - If not, tool isn't connected or AI didn't choose to use it

4. **Improve tool descriptions:**
   - AI chooses tools based on `toolDescription`
   - Make descriptions clear about when to use each tool
   - Include example queries in description

---

## AI Tool Execution Issues

### Issue: AI Writes Invalid SQL

**Symptom:** Tool execution fails with SQL syntax errors.

**Cause:** AI generated malformed SQL query.

**Solution:**

1. **Check error message:**
   - In n8n execution view, click failed Postgres Tool node
   - Read SQL error message
   - Common issues:
     - Missing quotes around strings
     - Incorrect column names
     - Invalid JSONB syntax

2. **Improve tool description:**
   - Add more SQL examples to `toolDescription`
   - Show correct syntax for JSONB queries
   - Emphasize table and column names

3. **Add SQL validation (optional):**
```javascript
// In Code node before Postgres Tool
const sql = $fromAI('sql_query');

// Basic validation
if (!sql.toLowerCase().includes('select')) {
  throw new Error('Query must be a SELECT statement');
}

if (sql.toLowerCase().includes('drop') || sql.toLowerCase().includes('delete')) {
  throw new Error('DROP and DELETE not allowed');
}

return [{ json: { sql } }];
```

4. **Use system prompt guidance:**
   - In AI Agent, add to system prompt:
   ```
   When writing SQL:
   - Always use SELECT (never DROP or DELETE)
   - Always include LIMIT to prevent overwhelming output
   - Use proper JSONB operators (-> for JSON, ->> for text)
   - Always join business_reviews with businesses to show business_name
   ```

---

### Issue: AI Hallucinations (Makes Up Data)

**Symptom:** AI provides data that doesn't exist in database.

**Cause:** LLM filling gaps with plausible-sounding information.

**Solution:**

1. **Strengthen system prompt:**
```
CRITICAL: You are connected to a real database. You must ONLY use data returned from your tools.

If a query returns 0 results, say "I found 0 results" - NEVER make up data.
If you don't know something, say "I don't have that information in the database."

Always cite your sources: "According to the database..." or "The query returned..."
```

2. **Test with empty results:**
   - Ask: "Show me businesses in Atlantis"
   - AI should say "I found 0 businesses in Atlantis"
   - If AI makes up businesses, update system prompt

3. **Use structured output:**
   - In tool descriptions, specify expected output format
   - Example: "Return JSON with {count: X, businesses: [...], source: 'database query'}"

---

### Issue: Full-Text Search Not Finding Relevant Results

**Symptom:** Searching for keyword in reviews returns 0 or wrong results.

**Cause:** Full-text search syntax incorrect or stemming issues.

**Solution:**

1. **Verify index exists:**
```sql
SELECT indexname FROM pg_indexes
WHERE indexname = 'idx_reviews_text_fts';
```

2. **Test full-text search manually:**
```sql
-- Basic search
SELECT review_text
FROM business_reviews
WHERE to_tsvector('english', review_text) @@ to_tsquery('english', 'parking')
LIMIT 5;

-- If returns 0, try:
SELECT review_text
FROM business_reviews
WHERE review_text ILIKE '%parking%'
LIMIT 5;
```

3. **Common full-text search issues:**
   - **Stemming:** "parking" matches "park", "parked", "parks"
   - **Stop words:** "the", "a", "is" are ignored
   - **Case-sensitive:** Use 'english' configuration for case-insensitive

4. **Improve search query:**
```sql
-- Use OR for variations
to_tsquery('english', 'parking | parked | parks')

-- Use AND for multiple terms
to_tsquery('english', 'parking & problem')

-- Use prefix search
to_tsquery('english', 'park:*')
```

5. **Update tool description:**
```
Full-text search examples:
- Single keyword: to_tsquery('parking')
- Multiple keywords (OR): to_tsquery('parking | lot')
- Multiple keywords (AND): to_tsquery('parking & problem')
- Prefix search: to_tsquery('park:*')
```

---

## Performance Issues

### Issue: High Database Connection Count

**Symptom:** Supabase shows many active connections, potential connection limit errors.

**Cause:** n8n not closing database connections properly.

**Solution:**

1. **Use connection pooling:**
   - In Postgres credentials, use connection pooling URL (if available)
   - Supabase provides pooled connection URLs

2. **Check for connection leaks:**
```sql
SELECT COUNT(*) as connection_count, state
FROM pg_stat_activity
WHERE datname = 'your_database_name'
GROUP BY state;
```

3. **Close connections in n8n:**
   - Postgres nodes should auto-close
   - If using custom Code nodes with pg library, ensure `client.end()`

---

### Issue: OpenAI Rate Limits

**Symptom:** Chat responses fail with "Rate limit exceeded" error.

**Cause:** Too many requests to OpenAI API.

**Solution:**

1. **Check OpenAI usage:**
   - Visit https://platform.openai.com/usage
   - View rate limits and current usage

2. **Reduce token usage:**
   - Limit system prompt length
   - Add `LIMIT` to all SQL queries (default to 10-20 rows)
   - Truncate large JSONB fields in SELECT

3. **Upgrade OpenAI tier:**
   - Tier 1: 500 RPM, 200,000 TPM
   - Tier 2+: Higher limits
   - Pay-as-you-go scales with usage

4. **Add retry logic in n8n:**
   - Use "Error Trigger" → "Wait" → "Resume Workflow"
   - Exponential backoff: 1s, 2s, 4s, 8s

---

## n8n Workflow Issues

### Issue: Workflow Execution Takes Too Long

**Symptom:** n8n execution times out or takes 10+ minutes.

**Cause:** Processing too much data sequentially.

**Solution:**

1. **Use batching:**
   - Process businesses in batches of 10-50
   - Use "Split In Batches" node

2. **Parallelize where possible:**
   - Use "Execute Workflow" node for parallel processing
   - Process reviews in separate workflow

3. **Add timeouts:**
   - Set explicit timeouts on HTTP Request and Apify nodes
   - Fail fast rather than hanging

---

### Issue: n8n Workflow Import Fails

**Symptom:** Can't import workflow JSON into n8n.

**Cause:** JSON format error or credential references.

**Solution:**

1. **Validate JSON:**
```bash
cat workflow.json | jq .
# Should output formatted JSON, no errors
```

2. **Remove credential references:**
   - Open JSON in text editor
   - Search for `"credentials": {`
   - Replace with empty object or remove property

3. **Import step-by-step:**
   - Instead of importing full workflow
   - Recreate by following building blocks in docs

---

## Credentials and Authentication

### Issue: "Invalid API Key" from OpenAI

**Symptom:** AI doesn't respond, error mentions API key invalid.

**Solution:**

1. **Check API key format:**
   - Should start with `sk-proj-` (project key) or `sk-` (legacy)
   - No extra spaces or quotes

2. **Test key directly:**
```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"
```

Expected: List of available models.

3. **Regenerate key:**
   - Go to https://platform.openai.com/api-keys
   - Create new key
   - Update in n8n credentials

---

### Issue: Postgres Connection String Invalid

**Symptom:** "could not connect to server" error.

**Solution:**

1. **Check connection string format:**
```
postgresql://username:password@host:port/database

# Supabase example:
postgresql://postgres.xxxxx:password@aws-0-us-west-1.pooler.supabase.com:5432/postgres
```

2. **Common issues:**
   - Missing password (special characters need URL encoding)
   - Wrong port (5432 for direct, 6543 for pooler)
   - SSL required but not specified

3. **Test connection:**
```bash
psql "YOUR_CONNECTION_STRING" -c "SELECT 1;"
# Should return 1
```

---

## Data Quality Issues

### Issue: Businesses Have Missing JSONB Fields

**Symptom:** Some businesses missing city, category, or social media data.

**Cause:** Apify data varies by business - not all have all fields.

**Solution:**

1. **Use safe JSONB access:**
```sql
-- Returns NULL if path doesn't exist (safe)
business_data->'social'->>'instagrams'

-- Check for existence before using
WHERE business_data->'social' ? 'instagrams'
```

2. **Add data validation in workflow:**
```javascript
// In Code node after Apify
items.forEach(item => {
  // Ensure required fields exist
  if (!item.json.overview) {
    item.json.overview = {};
  }
  if (!item.json.overview.city) {
    item.json.overview.city = 'Unknown';
  }
});
return items;
```

3. **Query only complete records:**
```sql
SELECT * FROM businesses
WHERE business_data->'overview'->>'city' IS NOT NULL
  AND business_data->'contact'->>'phone' IS NOT NULL;
```

---

### Issue: Review Text Contains Special Characters

**Symptom:** Reviews display with weird characters (�) or encoding issues.

**Cause:** UTF-8 encoding not handled properly.

**Solution:**

1. **Check database encoding:**
```sql
SHOW SERVER_ENCODING;
-- Should be UTF8
```

2. **In n8n Code node:**
```javascript
// Ensure UTF-8 encoding
const cleanText = Buffer.from(text, 'utf-8').toString('utf-8');
```

3. **For display in chat:**
   - Most modern systems handle UTF-8 automatically
   - If issues persist, strip non-ASCII:
   ```javascript
   const asciiOnly = text.replace(/[^\x00-\x7F]/g, '');
   ```

---

## Getting Additional Help

### Documentation Resources

- **n8n Docs:** https://docs.n8n.io/
- **Postgres Docs:** https://www.postgresql.org/docs/
- **Supabase Docs:** https://supabase.com/docs
- **OpenAI API Docs:** https://platform.openai.com/docs

### Community Support

- **n8n Community Forum:** https://community.n8n.io/
- **GitHub Issues:** https://github.com/abjohnson5f/market-research-rag/issues

### Debugging Tips

1. **Enable verbose logging:**
   - n8n: Set `N8N_LOG_LEVEL=debug` in environment
   - Postgres: Enable query logging in Supabase dashboard

2. **Test in isolation:**
   - Test each component separately
   - Database queries in SQL editor
   - AI prompts in OpenAI playground
   - n8n nodes one at a time

3. **Use test data:**
   - Insert controlled test data: `psql "URL" -f schema/test-data.sql`
   - Test with known inputs/outputs
   - Clean up: `psql "URL" -f schema/test-data.sql --variable=CLEANUP=true`

4. **Monitor execution:**
   - Watch n8n execution logs in real-time
   - Check database query logs in Supabase
   - Monitor OpenAI usage dashboard

---

## Quick Reference: Common Commands

```bash
# Database
psql "YOUR_URL" -c "SELECT COUNT(*) FROM businesses;"
psql "YOUR_URL" -f schema/run-tests.sql

# Test data
psql "YOUR_URL" -f schema/test-data.sql
psql "YOUR_URL" -f schema/test-data.sql --variable=CLEANUP=true

# n8n
n8n start  # Start n8n locally
n8n export:workflow --id=123 --output=workflow.json

# OpenAI
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"
```

---

**Still having issues?** Create a GitHub issue with:
1. Exact error message
2. Steps to reproduce
3. n8n workflow JSON (remove credentials first)
4. Relevant database query results
