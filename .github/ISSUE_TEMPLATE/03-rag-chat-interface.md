---
name: 💬 RAG Chat Interface
about: Build AI chat assistant for market analysis (Cole Medin pattern)
title: "[WORKFLOW] RAG Chat Interface"
labels: workflow, n8n, ai, priority-high
assignees: ''
---

## 📋 Objective

Create the RAG (Retrieval-Augmented Generation) chat interface that lets you ask questions about your market research data in natural language. This **completely replaces manual Google Sheets analysis** with an AI assistant powered by your Postgres database.

**Time estimate:** 2 hours
**Prerequisites:** Issue #1 and #2 completed (database + data collection working)
**Pattern source:** Cole Medin's RAG AI Agent Template V5

---

## 🎯 What You're Building

**Instead of:**
- ❌ Opening Google Sheets
- ❌ Manually filtering/sorting data
- ❌ Creating pivot tables
- ❌ Copy-pasting into ChatGPT

**You get:**
- ✅ Chat interface in n8n
- ✅ AI writes SQL queries dynamically
- ✅ Natural language questions → Structured answers
- ✅ Conversation memory (multi-turn discussions)

**Example conversations:**
```
You: "What businesses did we find in Phoenix?"
AI: "I found 47 businesses in Phoenix. The top categories are:
     - Home Services (12 businesses, avg 4.3 rating)
     - Restaurants (18 businesses, avg 4.1 rating)
     - Auto Repair (8 businesses, avg 3.9 rating)
     Would you like details on any category?"

You: "Show me auto repair shops with low ratings"
AI: [Executes: SELECT business_name, rating, review_count FROM businesses
     WHERE city = 'Phoenix' AND category ILIKE '%auto%' AND rating < 4.0]
     "Here are 3 auto repair shops with ratings below 4.0:
     1. Quick Fix Auto - 3.7 (89 reviews)
     2. Joe's Garage - 3.5 (42 reviews)
     3. Budget Auto - 3.2 (156 reviews)
     Want me to analyze their negative reviews?"

You: "Yes, what are customers complaining about?"
AI: [Executes: SELECT review_text FROM business_reviews WHERE business_id IN (...) AND stars <= 2]
     "Common complaints across these shops:
     - Overcharging (mentioned in 34% of negative reviews)
     - Unnecessary repairs recommended (28%)
     - Poor communication (22%)
     This is a newsletter opportunity: 'Phoenix Auto Honesty Report'"
```

---

## 📝 Step-by-Step Implementation

### Step 1: Configure OpenAI Credential

In n8n:
1. **Settings** → **Credentials** → **New**
2. Type: `OpenAI`
3. Name: `OpenAI Market Research`
4. API Key: Your OpenAI key (get from [platform.openai.com](https://platform.openai.com/api-keys))
5. **Test Connection** → Should succeed
6. Save

### Step 2: Create New Workflow

1. New workflow: "Market Research - RAG Chat"
2. Description: "AI chat assistant for analyzing market research data using RAG"

### Step 3: Add Chat Trigger

**Copy Cole's chat trigger pattern:**

```json
{
  "parameters": {
    "public": true,
    "options": {
      "loadPreviousSession": true
    }
  },
  "type": "@n8n/n8n-nodes-langchain.chatTrigger",
  "typeVersion": 1.1,
  "position": [0, 0],
  "id": "chat-trigger-1",
  "name": "When chat message received",
  "webhookId": "WILL_BE_AUTO_GENERATED"
}
```

**Important:** After adding this node:
1. Save workflow
2. Click the node
3. Copy the "Test URL" - you'll use this to chat!

### Step 4: Add AI Agent

**This is the brain - copy Cole's pattern with our custom system prompt:**

```json
{
  "parameters": {
    "promptType": "define",
    "text": "={{ $json.chatInput }}",
    "options": {
      "systemMessage": "You are a market research analyst assistant with access to local business data from Google Maps (scraped via Apify).\n\nYour knowledge base contains:\n- Business profiles (name, location, category, ratings, contact info, social media)\n- Customer reviews with full text and ratings\n- Popular times and traffic patterns\n- Data stored in Postgres with JSONB columns\n\nAvailable tools:\n1. query_businesses - Search/filter businesses by city, category, rating, review count, or any JSONB field\n2. query_reviews - Analyze customer reviews for sentiment, keywords, patterns\n3. analyze_opportunities - Identify underserved markets, high-potential niches\n\nJSON structure you're querying:\n- businesses.business_data contains: overview, contact, social, rating, popular_times, tags\n- Use JSONB operators: ->, ->>, @>, ?, ?&, ?| for nested queries\n- Generated columns available: city, category, rating, review_count\n\nALWAYS:\n- Write SQL queries yourself - you have full query capabilities\n- Cite specific business names and numbers in your answers\n- Identify patterns across multiple businesses\n- Quantify opportunities (X businesses, avg Y rating, Z reviews)\n- When analyzing reviews, look for recurring themes\n- If no data found, say so clearly (don't make things up)\n\nNEVER:\n- Fabricate data\n- Ignore low-rated businesses (they reveal market gaps)\n- Give generic advice without data backing\n\nExample queries you can write:\n- Find opportunities: SELECT * FROM businesses WHERE rating > 4.5 AND review_count < 20\n- Category analysis: SELECT category, COUNT(*), AVG(rating) FROM businesses GROUP BY category\n- Review search: SELECT b.business_name, r.review_text FROM business_reviews r JOIN businesses b ON b.id = r.business_id WHERE to_tsvector('english', r.review_text) @@ to_tsquery('parking')\n- JSONB queries: SELECT business_name FROM businesses WHERE business_data->'social' ? 'instagrams'\n\nYou're here to help discover newsletter opportunities, market gaps, and customer insights."
    }
  },
  "type": "@n8n/n8n-nodes-langchain.agent",
  "typeVersion": 1.6,
  "position": [400, 0],
  "id": "rag-ai-agent",
  "name": "Market Research AI Agent"
}
```

**Key differences from Cole's template:**
- System prompt is market-research specific (not document analysis)
- Teaches agent about JSONB structure
- Gives examples of SQL queries it can write
- Emphasizes quantification and pattern recognition

### Step 5: Add OpenAI Chat Model

**Connect to AI Agent:**

```json
{
  "parameters": {
    "model": "gpt-4o-mini",
    "options": {
      "temperature": 0.3
    }
  },
  "type": "@n8n/n8n-nodes-langchain.lmChatOpenAi",
  "typeVersion": 1,
  "position": [400, 200],
  "id": "openai-chat-model",
  "name": "OpenAI Chat Model",
  "credentials": {
    "openAiApi": {
      "name": "OpenAI Market Research"
    }
  }
}
```

**Why GPT-4o-mini:**
- Cheap ($0.15/1M input tokens vs $2.50 for GPT-4)
- Fast (< 2 second responses)
- Good at SQL generation
- **Upgrade to GPT-4o if:** Agent makes SQL mistakes or needs better reasoning

**Temperature 0.3:**
- Lower = more consistent SQL queries
- Higher = more creative newsletter ideas
- Adjust based on use case

**Connect:** Drag from "OpenAI Chat Model" → "Market Research AI Agent" (ai_languageModel port)

### Step 6: Add Postgres Chat Memory (Cole's Pattern)

**This enables multi-turn conversations:**

```json
{
  "parameters": {
    "sessionIdType": "customKey",
    "sessionKey": "={{ $json.sessionId }}",
    "contextWindowLength": 10
  },
  "type": "@n8n/n8n-nodes-langchain.memoryPostgresChat",
  "typeVersion": 1,
  "position": [400, 400],
  "id": "postgres-chat-memory",
  "name": "Postgres Chat Memory",
  "credentials": {
    "postgres": {
      "name": "Market Research DB"
    }
  }
}
```

**What this does:**
- Stores conversation history in Postgres
- Agent remembers context from previous messages
- Enables follow-up questions: "Show me more" or "What about Phoenix?"
- `contextWindowLength: 10` = remembers last 10 messages

**First time setup:**
The memory node auto-creates a table: `n8n_chat_histories`

**Connect:** Drag from "Postgres Chat Memory" → "Market Research AI Agent" (ai_memory port)

### Step 7: Add Postgres Tool Nodes

**These are how the AI queries your data. You'll create 3 tools in Issue #4, but here's where they connect:**

From Issue #4, you'll add:
1. **Query Businesses Tool** (basic SELECT queries)
2. **Query Reviews Tool** (full-text search)
3. **Analyze Opportunities Tool** (complex aggregations)

Each tool connects: Tool node → AI Agent (ai_tool port)

**Placeholder for now:** We'll add these in Issue #4

**Connect structure:**
```
Market Research AI Agent
  ├─ ai_languageModel → OpenAI Chat Model
  ├─ ai_memory → Postgres Chat Memory
  ├─ ai_tool → Query Businesses Tool (Issue #4)
  ├─ ai_tool → Query Reviews Tool (Issue #4)
  └─ ai_tool → Analyze Opportunities Tool (Issue #4)
```

### Step 8: Test Basic Chat (Without Tools)

**Before adding tools, test basic chat:**

1. Save workflow
2. Click "When chat message received" node
3. Copy "Production URL" (looks like: `https://your-n8n.com/webhook/abc-123`)
4. Open in browser
5. You should see n8n chat interface

**Test messages:**
```
You: "Hello! What can you help me with?"
AI: [Should respond with its capabilities]

You: "What data do you have access to?"
AI: [Should describe businesses and reviews tables]
```

**If this works, you have basic chat working!** The AI just can't query data yet (that's Issue #4).

---

## 🎨 Chat Interface Customization (Optional)

### Option 1: n8n Native Chat (Default)

The `chatTrigger` node creates a simple chat UI at the webhook URL.

**Pros:** Immediate, no setup
**Cons:** Basic styling, no auth

### Option 2: Embed in Your App

Use the webhook as API:

```javascript
// POST to webhook URL
fetch('https://your-n8n.com/webhook/abc-123', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    chatInput: "What businesses did we find in Phoenix?",
    sessionId: "user-123"  // Unique per user for memory
  })
})
.then(res => res.json())
.then(data => {
  console.log(data.output);  // AI response
});
```

### Option 3: Slack Integration

Replace `chatTrigger` with Slack trigger (Cole has examples for this).

---

## ✅ Testing Checklist

### Test 1: Chat Interface Loads

- [ ] Webhook URL opens in browser
- [ ] Chat interface appears
- [ ] Can type and send messages

### Test 2: AI Responds

Send: "Hello, what can you help me with?"

Expected: AI describes its market research capabilities

### Test 3: Memory Works

```
Message 1: "My name is Alex"
Message 2: "What's my name?"
```

Expected: AI responds "Alex" (proving it remembers context)

### Test 4: System Prompt Is Active

Send: "What database are you connected to?"

Expected: AI mentions "Postgres", "businesses table", "reviews", "JSONB"

### Test 5: New Session Isolation

- Open chat in incognito window (new sessionId)
- Send: "What's my name?"
- Expected: AI doesn't know (new session = no memory of "Alex")

---

## 🐛 Troubleshooting

**"Webhook URL returns 404"**
- Did you save the workflow after adding chat trigger?
- Is the workflow **activated** (toggle in top right)?
- Copy the URL from the node settings (don't type it manually)

**"AI doesn't remember previous messages"**
- Check that `sessionId` is consistent
- In n8n chat UI, sessionId is auto-generated per browser session
- If using API, pass the same sessionId for the user

**"Table n8n_chat_histories does not exist"**
- The memory node creates this automatically on first message
- If error persists, create manually:
  ```sql
  CREATE TABLE n8n_chat_histories (
    session_id TEXT,
    message_id TEXT PRIMARY KEY,
    role TEXT,
    content TEXT,
    created_at TIMESTAMP DEFAULT NOW()
  );
  ```

**"AI responses are slow (> 10 seconds)"**
- This is normal for first message (initializes memory)
- Subsequent messages should be < 2 seconds
- If always slow: Check OpenAI API status or switch to gpt-3.5-turbo

**"AI gives generic answers, doesn't reference tools"**
- Tools aren't connected yet (that's Issue #4)
- For now, AI only has system knowledge, no data access
- This is expected behavior until Issue #4

---

## ✅ Acceptance Criteria

- [ ] OpenAI credential configured
- [ ] Chat trigger node added and webhook URL works
- [ ] AI Agent node with custom system prompt
- [ ] OpenAI Chat Model connected to agent
- [ ] Postgres Chat Memory connected to agent
- [ ] Chat interface loads in browser
- [ ] AI responds to messages
- [ ] Memory persists across conversation
- [ ] System prompt is being used (AI knows it's market research focused)
- [ ] Placeholders for tool connections ready (3 ai_tool ports)

---

## 📚 Additional Resources

- [n8n Chat Trigger Docs](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.chattrigger/)
- [n8n AI Agent Docs](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/)
- [OpenAI Models Comparison](https://platform.openai.com/docs/models)
- [Cole Medin's n8n Tutorials](https://www.youtube.com/@ColeMedin)

---

## 🔄 Next Steps

After completing this issue:
- ✅ Mark this issue as complete
- ✅ Test basic chat functionality
- ➡️ Move to **Issue #4: Postgres Tool Nodes** to give the AI actual data access
- This is where it gets powerful - the AI will write SQL queries on the fly!
