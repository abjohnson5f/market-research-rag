---
name: 🔧 Postgres Tool Nodes
about: Give AI Agent database access via SQL tools (Cole Medin pattern)
title: "[TOOLS] Postgres Query Tools for AI"
labels: workflow, n8n, ai-tools, priority-critical
assignees: ''
---

## 📋 Objective

Create Postgres Tool nodes that give your AI Agent the ability to query the database directly. This is **the magic that makes RAG work** - the AI writes SQL queries dynamically based on your questions, executes them, and formats the results in natural language.

**Time estimate:** 1-2 hours
**Prerequisites:** Issue #3 completed (RAG chat interface working)
**Pattern source:** Cole Medin's `postgresTool` nodes from RAG template

---

## 🎯 What You're Building

**The Power of Postgres Tools:**

Without tools (Issue #3 state):
```
You: "Show me businesses in Phoenix"
AI: "I have access to business data but cannot query it directly."
```

With tools (after this issue):
```
You: "Show me businesses in Phoenix"
AI: [Thinks: I should use query_businesses tool with SQL query]
    [Executes: SELECT business_name, rating FROM businesses WHERE city = 'Phoenix']
    [Gets: 47 rows]
    "I found 47 businesses in Phoenix! Here are the top 5 by rating:
     1. Desert Coffee Co - 4.9 (127 reviews)
     2. Phoenix Auto Detail - 4.8 (89 reviews)
     ..."
```

**You'll create 3 tools:**
1. **query_businesses** - Find businesses by any criteria
2. **query_reviews** - Search customer reviews with full-text search
3. **analyze_opportunities** - Run complex analytical queries

---

## 📝 Step-by-Step Implementation

### Step 1: Open Your RAG Chat Workflow

From Issue #3:
- Open "Market Research - RAG Chat" workflow
- You should see: Chat Trigger → AI Agent → OpenAI Model + Memory

### Step 2: Add Tool #1 - Query Businesses

**This is the most-used tool. Copy this EXACTLY:**

```json
{
  "parameters": {
    "descriptionType": "manual",
    "toolDescription": "Use this tool to search for businesses in the database. You can filter by city, category, rating, review count, or query the business_data JSONB column for any field.\n\nTable schema:\n- business_name (TEXT) - Name of the business\n- city (TEXT) - City location (e.g. 'Phoenix', 'Seattle')\n- category (TEXT) - Business type (e.g. 'Coffee Shop', 'Auto Repair')\n- rating (DECIMAL) - Average rating from Google Maps (1.0 to 5.0)\n- review_count (INT) - Total number of reviews\n- website (TEXT) - Business website URL\n- phone (TEXT) - Contact phone number\n- business_data (JSONB) - Full business details with nested structure\n\nJSONB structure (access with -> and ->> operators):\n- business_data->'overview' - Contains city, category, rating fields\n- business_data->'contact' - Phone, website, address, emails, lat/lng\n- business_data->'social' - Instagram, Facebook, LinkedIn, TikTok URLs\n- business_data->'rating' - totalScore, reviewsCount, distribution, tags\n- business_data->'popular_times' - Traffic histogram by day/hour\n- business_data->'tags' - Array of tags from reviews and categories\n\nExample queries:\n\nFind businesses in specific city:\nSELECT business_name, category, rating, review_count FROM businesses WHERE city = 'Phoenix' ORDER BY rating DESC LIMIT 10;\n\nFind high-rated with low reviews (underserved):\nSELECT business_name, city, rating, review_count FROM businesses WHERE rating > 4.5 AND review_count < 30 ORDER BY rating DESC;\n\nFind businesses with Instagram:\nSELECT business_name, city, business_data->'social'->>'instagrams' as instagram FROM businesses WHERE business_data->'social' ? 'instagrams' AND business_data->'social'->>'instagrams' != '';\n\nCategory analysis:\nSELECT category, COUNT(*) as count, ROUND(AVG(rating), 2) as avg_rating, SUM(review_count) as total_reviews FROM businesses WHERE city = 'Phoenix' GROUP BY category HAVING COUNT(*) > 3 ORDER BY total_reviews DESC;\n\nALWAYS include business_name in your SELECT. Use ORDER BY and LIMIT to keep results manageable. Return maximum 50 rows unless specifically asked for more.",
    "operation": "executeQuery",
    "query": "={{ $fromAI('sql_query') }}",
    "options": {}
  },
  "type": "n8n-nodes-base.postgresTool",
  "typeVersion": 2.5,
  "position": [200, 200],
  "id": "query-businesses-tool",
  "name": "Query Businesses Tool",
  "credentials": {
    "postgres": {
      "name": "Market Research DB"
    }
  }
}
```

**Key components explained:**

1. **`toolDescription`**: This is what the AI sees. It's like teaching the AI how to use the tool.
   - Schema documentation (what columns exist)
   - JSONB structure (how to access nested data)
   - Example queries (teaching the AI SQL patterns)

2. **`query: "={{ $fromAI('sql_query') }}"`**: This magical line means:
   - AI writes SQL in its reasoning
   - n8n extracts the SQL from AI's thought process
   - Executes it against Postgres
   - Returns results to AI

3. **`postgresTool` type**: Special node that:
   - Connects to AI Agent's `ai_tool` port
   - Validates SQL (prevents DROP/DELETE)
   - Handles result formatting

**Connect:** Drag from "Query Businesses Tool" → "Market Research AI Agent" (ai_tool port - you'll see multiple ports)

### Step 3: Add Tool #2 - Query Reviews

**For analyzing customer sentiment and finding patterns:**

```json
{
  "parameters": {
    "descriptionType": "manual",
    "toolDescription": "Use this tool to search and analyze customer reviews. Supports full-text search for finding reviews mentioning specific keywords or themes.\n\nTable schema:\n- business_id (INT) - Foreign key to businesses table\n- reviewer_name (TEXT) - Name of reviewer\n- stars (INT) - Rating given (1-5)\n- review_text (TEXT) - Full review content (full-text searchable)\n- published_at (DATE) - When review was posted\n- review_data (JSONB) - Complete review object\n\nCommon query patterns:\n\nFind reviews mentioning keyword (full-text search):\nSELECT b.business_name, r.review_text, r.stars FROM business_reviews r JOIN businesses b ON b.id = r.business_id WHERE to_tsvector('english', r.review_text) @@ to_tsquery('parking & problem') ORDER BY r.stars LIMIT 20;\n\nFind negative reviews for specific business:\nSELECT reviewer_name, stars, review_text, published_at FROM business_reviews WHERE business_id = (SELECT id FROM businesses WHERE business_name ILIKE '%business name%') AND stars <= 2 ORDER BY published_at DESC;\n\nReview sentiment analysis by category:\nSELECT b.category, AVG(r.stars) as avg_stars, COUNT(r.id) as review_count, COUNT(CASE WHEN r.stars <= 2 THEN 1 END) as negative_reviews FROM business_reviews r JOIN businesses b ON b.id = r.business_id WHERE b.city = 'Phoenix' GROUP BY b.category ORDER BY negative_reviews DESC;\n\nFind common complaint themes:\nSELECT b.business_name, COUNT(*) as complaint_count, string_agg(r.review_text, ' | ') as sample_complaints FROM business_reviews r JOIN businesses b ON b.id = r.business_id WHERE r.stars <= 2 AND r.review_text ILIKE '%your keyword%' GROUP BY b.business_name HAVING COUNT(*) > 3;\n\nFull-text search operators:\n- & = AND (both words must appear)\n- | = OR (either word)\n- ! = NOT (exclude word)\n- <-> = words must be adjacent\n\nExample: to_tsquery('coffee & (bad | terrible) & !service') finds reviews with \"coffee\" AND (\"bad\" OR \"terrible\") but NOT \"service\"\n\nALWAYS join with businesses table to get business_name for context. Limit results to 20-50 for readability.",
    "operation": "executeQuery",
    "query": "={{ $fromAI('sql_query') }}",
    "options": {}
  },
  "type": "n8n-nodes-base.postgresTool",
  "typeVersion": 2.5,
  "position": [200, 400],
  "id": "query-reviews-tool",
  "name": "Query Reviews Tool",
  "credentials": {
    "postgres": {
      "name": "Market Research DB"
    }
  }
}
```

**What makes this powerful:**

- **Full-text search**: `to_tsvector` and `to_tsquery` are Postgres's built-in text search
- **Pattern recognition**: AI can find recurring themes across reviews
- **Sentiment analysis**: Group by stars to identify positive vs negative patterns

**Connect:** Drag from "Query Reviews Tool" → "Market Research AI Agent" (another ai_tool port)

### Step 4: Add Tool #3 - Analyze Opportunities

**For complex analytical queries (newsletter ideas, market gaps):**

```json
{
  "parameters": {
    "descriptionType": "manual",
    "toolDescription": "Use this tool for complex analytical queries to identify market opportunities, trends, and newsletter ideas. This tool is for aggregations, statistical analysis, and multi-table joins.\n\nUse cases:\n1. Find underserved markets (high demand, low supply)\n2. Identify businesses with engagement gaps (high reviews but low social presence)\n3. Discover newsletter opportunities (categories with trust issues)\n4. Analyze competitive landscapes\n\nExample analytical queries:\n\nUnderserved opportunities (high rating, low competition):\nSELECT city, category, COUNT(*) as business_count, ROUND(AVG(rating), 2) as avg_rating, SUM(review_count) as total_reviews FROM businesses WHERE rating > 4.5 GROUP BY city, category HAVING COUNT(*) < 5 AND SUM(review_count) > 100 ORDER BY total_reviews DESC;\n\nCategories with trust issues (many reviews, low ratings):\nSELECT category, COUNT(*) as business_count, ROUND(AVG(rating), 2) as avg_rating, SUM(review_count) as total_reviews FROM businesses GROUP BY category HAVING AVG(rating) < 4.0 AND SUM(review_count) > 500 ORDER BY avg_rating ASC;\n\nSocial media engagement gaps:\nSELECT b.business_name, b.city, b.rating, b.review_count, CASE WHEN b.business_data->'social' ? 'instagrams' THEN 'Yes' ELSE 'No' END as has_instagram FROM businesses b WHERE b.rating > 4.5 AND b.review_count > 50 AND (b.business_data->'social'->>'instagrams' IS NULL OR b.business_data->'social'->>'instagrams' = '') ORDER BY b.review_count DESC LIMIT 20;\n\nNewsletter opportunity analysis:\nWITH category_stats AS (SELECT b.category, COUNT(*) as biz_count, AVG(b.rating) as avg_rating, COUNT(r.id) FILTER (WHERE r.stars <= 2) as negative_reviews, COUNT(r.id) as total_stored_reviews FROM businesses b LEFT JOIN business_reviews r ON r.business_id = b.id GROUP BY b.category) SELECT category, biz_count, ROUND(avg_rating, 2) as avg_rating, negative_reviews, ROUND(100.0 * negative_reviews / NULLIF(total_stored_reviews, 0), 1) as negative_pct FROM category_stats WHERE biz_count > 5 ORDER BY negative_pct DESC LIMIT 10;\n\nTime-based trends (if you have multiple executions):\nSELECT e.search_query, e.created_at::date as execution_date, COUNT(b.id) as businesses_found, AVG(b.rating) as avg_rating FROM market_executions e JOIN businesses b ON b.execution_id = e.id GROUP BY e.search_query, e.created_at::date ORDER BY e.created_at DESC;\n\nUse CTEs (WITH clauses) for complex multi-step analysis. Always provide context with your results (don't just return numbers, explain what they mean for newsletter opportunities or market insights).",
    "operation": "executeQuery",
    "query": "={{ $fromAI('sql_query') }}",
    "options": {}
  },
  "type": "n8n-nodes-base.postgresTool",
  "typeVersion": 2.5,
  "position": [200, 600],
  "id": "analyze-opportunities-tool",
  "name": "Analyze Opportunities Tool",
  "credentials": {
    "postgres": {
      "name": "Market Research DB"
    }
  }
}
```

**Why separate this from query_businesses:**

- Different use case (analysis vs lookup)
- More complex SQL (CTEs, window functions, statistical aggregations)
- AI knows to use this for "find opportunities" vs "show me businesses"
- Encourages the AI to think analytically

**Connect:** Drag from "Analyze Opportunities Tool" → "Market Research AI Agent" (third ai_tool port)

### Step 5: Verify Tool Connections

Your AI Agent should now have:
- `ai_languageModel` → OpenAI Chat Model
- `ai_memory` → Postgres Chat Memory
- `ai_tool` → Query Businesses Tool
- `ai_tool` → Query Reviews Tool
- `ai_tool` → Analyze Opportunities Tool

**Visual check:** The AI Agent node should have 5 lines coming into it.

### Step 6: Save and Activate

1. **Save workflow** (Ctrl/Cmd + S)
2. **Activate workflow** (toggle in top right)
3. **Copy webhook URL** from Chat Trigger node

---

## ✅ Testing the Tools

### Test 1: Basic Business Query

**Question:** "Show me the top 5 businesses in Phoenix by rating"

**Expected AI behavior:**
1. AI chooses `query_businesses` tool
2. Writes SQL: `SELECT business_name, rating, review_count FROM businesses WHERE city = 'Phoenix' ORDER BY rating DESC LIMIT 5`
3. Executes query
4. Formats results in natural language

**Expected response:**
```
Here are the top 5 businesses in Phoenix by rating:

1. [Business Name] - 4.9 stars (127 reviews)
2. [Business Name] - 4.8 stars (89 reviews)
3. [Business Name] - 4.7 stars (156 reviews)
4. [Business Name] - 4.7 stars (94 reviews)
5. [Business Name] - 4.6 stars (203 reviews)

Would you like more details about any of these businesses?
```

### Test 2: Review Analysis

**Question:** "What are customers saying about parking in Phoenix restaurants?"

**Expected AI behavior:**
1. Chooses `query_reviews` tool
2. Writes SQL: `SELECT b.business_name, r.review_text, r.stars FROM business_reviews r JOIN businesses b ON b.id = r.business_id WHERE b.city = 'Phoenix' AND b.category ILIKE '%restaurant%' AND to_tsvector('english', r.review_text) @@ to_tsquery('parking') LIMIT 20`
3. Analyzes patterns in results

**Expected response:**
```
I analyzed 18 reviews from Phoenix restaurants mentioning parking. Here's what customers are saying:

Positive:
- 8 reviews praised "ample parking" or "easy parking"
- Valet service mentioned positively 3 times

Negative:
- 6 reviews complained about lack of parking
- 2 mentioned parking lot safety concerns
- 1 complained about paid parking

Most mentioned: Downtown restaurants have parking issues, suburban locations praised for easy access.

Newsletter angle: "Phoenix Restaurant Parking Guide - Where to Actually Find a Spot"
```

### Test 3: Opportunity Analysis

**Question:** "What are the best newsletter opportunities in this data?"

**Expected AI behavior:**
1. Chooses `analyze_opportunities` tool
2. Writes complex query with aggregations
3. Identifies patterns (categories with low ratings but high review volume = people searching for recommendations)

**Expected response:**
```
Based on the data, I found 3 strong newsletter opportunities:

1. **Auto Repair in Phoenix** (Highest potential)
   - 52 businesses, avg rating 3.9 (below market average)
   - 6,234 total reviews (high engagement = people searching)
   - 34% of reviews mention "overcharging" or "unnecessary repairs"
   - Newsletter: "Phoenix Auto Honesty Report - Who to Trust"

2. **Home Services** (Good potential)
   - 87 businesses, avg 4.3 rating (quality concerns)
   - 12,453 reviews (very high engagement)
   - Common complaints: Communication issues, pricing surprises
   - Newsletter: "Phoenix Home Pros - Transparent Recommendations"

3. **Pet Services** (Emerging opportunity)
   - Only 23 businesses, avg 4.6 rating (underserved market)
   - 1,842 reviews (demand exists but limited supply)
   - High ratings suggest quality is good, need is unmet
   - Newsletter: "Phoenix Pet Care Insider"

Want me to dive deeper into any of these categories?
```

### Test 4: Follow-up Questions (Memory Test)

**Conversation:**
```
You: "Show me auto repair shops in Phoenix"
AI: [Shows list of 52 shops]

You: "Which of these have the worst reviews?"
AI: [Remembers context of "these" = Phoenix auto repair shops]
    [Queries reviews for those specific businesses]
    [Shows bottom 5 by rating with complaint themes]

You: "What's the most common complaint?"
AI: [Remembers we're talking about bottom-rated auto shops]
    [Analyzes reviews for patterns]
    "Overcharging is the most common complaint (34% of negative reviews)"
```

**This tests:**
- Memory (remembers context)
- Tool chaining (uses businesses query, then reviews query)
- Contextual understanding ("these", "the most common")

---

## 🐛 Troubleshooting

**"AI says 'I cannot execute queries'"**
- Tools aren't connected properly
- Check that ai_tool port connections are visible in the workflow
- Try disconnecting and reconnecting tool nodes

**"AI returns SQL syntax errors"**
- This is normal initially - the AI is learning your schema
- The system prompt has examples, but it may need guidance
- Try being more specific: "Use the query_businesses tool to SELECT business_name, city FROM businesses WHERE city = 'Phoenix'"
- If persistent, upgrade to gpt-4o (better at SQL)

**"AI uses wrong tool for the question"**
- Tool descriptions might be unclear
- Make descriptions more distinct
- Example: If AI uses query_reviews when it should use query_businesses, emphasize in query_businesses description: "Use this tool for finding and filtering businesses by attributes"

**"Results are truncated at 50 rows"**
- This is intentional (see LIMIT clauses in examples)
- To get more: "Show me ALL businesses in Phoenix" (AI should increase LIMIT)
- For very large results, ask AI to aggregate: "How many businesses in each category in Phoenix?" instead of listing all

**"AI doesn't use JSONB queries"**
- It needs examples in the conversation
- Ask: "Show me businesses with Instagram accounts" or "Which businesses have popular times data?"
- The AI will see the JSONB operators in the tool description and start using them

**"Tool returns 'relation does not exist'"**
- Typo in table name (should be `businesses`, `business_reviews`, `market_executions`)
- Or database schema from Issue #1 didn't run correctly
- Verify: `SELECT * FROM businesses LIMIT 1;` in Supabase SQL editor

**"Performance is slow (> 10 seconds per query)"**
- Check if indexes from Issue #1 (`02-indexes.sql`) are created
- Run: `SELECT indexname FROM pg_indexes WHERE tablename = 'businesses';`
- Should see ~10 indexes
- If missing: Run `schema/02-indexes.sql`

---

## ✅ Acceptance Criteria

- [ ] All 3 Postgres Tool nodes added to workflow
- [ ] Each tool connected to AI Agent (5 total connections to agent)
- [ ] Test 1 passes (basic business query works)
- [ ] Test 2 passes (review analysis works)
- [ ] Test 3 passes (opportunity analysis works)
- [ ] Test 4 passes (follow-up questions use memory)
- [ ] AI writes valid SQL queries
- [ ] Results are formatted naturally (not just raw data dumps)
- [ ] No SQL injection possible (tools only allow SELECT)

---

## 🎓 How This Works (Under the Hood)

**The AI's decision process:**

1. **User asks question:** "Find businesses in Phoenix"

2. **AI reads available tools:**
   - query_businesses (description mentions city filtering)
   - query_reviews (description mentions review analysis)
   - analyze_opportunities (description mentions aggregations)

3. **AI chooses tool:** `query_businesses` (best fit for city filtering)

4. **AI generates SQL in reasoning:**
   ```
   I should use the query_businesses tool to find businesses in Phoenix.
   I'll write a SQL query: SELECT business_name, category, rating
   FROM businesses WHERE city = 'Phoenix' ORDER BY rating DESC LIMIT 10
   ```

5. **n8n extracts SQL:** The `$fromAI('sql_query')` expression pulls the SQL from AI's thoughts

6. **Postgres executes:** Query runs against your database

7. **Results return to AI:** JSON array of rows

8. **AI formats response:**
   ```
   I found 47 businesses in Phoenix. Here are the top 10 by rating:
   1. Coffee Shop - 4.9
   2. Auto Repair - 4.8
   ...
   ```

**Security note:** The `postgresTool` node type only allows `SELECT` queries. AI cannot:
- DROP tables
- DELETE data
- UPDATE records
- INSERT records

It's read-only by design.

---

## 📚 Additional Resources

- [Postgres Tool Node Docs](https://docs.n8n.io/integrations/builtin/cluster-nodes/sub-nodes/n8n-nodes-langchain.toolpostgres/)
- [Postgres Full-Text Search](https://www.postgresql.org/docs/current/textsearch.html)
- [JSONB Operators](https://www.postgresql.org/docs/current/functions-json.html)
- [SQL Window Functions](https://www.postgresql.org/docs/current/tutorial-window.html)

---

## 🔄 Next Steps

After completing this issue:
- ✅ Mark this issue as complete
- ✅ Test extensively with various questions
- ✅ Document any SQL patterns the AI struggles with
- ➡️ Move to **Issue #5: Testing & Validation** for comprehensive system testing
- 🎉 **Your RAG system is now fully functional!** The AI can query your data and answer questions.
