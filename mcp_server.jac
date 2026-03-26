"""
AI Influencer Manager — MCP Tool Server

Exposes the influencer's capabilities as public HTTP endpoints consumable
by any MCP-compatible client (Claude Desktop, Slack bot, Discord bot, etc.).

Run with:  jac start --dev mcp_server.jac --api_port 8080
Test with: curl -X POST http://localhost:8080/walker/mcp_chat \
               -H "Content-Type: application/json" \
               -d '{"message": "Hey Aria, who are you?"}'

IMPORTANT — Auth constraint in Jac:
  :pub walkers have READ-ONLY access to the root graph. Graph writes (creating
  ConversationTurn nodes etc.) silently fail with :pub. The walkers below are
  designed to work read-only: they gather context from the graph and generate
  responses WITHOUT persisting turns. For a fully stateful MCP integration,
  use Jac's built-in auth (POST /user/login → token → Authorization header).
"""

import from influencer {
    gather_influencer_context,
    set_direction,
    generate_content,
    get_pending_drafts,
    get_analytics,
    init_influencer,
    DraftResult
}

# ─────────────────────────────────────────────────────────────────────────────
# READ-ONLY MCP TOOLS (work with :pub)
# ─────────────────────────────────────────────────────────────────────────────

"""Chat with the influencer. Provides a stateless response based on the current
graph context (persona + active direction + brand guide). Conversation history
is NOT persisted — the MCP client manages conversation context externally.

POST /walker/mcp_chat
Body: {"message": "Push eco-fashion this week"}"""
walker :pub mcp_chat {
    has message: str;

    can handle with Root entry {
        # Gather current influencer context (read-only, works with :pub)
        ctx_result = here spawn gather_influencer_context();
        ctx = ctx_result.reports[0] if ctx_result.reports else {};

        # Generate a stateless response
        try {
            response = self.generate_response(self.message, ctx);
        } except Exception as e {
            report {"error": "Response generation failed: " + str(e)};
            disengage;
        }

        report {"response": response, "influencer": ctx.get("persona", {}).get("name", "Aria")};
    }

    """Respond to the brand owner as the AI influencer.
    Stay in character. Reference current content direction and brand guidelines."""
    def generate_response(message: str, context: dict) -> str by llm();
}

"""Generate content draft previews. Returns drafts WITHOUT persisting them
(read-compatible with :pub). Use the authenticated API for persistent drafts.

POST /walker/mcp_generate
Body: {"platform": "instagram", "count": 3}"""
walker :pub mcp_generate {
    has platform: str = "instagram";
    has count: int = 3;

    can handle with Root entry {
        ctx_result = here spawn gather_influencer_context();
        ctx = ctx_result.reports[0] if ctx_result.reports else {};

        if "directions" in ctx and ctx["directions"] {
            ctx["direction"] = ctx["directions"][0]["theme"];
        } else {
            ctx["direction"] = "general lifestyle and sustainability content";
        }

        try {
            drafts = self.create_draft_previews(ctx, self.platform, self.count);
        } except Exception as e {
            report {"error": "Draft generation failed: " + str(e)};
            disengage;
        }

        if not isinstance(drafts, list) {
            report {"error": "Unexpected LLM response format"};
            disengage;
        }

        report {"drafts": drafts, "platform": self.platform, "note": "Preview only — not persisted"};
    }

    """Create social media post drafts matching the influencer's voice and direction.
    Each draft must have: caption (str), hashtags (list[str]).
    Return exactly `count` drafts."""
    def create_draft_previews(context: dict, platform: str, count: int) -> list[DraftResult] by llm();
}

"""Return the current influencer context (persona, active direction, brand guide).
Useful for MCP clients to understand the current state before sending commands.

POST /walker/mcp_get_context
Body: {}"""
walker :pub mcp_get_context {
    can handle with Root entry {
        ctx_result = here spawn gather_influencer_context();
        if ctx_result.reports {
            report ctx_result.reports[0];
        } else {
            report {"error": "Influencer not initialized"};
        }
    }
}

"""Return analytics: draft counts, active direction, message count.

POST /walker/mcp_analytics
Body: {}"""
walker :pub mcp_analytics {
    can handle with Root entry {
        result = root spawn get_analytics();
        if result.reports {
            report result.reports[0];
        } else {
            report {"error": "Analytics unavailable"};
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# WRITE TOOLS (require auth — see note at top of file)
# ─────────────────────────────────────────────────────────────────────────────

"""Set the influencer's content direction.

NOTE: This walker requires authentication because it writes to the graph.
Authenticate first: POST /user/login → {"token": "..."} → use as Bearer token.

POST /walker/mcp_set_direction
Headers: Authorization: Bearer <token>
Body: {"instruction": "Focus on sustainable denim this week, edgy Gen Z tone"}"""
walker mcp_set_direction {
    has instruction: str;

    can handle with Root entry {
        result = root spawn set_direction(instruction=self.instruction);
        if result.reports {
            report result.reports[0];
        } else {
            report {"error": "Failed to set direction"};
        }
    }
}

"""Fetch all pending drafts (requires auth for user-isolated graph).

POST /walker/mcp_get_drafts
Headers: Authorization: Bearer <token>
Body: {}"""
walker mcp_get_drafts {
    can handle with Root entry {
        result = root spawn get_pending_drafts();
        if result.reports {
            report result.reports[0];
        } else {
            report {"drafts": []};
        }
    }
}
