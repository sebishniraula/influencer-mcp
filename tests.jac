# AI Influencer Manager — Test Suite
# Run with: jac test tests.jac
#
# Tests share graph state and run in order.
# Covers 11 codepaths from the engineering review.

import from influencer {
    init_influencer,
    gather_influencer_context,
    chat_with_influencer,
    set_direction,
    generate_content,
    get_pending_drafts,
    approve_draft,
    reject_draft,
    Persona,
    BrandGuide,
    ContentDirection,
    ContentDraft,
    ConversationTurn
}

# ─────────────────────────────────────────────────────────────────────────────
# HELPER WALKERS — used by tests to query graph nodes from root context
# ─────────────────────────────────────────────────────────────────────────────

walker get_personas {
    can c with Root entry { report [-->](?:Persona); }
}

walker get_brand_guides {
    can c with Root entry { report [-->](?:BrandGuide); }
}

walker get_directions {
    can c with Root entry { report [-->](?:ContentDirection); }
}

walker get_drafts {
    can c with Root entry { report [-->](?:ContentDraft); }
}

walker get_turns {
    can c with Root entry { report [-->](?:ConversationTurn); }
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 1: init_influencer creates the expected graph nodes
# ─────────────────────────────────────────────────────────────────────────────
test {
    root spawn init_influencer();
    personas = (root spawn get_personas()).reports[0];
    assert len(personas) == 1;
    brand_guides = (root spawn get_brand_guides()).reports[0];
    assert len(brand_guides) == 1;
    directions = (root spawn get_directions()).reports[0];
    assert len(directions) >= 1;
    assert personas[0].name == "Aria";
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 2: init_influencer is idempotent
# ─────────────────────────────────────────────────────────────────────────────
test {
    root spawn init_influencer();
    root spawn init_influencer();
    personas = (root spawn get_personas()).reports[0];
    assert len(personas) == 1;
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 3: gather_influencer_context returns expected structure
# ─────────────────────────────────────────────────────────────────────────────
test {
    root spawn init_influencer();
    ctx_result = root spawn gather_influencer_context();
    assert len(ctx_result.reports) > 0;
    ctx = ctx_result.reports[0];
    assert "persona" in ctx;
    assert "brand" in ctx;
    assert "name" in ctx["persona"];
    assert "donts" in ctx["brand"];
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 4: set_direction creates a ContentDirection and deactivates old ones
# ─────────────────────────────────────────────────────────────────────────────
test {
    root spawn init_influencer();
    r1 = root spawn set_direction(instruction="Focus on eco denim this week");
    assert len(r1.reports) > 0;
    report1 = r1.reports[0];
    assert "error" not in report1;
    assert report1["status"] == "Direction set";

    r2 = root spawn set_direction(instruction="Pivot to minimalist capsule wardrobes");
    report2 = r2.reports[0];
    assert "error" not in report2;

    all_dirs = (root spawn get_directions()).reports[0];
    active_count = 0;
    for d in all_dirs {
        if d.active {
            active_count += 1;
        }
    }
    assert active_count == 1;
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 5: generate_content creates ContentDraft nodes
# ─────────────────────────────────────────────────────────────────────────────
test {
    root spawn init_influencer();
    root spawn set_direction(instruction="sustainable denim for Gen Z");

    drafts_before = (root spawn get_drafts()).reports[0];
    count_before = len(drafts_before);

    result = root spawn generate_content(platform="instagram", count=2);
    assert len(result.reports) > 0;
    rep = result.reports[-1];
    assert "error" not in rep;
    assert rep["count"] == 2;

    drafts_after = (root spawn get_drafts()).reports[0];
    assert len(drafts_after) == count_before + 2;

    new_draft = drafts_after[count_before];
    assert new_draft.platform == "instagram";
    assert new_draft.status == "pending";
    assert len(new_draft.caption) > 0;
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 6: get_pending_drafts returns only pending drafts with required fields
# ─────────────────────────────────────────────────────────────────────────────
test {
    root spawn init_influencer();
    root spawn generate_content(platform="instagram", count=2);

    result = root spawn get_pending_drafts();
    assert len(result.reports) > 0;
    rep = result.reports[0];
    assert "drafts" in rep;
    assert len(rep["drafts"]) >= 2;

    first = rep["drafts"][0];
    assert "id" in first;
    assert "caption" in first;
    assert "platform" in first;
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 7: approve_draft changes status to 'approved'
# ─────────────────────────────────────────────────────────────────────────────
test {
    root spawn init_influencer();
    gen = root spawn generate_content(platform="instagram", count=1);
    gen_rep = gen.reports[-1];
    assert "error" not in gen_rep;  # fails here if LLM/plugin not set up
    assert gen_rep.get("count", 0) > 0;  # fails if byllm returned empty

    pending_result = root spawn get_pending_drafts();
    pending_drafts = pending_result.reports[0]["drafts"];
    assert len(pending_drafts) >= 1;
    draft_id = pending_drafts[0]["id"];

    approve_result = root spawn approve_draft(draft_id=draft_id);
    rep = approve_result.reports[0];
    assert "error" not in rep;
    assert rep["status"] == "approved";

    # Verify approved draft no longer appears in pending
    pending_after = root spawn get_pending_drafts();
    found = False;
    for pd in pending_after.reports[0]["drafts"] {
        if pd["id"] == draft_id {
            found = True;
        }
    }
    assert not found;
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 8: reject_draft changes status and stores feedback
# ─────────────────────────────────────────────────────────────────────────────
test {
    root spawn init_influencer();
    gen = root spawn generate_content(platform="tiktok", count=1);
    gen_rep = gen.reports[-1];
    assert "error" not in gen_rep;  # fails here if LLM/plugin not set up
    assert gen_rep.get("count", 0) > 0;  # fails if byllm returned empty

    pending_result = root spawn get_pending_drafts();
    pending_drafts = pending_result.reports[0]["drafts"];
    assert len(pending_drafts) >= 1;
    draft_id = pending_drafts[0]["id"];

    reject_result = root spawn reject_draft(
        draft_id=draft_id,
        feedback="Too formal, needs more Gen Z energy"
    );
    rep = reject_result.reports[0];
    assert "error" not in rep;
    assert rep["status"] == "rejected";

    # Verify feedback stored on the node
    all_drafts = (root spawn get_drafts()).reports[0];
    matched = False;
    for d in all_drafts {
        if str(d.__jac__.id) == draft_id {
            assert d.feedback == "Too formal, needs more Gen Z energy";
            assert d.status == "rejected";
            matched = True;
        }
    }
    assert matched;
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 9: approve_draft with invalid ID returns explicit error
# ─────────────────────────────────────────────────────────────────────────────
test {
    result = root spawn approve_draft(draft_id="nonexistent-id-12345");
    assert len(result.reports) > 0;
    rep = result.reports[0];
    assert "error" in rep;
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 10: reject_draft with invalid ID returns explicit error
# ─────────────────────────────────────────────────────────────────────────────
test {
    result = root spawn reject_draft(draft_id="nonexistent-id-99999", feedback="nope");
    assert len(result.reports) > 0;
    rep = result.reports[0];
    assert "error" in rep;
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 11: ConversationTurn nodes created after chat_with_influencer
# ─────────────────────────────────────────────────────────────────────────────
test {
    root spawn init_influencer();

    turns_before = (root spawn get_turns()).reports[0];
    count_before = len(turns_before);

    result = root spawn chat_with_influencer(message="Hey Aria, who are you?");
    assert len(result.reports) > 0;
    rep = result.reports[-1];
    assert "error" not in rep;
    assert "response" in rep;
    assert len(rep["response"]) > 0;

    turns_after = (root spawn get_turns()).reports[0];
    assert len(turns_after) == count_before + 2;

    # Verify both roles exist among the new turns
    found_user = False;
    found_influencer = False;
    i = count_before;
    while i < len(turns_after) {
        if turns_after[i].role == "user" { found_user = True; }
        if turns_after[i].role == "influencer" { found_influencer = True; }
        i += 1;
    }
    assert found_user;
    assert found_influencer;
}
