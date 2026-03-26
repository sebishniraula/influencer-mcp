# AI Influencer Manager — Core Graph + Walkers
#
# Flat graph layout (all nodes connected directly to root):
#   root --> Persona           (one)
#   root --> BrandGuide        (one)
#   root --> ContentDirection  (many, one active at a time)
#   root --> ConversationTurn  (many, chat history)
#   root --> ContentDraft      (many, generated content)

import from datetime { datetime }

# ============================================
# NODES
# ============================================

"""The influencer's core identity and voice."""
node Persona {
    has name: str = "Aria";
    has bio: str = "Sustainable fashion advocate and lifestyle creator";
    has tone: str = "warm, authentic, slightly witty";
    has values: list = ["sustainability", "inclusivity", "transparency"];
    has audience: str = "Gen Z and millennials interested in ethical fashion";
}

"""A content direction set by the brand owner. Only one is active at a time."""
node ContentDirection {
    has theme: str;
    has platforms: list = ["instagram", "tiktok"];
    has tone_override: str = "";
    has active: bool = True;
    has created_at: str = "";
}

"""A generated content draft awaiting approval."""
node ContentDraft {
    has platform: str;
    has caption: str;
    has hashtags: list = [];
    has status: str = "pending";
    has feedback: str = "";
    has created_at: str = "";
}

"""Brand guidelines and content constraints."""
node BrandGuide {
    has brand_name: str = "Your Brand";
    has dos: list = ["promote sustainability", "be authentic", "engage with followers"];
    has donts: list = ["greenwash", "bash competitors", "make false claims"];
    has key_messages: list = ["Fashion can be beautiful AND ethical"];
}

"""A single turn in the conversation between brand owner and influencer."""
node ConversationTurn {
    has role: str;
    has text: str;
    has created_at: str = "";
}

sem Persona.tone = "The speaking style and personality voice of the influencer";
sem Persona.values = "Core values that must be reflected in all content and responses";
sem ContentDirection.theme = "The current content focus requested by the brand owner";
sem ContentDraft.status = "Approval state: pending (awaiting review), approved, or rejected";
sem BrandGuide.donts = "Topics and behaviors the influencer must never engage in";
sem ConversationTurn.role = "Either 'user' (brand owner) or 'influencer' (AI response)";

# ============================================
# TYPED RETURN OBJECTS (required by byllm)
# ============================================

"""Structured result from parse_direction LLM function."""
obj DirectionResult {
    has theme: str = "";
    has tone: str = "";
    has platforms: list[str] = ["instagram", "tiktok"];
}

"""A single content draft returned by create_drafts LLM function."""
obj DraftResult {
    has caption: str = "";
    has hashtags: list[str] = [];
}

# ============================================
# WALKERS
# ============================================

"""Initialize the influencer graph. Safe to call multiple times (idempotent)."""
walker init_influencer {
    can setup with Root entry {
        existing = [-->](?:Persona);
        if not existing {
            # ++> returns the node directly — do not index with [0]
            here ++> Persona();
            here ++> BrandGuide();
            here ++> ContentDirection(
                theme="sustainable fashion essentials",
                created_at=str(datetime.now())
            );
            report {"status": "initialized"};
        } else {
            report {"status": "already_exists"};
        }
    }
}

"""Gather full influencer context from the graph.
Returns dict with persona, active directions, and brand guide.
Used by chat and content-generation walkers (DRY)."""
walker gather_influencer_context {
    has context: dict = {};

    can start with Root entry {
        visit [-->](?:Persona);
        visit [-->](?:ContentDirection);
        visit [-->](?:BrandGuide);
    }

    can gather_persona with Persona entry {
        self.context["persona"] = {
            "name": here.name,
            "bio": here.bio,
            "tone": here.tone,
            "values": here.values,
            "audience": here.audience
        };
    }

    can gather_direction with ContentDirection entry {
        if not here.active {
            skip;
        }
        if "directions" not in self.context {
            self.context["directions"] = [];
        }
        self.context["directions"].append({
            "theme": here.theme,
            "tone": here.tone_override,
            "platforms": here.platforms
        });
    }

    can gather_brand with BrandGuide entry {
        self.context["brand"] = {
            "name": here.brand_name,
            "dos": here.dos,
            "donts": here.donts,
            "key_messages": here.key_messages
        };
    }

    can done with Root exit {
        report self.context;
    }
}

"""Process a message and respond as the AI influencer."""
walker chat_with_influencer {
    has message: str;

    can handle with Root entry {
        ctx_result = root spawn gather_influencer_context();
        ctx = ctx_result.reports[0] if ctx_result.reports else {};

        all_turns = [-->](?:ConversationTurn);
        turn_data = [{"role": t.role, "text": t.text, "ts": t.created_at}
                     for t in all_turns];
        turn_data = sorted(turn_data, key=lambda x: dict -> str : x["ts"])[-10:];
        ctx["history"] = [{"role": t["role"], "text": t["text"]} for t in turn_data];

        try {
            response = self.generate_influencer_response(self.message, ctx);
        } except Exception as e {
            report {"error": "Response generation failed: " + str(e)};
            disengage;
        }

        ts = str(datetime.now());
        here ++> ConversationTurn(role="user", text=self.message, created_at=ts);
        here ++> ConversationTurn(role="influencer", text=response, created_at=ts);

        report {"response": response};
    }

    """Respond to the brand owner as the AI influencer would.
    Stay in character. Be natural, professional, and collaborative.
    Reference current content directions and brand guidelines when relevant.
    Use conversation history to maintain continuity across turns."""
    def generate_influencer_response(
        message: str,
        influencer_context: dict
    ) -> str by llm();
}

"""Set a new content direction. Deactivates all previous directions first."""
walker set_direction {
    has instruction: str;

    can handle with Root entry {
        # Deactivate all existing directions
        all_dirs = [-->](?:ContentDirection);
        for d in all_dirs {
            d.active = False;
        }

        try {
            direction_info = self.parse_direction(self.instruction);
        } except Exception as e {
            report {"error": "Failed to parse direction: " + str(e)};
            disengage;
        }

        if not direction_info.theme {
            report {"error": "Could not identify a content theme. Try: 'Focus on sustainable denim this week'"};
            disengage;
        }

        here ++> ContentDirection(
            theme=direction_info.theme,
            tone_override=direction_info.tone,
            platforms=direction_info.platforms if direction_info.platforms else ["instagram", "tiktok"],
            created_at=str(datetime.now())
        );

        report {"status": "Direction set", "theme": direction_info.theme};
    }

    """Extract structured content direction from a natural language instruction.
    Return a DirectionResult with: theme (required), tone (optional), platforms (optional list).
    Example: 'Focus on eco denim, keep it edgy' -> DirectionResult(theme='eco denim', tone='edgy')"""
    def parse_direction(instruction: str) -> DirectionResult by llm();
}

"""Generate content drafts and persist them as ContentDraft nodes."""
walker generate_content {
    has platform: str = "instagram";
    has count: int = 3;

    can handle with Root entry {
        ctx_result = root spawn gather_influencer_context();
        ctx = ctx_result.reports[0] if ctx_result.reports else {};

        if "directions" in ctx and ctx["directions"] {
            ctx["direction"] = ctx["directions"][0]["theme"];
        } else {
            ctx["direction"] = "general lifestyle and sustainability content";
        }

        try {
            drafts = self.create_drafts(ctx, self.platform, self.count);
        } except Exception as e {
            report {"error": "Draft generation failed: " + str(e)};
            disengage;
        }

        if not isinstance(drafts, list) or len(drafts) == 0 {
            report {"error": "LLM returned no drafts — check byllm plugin is enabled and OPENAI_API_KEY is set"};
            disengage;
        }

        # Use timestamp as a marker to find the newly created nodes afterward
        ts = str(datetime.now());
        for d in drafts {
            here ++> ContentDraft(
                platform=self.platform,
                caption=d.caption,
                hashtags=d.hashtags,
                created_at=ts
            );
        }

        # Collect saved drafts by matching the timestamp
        saved = [];
        all_drafts = [-->](?:ContentDraft);
        for draft in all_drafts {
            if draft.created_at == ts {
                saved.append({
                    "id": str(draft.__jac__.id),
                    "platform": draft.platform,
                    "caption": draft.caption,
                    "hashtags": draft.hashtags,
                    "status": "pending"
                });
            }
        }

        report {"status": "drafts created", "drafts": saved, "count": len(saved)};
    }

    """Create social media post drafts matching the influencer's voice and direction.
    Each draft must have: caption (str), hashtags (list[str]).
    Return exactly count drafts."""
    def create_drafts(
        influencer_context: dict,
        platform: str,
        count: int
    ) -> list[DraftResult] by llm();
}

"""Return all pending content drafts."""
walker get_pending_drafts {
    can collect with Root entry {
        all_drafts = [-->](?:ContentDraft);
        pending = [];
        for d in all_drafts {
            if d.status == "pending" {
                pending.append({
                    "id": str(d.__jac__.id),
                    "platform": d.platform,
                    "caption": d.caption,
                    "hashtags": d.hashtags,
                    "created_at": d.created_at
                });
            }
        }
        report {"drafts": pending};
    }
}

"""Approve a content draft by node ID. Always reports success or explicit error."""
walker approve_draft {
    has draft_id: str;

    can handle with Root entry {
        all_drafts = [-->](?:ContentDraft);
        for d in all_drafts {
            if str(d.__jac__.id) == self.draft_id {
                d.status = "approved";
                report {"status": "approved", "draft_id": self.draft_id};
                disengage;
            }
        }
        report {"error": "Draft not found: " + self.draft_id};
    }
}

"""Reject a content draft with optional feedback."""
walker reject_draft {
    has draft_id: str;
    has feedback: str = "";

    can handle with Root entry {
        all_drafts = [-->](?:ContentDraft);
        for d in all_drafts {
            if str(d.__jac__.id) == self.draft_id {
                d.status = "rejected";
                d.feedback = self.feedback;
                report {"status": "rejected", "draft_id": self.draft_id};
                disengage;
            }
        }
        report {"error": "Draft not found: " + self.draft_id};
    }
}

"""Return analytics: draft counts, active direction, message count."""
walker get_analytics {
    can collect with Root entry {
        all_drafts = [-->](?:ContentDraft);
        counts = {"pending": 0, "approved": 0, "rejected": 0};
        for d in all_drafts {
            if d.status in counts {
                counts[d.status] += 1;
            }
        }

        all_turns = [-->](?:ConversationTurn);

        active_theme = "none";
        all_dirs = [-->](?:ContentDirection);
        for ad in all_dirs {
            if ad.active {
                active_theme = ad.theme;
                break;
            }
        }

        report {
            "drafts": counts,
            "total_drafts": len(all_drafts),
            "active_direction": active_theme,
            "total_messages": len(all_turns)
        };
    }
}
