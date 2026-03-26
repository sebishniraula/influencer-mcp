# AI Influencer Manager

A full-stack AI application built with the [Jac language](https://www.jac-lang.org/) that lets you manage an AI social media influencer — chat with her, set content direction, generate post drafts, and approve or reject them.

The influencer is named **Aria**: a sustainable fashion advocate with a warm, authentic voice targeting Gen Z and millennials.

> **This project was built as an MCP (Model Context Protocol) exploration** — the core idea is exposing Aria's capabilities as a set of HTTP tools that any MCP-compatible client (Claude Desktop, a Slack bot, a Discord bot, etc.) can call directly, without needing the web UI at all.

---

## What it does

| Feature | Description |
|---|---|
| **Chat with Aria** | Have a natural conversation with your AI influencer. She knows her brand, values, and content direction. |
| **Set content direction** | Tell Aria what theme and tone to focus on (e.g. "sustainable summer fashion"). |
| **Generate drafts** | Auto-generate Instagram/TikTok post captions + hashtags aligned with Aria's persona and your brand guidelines. |
| **Approve / Reject** | Review generated drafts in a sidebar panel. Approve to publish or reject with optional feedback so Aria can improve. |
| **Auth** | Full sign-up / sign-in flow — each user gets their own Aria instance with its own graph state. |

---

## MCP Server

`mcp_server.jac` exposes Aria's capabilities as plain HTTP endpoints — no web UI required. Any tool that can make a POST request can use Aria: Claude Desktop, a Slack bot, a cron job, a CI pipeline, whatever.

### Public endpoints (no auth needed)

These are read-only and work without a login token:

| Endpoint | Body | What it does |
|---|---|---|
| `POST /walker/mcp_chat` | `{"message": "..."}` | Chat with Aria — returns a response in her voice |
| `POST /walker/mcp_generate` | `{"platform": "instagram", "count": 3}` | Generate post drafts (preview, not persisted) |
| `POST /walker/mcp_get_context` | `{}` | Get current persona, brand guide, active direction |
| `POST /walker/mcp_analytics` | `{}` | Draft counts, message count, active direction |

### Authenticated endpoints (require Bearer token)

These write to the graph so they need a user session:

| Endpoint | Body | What it does |
|---|---|---|
| `POST /walker/mcp_set_direction` | `{"instruction": "Focus on sustainable denim, edgy Gen Z tone"}` | Update Aria's active content direction |
| `POST /walker/mcp_get_drafts` | `{}` | Fetch all pending drafts for the logged-in user |

### Quick start with curl

```bash
# Start the MCP server
OPENAI_API_KEY=your-key python -m jaclang start mcp_server.jac --port 8080

# Chat with Aria (no auth required)
curl -X POST http://localhost:8080/walker/mcp_chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hey Aria, what are you working on this week?"}'

# Generate Instagram drafts
curl -X POST http://localhost:8080/walker/mcp_generate \
  -H "Content-Type: application/json" \
  -d '{"platform": "instagram", "count": 3}'

# Get Aria's current context
curl -X POST http://localhost:8080/walker/mcp_get_context \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Authenticated usage

```bash
# 1. Register a user
curl -X POST http://localhost:8080/user/register \
  -H "Content-Type: application/json" \
  -d '{"email": "you@example.com", "password": "yourpassword", "username": "you"}'

# 2. Log in to get a token
TOKEN=$(curl -s -X POST http://localhost:8080/user/login \
  -H "Content-Type: application/json" \
  -d '{"email": "you@example.com", "password": "yourpassword"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['token'])")

# 3. Set Aria's content direction
curl -X POST http://localhost:8080/walker/mcp_set_direction \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"instruction": "Focus on sustainable denim this week, edgy Gen Z tone"}'
```

### Design note: stateless vs stateful

The public MCP tools are intentionally **stateless** — `mcp_chat` generates a response from the current graph context but doesn't save conversation history. The MCP client is expected to manage conversation context externally (just like Claude Desktop does). This is what makes them safe to expose without authentication.

The authenticated tools (set direction, get drafts) write to the user's personal graph, so they require a login token to keep each user's Aria instance isolated.

---

## Architecture

Built with **Jac** — a language that compiles to Python on the backend and React on the frontend from a single source file.

```
main.jac         ← React frontend (cl{} blocks) + entry point
influencer.jac   ← Backend: graph nodes, walkers, LLM-powered logic
mcp_server.jac   ← MCP tool server (HTTP endpoints for external clients)
tests.jac        ← 11 unit/integration tests
jac.toml         ← Project config (deps, port, LLM model)
```

The project has **two ways to interact with Aria**:
1. **Web UI** (`main.jac`) — the full browser app with chat, drafts panel, auth
2. **MCP server** (`mcp_server.jac`) — raw HTTP tools, call from anything

### Graph layout

Every user's data lives in a flat graph rooted at their `root` node:

```
root
 ├── Persona           (one)   — Aria's identity, tone, values
 ├── BrandGuide        (one)   — dos/don'ts, key messages
 ├── ContentDirection  (many)  — active content theme + platform
 ├── ConversationTurn  (many)  — chat history
 └── ContentDraft      (many)  — pending/approved/rejected posts
```

### LLM integration

Uses Jac's `by llm()` syntax (byllm plugin) with `gpt-4o` by default. LLM functions have typed return objects so byllm can generate proper JSON schemas:

```jac
can generate_response(context: str, message: str) -> str by llm();
can create_drafts(persona: str, direction: str, platform: str, count: int) -> list[DraftResult] by llm();
```

---

## Setup

### Prerequisites

- Python 3.11+
- [Bun](https://bun.sh/) (for frontend bundling) — install with:
  ```bash
  # macOS/Linux
  curl -fsSL https://bun.sh/install | bash

  # Windows (PowerShell)
  irm bun.sh/install.ps1 | iex
  ```
- OpenAI API key

### Install

```bash
# Clone the repo
git clone https://github.com/sebishniraula/influencer-mcp.git
cd influencer-mcp

# Create a virtual environment and install Jac
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate

pip install jaclang jac-byllm python-dotenv

# Set up environment
cp .env.example .env
# Edit .env and add your OPENAI_API_KEY
```

### Run

```bash
# Make sure Bun is in PATH (Windows example):
export PATH="/c/Users/YOUR_USERNAME/.bun/bin:$PATH"

# Start the dev server
OPENAI_API_KEY=$(grep OPENAI_API_KEY .env | cut -d= -f2) \
  python -m jaclang start main.jac --port 3333
```

Open **http://localhost:3333** in your browser.

> **Windows note:** Port 8000 (the default) is often blocked by Windows. Use `--port 3333` or another port above 3000.

---

## Running tests

```bash
OPENAI_API_KEY=your-key python -m jaclang test tests.jac
```

All 11 tests should pass. Tests cover: influencer initialization, persona/brand creation, content direction, draft generation, chat responses, approval/rejection flows.

---

## Known issue: chat response not displaying

> **Symptom:** You send a message, see "Aria is typing..." but no response ever appears.

**Root cause:** In Jac's `cl{}` (React) frontend, `root spawn walkerName()` is an async HTTP call that returns a Promise. Without `await`, the code reads the result before the request finishes — so `result.reports` is always empty and the message is never added.

**Fix applied** (in `main.jac`):
```jac
# BROKEN — reads result before the HTTP call completes
result = root spawn chat_with_influencer(message=current);

# FIXED — waits for the response
result = await root spawn chat_with_influencer(message=current);
```

The same fix applies to `generate_content`, `approve_draft`, `reject_draft`, and the init calls in `useEffect`.

**If you're still seeing this after pulling:** the frontend bundle may be cached. Stop the server, delete the `.jac/` build cache, and restart:

```bash
# Stop the server (Ctrl+C)
rm -rf .jac/
python -m jaclang start main.jac --port 3333
```

---

## Configuration

Edit `jac.toml` to change defaults:

```toml
[plugins.byllm.model]
default_model = "gpt-4o"   # change to gpt-4o-mini to reduce cost

[serve]
port = 8000   # override with --port flag at runtime
```

---

## Project structure

```
influencer-mcp/
├── main.jac          # Full-stack entry: React UI + imports
├── influencer.jac    # Core: nodes, walkers, LLM logic
├── mcp_server.jac    # MCP server for external tool integration
├── tests.jac         # Test suite (jac test tests.jac)
├── jac.toml          # Project config
└── .env.example      # Environment variable template
```

---

## Tech stack

- **[Jac](https://www.jac-lang.org/)** — Object-Spatial Programming language (Python backend + React frontend from one file)
- **[jaclang byllm](https://docs.jaseci.org/learn/jac-byllm/quickstart/)** — `by llm()` decorator for LLM-backed functions
- **MCP (Model Context Protocol)** — HTTP tool endpoints consumable by Claude Desktop, bots, and other AI clients
- **OpenAI GPT-4o** — Default LLM
- **React** — Auto-compiled from `cl{}` blocks in Jac
- **Bun** — Frontend bundler
