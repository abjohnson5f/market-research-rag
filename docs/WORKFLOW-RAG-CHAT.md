# RAG Chat Interface - Setup Guide

**Pattern:** Cole Medin's RAG AI Agent Template V5
**Model:** GPT-4o-mini (fast & cost-effective)
**Database:** Postgres with chat memory persistence
**Purpose:** Natural language interface for market research data

---

## Quick Start

### 1. Import Workflow

1. Open n8n
2. Click **Workflows** → **Import from File**
3. Select `workflows/02-rag-chat-interface.json`
4. Click **Import**

### 2. Configure Credentials

**OpenAI Credential:**
1. **Settings** → **Credentials** → **New**
2. Type: `OpenAI`
3. Name: `OpenAI Market Research` (must match workflow)
4. API Key: Get from [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
5. **Test Connection** → Should succeed
6. Save

**Postgres Credential:**
1. Should already exist from Issue #1 as `Market Research DB`
2. If not, create with connection string from Neon/Supabase
3. Ensure name matches workflow: `Market Research DB`

### 3. Activate Workflow

1. Toggle **Active** in top right (turns green)
2. Click **When chat message received** node
3. Copy **Production URL** (looks like: `https://your-n8n.com/webhook-test/market-research-chat`)
4. Open URL in browser → Chat interface should load

### 4. First Test

**Message:** "Hello! What can you help me with?"

**Expected Response:**
```
I'm a market research analyst assistant. I can help you analyze local business
data from Google Maps, including:

- Finding businesses by location, category, or rating
- Analyzing customer reviews for patterns and sentiment
- Identifying market opportunities and gaps
- Comparing businesses within a category
- Suggesting newsletter topics based on data

I have access to business profiles, reviews, ratings, contact info, and more.
What would you like to explore?
```

**If you see this, basic chat is working!** The AI can't query data yet (that's Issue #4).

---

## Architecture Overview

### Flow Diagram

```
User Browser
    ↓
When chat message received (Chat Trigger)
    ↓
Edit Fields (Extract chatInput + sessionId)
    ↓
Market Research AI Agent
    ├─ OpenAI Chat Model (gpt-4o-mini, temp 0.3)
    ├─ Postgres Chat Memory (10 message context)
    └─ [Tool placeholders - added in Issue #4]
        ├─ Query Businesses Tool
        ├─ Query Reviews Tool
        └─ Analyze Opportunities Tool
    ↓
Respond to Webhook
    ↓
User Browser (displays response)
```

### Node Details

#### 1. When chat message received (Chat Trigger)
- **Type:** `@n8n/n8n-nodes-langchain.chatTrigger`
- **Purpose:** Creates public chat interface at webhook URL
- **Config:**
  - `public: true` - No authentication required
  - `loadPreviousSession: true` - Restores conversation history
- **Webhook ID:** `market-research-chat`

#### 2. Edit Fields
- **Type:** `n8n-nodes-base.set`
- **Purpose:** Normalizes input format (handles both chat UI and API calls)
- **Extracts:**
  - `chatInput`: User's message
  - `sessionId`: Unique conversation identifier

#### 3. Market Research AI Agent
- **Type:** `@n8n/n8n-nodes-langchain.agent`
- **Purpose:** Core reasoning engine - interprets user intent and decides which tools to use
- **System Prompt:** See [System Prompt Customization](#system-prompt-customization) below
- **Connections:**
  - **ai_languageModel** → OpenAI Chat Model
  - **ai_memory** → Postgres Chat Memory
  - **ai_tool** → [3 tools added in Issue #4]

#### 4. OpenAI Chat Model
- **Type:** `@n8n/n8n-nodes-langchain.lmChatOpenAi`
- **Model:** `gpt-4o-mini`
  - Cost: $0.15/1M input tokens (80% cheaper than GPT-4)
  - Speed: <2 second responses
  - Good at: SQL generation, structured reasoning
- **Temperature:** `0.3`
  - Lower = more consistent/deterministic
  - Good for SQL queries and factual responses
  - Increase to 0.7 for more creative newsletter ideas

#### 5. Postgres Chat Memory
- **Type:** `@n8n/n8n-nodes-langchain.memoryPostgresChat`
- **Purpose:** Stores conversation history for context
- **Config:**
  - `sessionKey`: `{{ $json.sessionId }}` - Unique per user
  - `contextWindowLength`: 10 - Remembers last 10 messages
- **Auto-creates table:** `n8n_chat_histories`

#### 6. Respond to Webhook
- **Type:** `n8n-nodes-base.respondToWebhook`
- **Purpose:** Sends AI response back to user

---

## System Prompt Customization

### Current Prompt (Market Research Focused)

Located in **Market Research AI Agent** node → `options.systemMessage`

**Key sections:**

1. **Persona Definition**
   ```
   You are a market research analyst assistant with access to
   local business data from Google Maps (scraped via Apify).
   ```

2. **Knowledge Base Description**
   - Business profiles structure
   - Review data format
   - JSONB schema explanation

3. **Available Tools**
   - Lists 3 tools (query_businesses, query_reviews, analyze_opportunities)
   - Describes when to use each

4. **JSON Structure Examples**
   - Shows JSONB operators: `->`, `->>`, `@>`, `?`, `?&`, `?|`
   - Generated columns: city, category, rating, review_count

5. **Behavior Rules (ALWAYS/NEVER)**
   - ALWAYS: Cite sources, quantify, identify patterns
   - NEVER: Fabricate data, ignore low-rated businesses

6. **Example Queries**
   - Real SQL queries the agent can write
   - Demonstrates JSONB, full-text search, aggregations

### How to Customize

**Example: Focus on newsletter opportunities**

Add to "ALWAYS" section:
```
- When analyzing data, always suggest 3 potential newsletter angles
- Prioritize controversial/surprising findings
- Look for businesses with strong social media but low ratings (authenticity gaps)
```

**Example: Add specific city context**

Add after "Knowledge base" section:
```
Current focus cities: Phoenix, Scottsdale, Tempe, Gilbert
Population data: Phoenix (1.6M), Scottsdale (250K), Tempe (190K), Gilbert (260K)
Use population to calculate per-capita business density when analyzing opportunities.
```

**Example: Change tone**

Replace persona:
```
You are Kyle Johnson's AI assistant for BrandFontsIQ market research.
Kyle is writing The Good Business newsletter - focus on stories that
make readers say "I didn't know that!" Be conversational but data-driven.
```

### Testing Prompt Changes

After editing system prompt:

1. Save workflow
2. Deactivate → Reactivate (refreshes prompt)
3. Start new chat session (new browser/incognito)
4. Test with: "What's your role?" (should reflect new prompt)

---

## Testing the Chat Interface

### Test 1: Basic Conversation

**Message:** "What can you help me with?"

**Expected:** AI describes market research capabilities

**Pass criteria:** Response mentions businesses, reviews, opportunities

---

### Test 2: Memory Persistence

**Message 1:** "My name is Alex"
**Message 2:** "What's my name?"

**Expected:** AI responds "Alex"

**Pass criteria:** AI remembers from previous message

---

### Test 3: Session Isolation

1. Open chat in **normal browser** → Say "My name is Alex"
2. Open chat in **incognito window** → Ask "What's my name?"

**Expected:** AI says it doesn't know (different sessionId)

**Pass criteria:** Conversations don't leak between sessions

---

### Test 4: System Prompt Active

**Message:** "What database are you connected to?"

**Expected:** AI mentions:
- Postgres
- businesses table
- reviews table
- JSONB columns

**Pass criteria:** Response shows agent knows its data structure

---

### Test 5: Tool Awareness (Before Issue #4)

**Message:** "Show me restaurants in Phoenix"

**Expected:** AI says it has the capability but tools aren't connected yet

**Example response:**
```
I can help you find restaurants in Phoenix, but I need my database tools
to be connected first. Once the query_businesses tool is active (Issue #4),
I'll be able to search for restaurants by location, filter by rating,
and analyze their reviews.
```

**Pass criteria:** AI understands its future capabilities

---

## Model Selection Guide

### When to Use GPT-4o-mini (Default)

✅ **Use for:**
- General questions about data
- Basic SQL queries (SELECT, WHERE, JOIN)
- Review sentiment analysis
- Category comparisons
- Cost-sensitive applications

**Performance:**
- Cost: $0.15 / 1M input tokens
- Speed: 1-2 seconds per response
- Accuracy: 95% for structured queries

---

### When to Upgrade to GPT-4o

⚠️ **Upgrade if:**
- SQL queries have syntax errors
- Agent struggles with complex joins (3+ tables)
- Need more creative newsletter ideas
- Multi-step reasoning required
- Better understanding of ambiguous questions

**Performance:**
- Cost: $2.50 / 1M input tokens (17x more expensive)
- Speed: 2-4 seconds per response
- Accuracy: 99%+ for complex queries

**How to upgrade:**
1. Edit **OpenAI Chat Model** node
2. Change `model`: `"gpt-4o-mini"` → `"gpt-4o"`
3. Save and reactivate workflow

---

### When to Upgrade to GPT-4 (Full)

🚀 **Only if:**
- GPT-4o still makes mistakes
- Need maximum reasoning capability
- Cost is not a concern

**Performance:**
- Cost: $30 / 1M input tokens (200x more expensive)
- Speed: 5-10 seconds per response
- Use cases: Complex research tasks, publication-quality analysis

---

## Using as API (Non-Browser)

### JavaScript Example

```javascript
// POST to webhook URL
const response = await fetch('https://your-n8n.com/webhook-test/market-research-chat', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    chatInput: "What restaurants in Phoenix have over 100 reviews?",
    sessionId: "user-alex-123"  // Unique per user for memory
  })
});

const data = await response.json();
console.log(data.output);  // AI response
```

### Python Example

```python
import requests

response = requests.post(
    'https://your-n8n.com/webhook-test/market-research-chat',
    json={
        'chatInput': 'Show me auto repair shops with low ratings in Scottsdale',
        'sessionId': 'user-alex-123'
    }
)

print(response.json()['output'])
```

### cURL Example

```bash
curl -X POST https://your-n8n.com/webhook-test/market-research-chat \
  -H "Content-Type: application/json" \
  -d '{
    "chatInput": "What are common complaints in Phoenix restaurant reviews?",
    "sessionId": "user-alex-123"
  }'
```

**Important:** Use the same `sessionId` for a user's entire conversation to maintain context.

---

## Troubleshooting

### "Webhook URL returns 404"

**Cause:** Workflow not activated or webhook ID mismatch

**Fix:**
1. Check workflow is **Active** (green toggle)
2. Save workflow after adding chat trigger (generates webhook)
3. Copy URL from node settings (don't type manually)
4. Try deactivate → reactivate

---

### "AI doesn't remember previous messages"

**Cause:** Session ID not consistent

**Fix:**
1. If using browser chat: Each browser/tab = unique session (this is correct)
2. If using API: Pass the same `sessionId` for the user
3. Check Postgres connection: `SELECT * FROM n8n_chat_histories LIMIT 5;`

---

### "Table n8n_chat_histories does not exist"

**Cause:** Memory node hasn't initialized

**Fix:**
1. Send one message through chat (creates table automatically)
2. If error persists, create manually:

```sql
CREATE TABLE n8n_chat_histories (
  session_id TEXT,
  message_id TEXT PRIMARY KEY,
  role TEXT,  -- 'user' or 'assistant'
  content TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_session_id ON n8n_chat_histories(session_id);
CREATE INDEX idx_created_at ON n8n_chat_histories(created_at);
```

---

### "AI responses are slow (>10 seconds)"

**Cause:** First message initializes memory, or OpenAI API delay

**Fix:**
1. First message in session: 5-10 seconds is normal
2. Subsequent messages: Should be <2 seconds
3. If always slow:
   - Check OpenAI API status: [status.openai.com](https://status.openai.com)
   - Switch to `gpt-3.5-turbo` for faster responses (less capable)
   - Check Postgres connection latency

---

### "AI gives generic answers, doesn't query data"

**Cause:** Tools not connected yet (expected until Issue #4)

**Expected behavior:** AI can chat but says "I need my tools connected to query the database"

**Fix:** Complete Issue #4 to add tool nodes

---

### "Error: Could not connect to OpenAI"

**Cause:** API key invalid or quota exceeded

**Fix:**
1. Check API key: Settings → Credentials → OpenAI Market Research → Test Connection
2. Verify API key at [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
3. Check usage limits: [platform.openai.com/usage](https://platform.openai.com/usage)
4. If free tier expired, add payment method

---

## Next Steps

After completing this workflow:

✅ **You have working:** AI chat interface with memory

⏭️ **Next (Issue #4):** Add Postgres tool nodes
- Query Businesses Tool (basic SELECT)
- Query Reviews Tool (full-text search)
- Analyze Opportunities Tool (aggregations)

**This is where it gets powerful** - the AI will write SQL queries on the fly and actually access your data!

---

## Cost Estimation

### GPT-4o-mini (Default)

**Assumptions:**
- Average conversation: 10 messages
- Average message: 50 tokens input, 150 tokens output
- Total per conversation: 2,000 tokens

**Cost:**
- $0.15 per 1M input tokens
- $0.60 per 1M output tokens
- **Per conversation: $0.0003 (3 cents per 100 conversations)**

**Monthly usage:**
- 1,000 conversations/month: $3/month
- 10,000 conversations/month: $30/month

### GPT-4o (If Upgraded)

**Same assumptions:**
- **Per conversation: $0.005 (50 cents per 100 conversations)**
- 1,000 conversations/month: $50/month
- 10,000 conversations/month: $500/month

**Recommendation:** Start with gpt-4o-mini, only upgrade if quality issues.

---

## Advanced: Custom UI Integration

### Embed in React App

```jsx
import { useState } from 'react';

function MarketResearchChat() {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const sessionId = 'user-' + Date.now(); // Or from auth system

  const sendMessage = async () => {
    const userMessage = { role: 'user', content: input };
    setMessages([...messages, userMessage]);

    const response = await fetch('https://your-n8n.com/webhook-test/market-research-chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chatInput: input, sessionId })
    });

    const data = await response.json();
    const aiMessage = { role: 'assistant', content: data.output };
    setMessages([...messages, userMessage, aiMessage]);
    setInput('');
  };

  return (
    <div>
      <div className="messages">
        {messages.map((msg, i) => (
          <div key={i} className={msg.role}>{msg.content}</div>
        ))}
      </div>
      <input value={input} onChange={(e) => setInput(e.target.value)} />
      <button onClick={sendMessage}>Send</button>
    </div>
  );
}
```

### Slack Integration (Alternative)

Replace `chatTrigger` with Slack trigger node:

1. Add **Slack Trigger** node
2. Event: `message.channels`
3. Connect to AI Agent (same flow)
4. Response goes to Slack thread

**Benefit:** Chat interface in Slack instead of web browser

---

## References

- **Cole Medin's Template:** RAG AI Agent Template V5
- **n8n Chat Trigger Docs:** [docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.chattrigger/](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.chattrigger/)
- **n8n AI Agent Docs:** [docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/)
- **OpenAI Models:** [platform.openai.com/docs/models](https://platform.openai.com/docs/models)
- **LangChain Memory:** [python.langchain.com/docs/modules/memory/](https://python.langchain.com/docs/modules/memory/)
