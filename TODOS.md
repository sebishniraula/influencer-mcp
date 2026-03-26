# TODOS

## TODO: MCP Authentication

**What:** Add `auth: bool = True` to all MCP walker `__specs__` before any public or shared deployment.

**Why:** All three MCP walkers (`mcp_chat`, `mcp_set_direction`, `mcp_generate`) currently use `auth: bool = False`. Anyone who can reach the endpoint can call the LLM indefinitely, burning API credits with no rate limiting or identity check.

**Pros:** Protects API keys from abuse; makes the MCP server shareable beyond localhost.

**Cons:** Requires implementing Jac's auth middleware; adds setup complexity for demo environments.

**Context:** Jac supports `auth: bool = True` in `__specs__`. Switching it on requires configuring the Jac auth system (likely token-based). Safe to defer until post-demo / pre-public-deployment. Document clearly in README so the developer doesn't accidentally deploy the open version.

**Depends on / blocked by:** Core chat and MCP server working end-to-end first.

---

## TODO: get_analytics Walker + MCP Endpoint

**What:** Implement a `get_analytics` walker and expose it as an MCP tool (`mcp_analytics` endpoint).

**Why:** The plan's intro explicitly lists `get_analytics` as one of the influencer's MCP capabilities, but no code defines it. Without it, the stated MCP tool surface is incomplete.

**Pros:** Completes the MCP API surface as described; useful for brand owners to see draft counts, direction history, and engagement summary.

**Cons:** Requires deciding what metrics to expose and how to aggregate graph data; minor implementation effort.

**Context:** A simple version could return: total drafts by status (pending/approved/rejected), current active direction, message count, and a list of past direction themes. All data is already in the graph — this is just a read walker. Implement as `mcp_analytics` with `methods: ["get"]`.

**Depends on / blocked by:** ContentDraft persistence (from Issue 3) must be implemented first so there's real data to aggregate.
