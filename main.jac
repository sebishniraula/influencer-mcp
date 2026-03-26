# AI Influencer Manager — Full-Stack Entry Point
# Frontend calls walkers directly (no wrapper layer needed).

import from influencer {
    init_influencer,
    chat_with_influencer,
    set_direction,
    generate_content,
    get_pending_drafts,
    approve_draft,
    reject_draft
}

cl import from "@jac/runtime" { jacSignup, jacLogin, jacLogout, jacIsLoggedIn }
cl import from react { useEffect }

# ============================================
# FRONTEND (cl{} compiles to React)
# ============================================

cl {
    def:pub app() -> JsxElement {
        # Auth state
        has logged_in: bool = False;
        has email: str = "";
        has password: str = "";
        has auth_mode: str = "login";
        has auth_error: str = "";
        has auth_loading: bool = False;

        # Chat state
        has messages: list = [];
        has input_val: str = "";
        has chat_loading: bool = False;

        # Drafts state
        has drafts: list = [];
        has show_drafts: bool = False;
        has generate_loading: bool = False;
        has reject_feedback: str = "";
        has rejecting_id: str = "";

        # App init state
        has app_loading: bool = True;

        # ── Lifecycle ──────────────────────────────────────────────────────────
        useEffect(lambda -> None { async def init_app -> None {
            logged_in = jacIsLoggedIn();
            if logged_in {
                await root spawn init_influencer();
                dr = await root spawn get_pending_drafts();
                if dr.reports { drafts = dr.reports[0]["drafts"]; }
            }
            app_loading = False;
        } init_app();}, []);

        # ── Auth ───────────────────────────────────────────────────────────────
        async def handle_auth() -> None {
            auth_loading = True;
            auth_error = "";
            if auth_mode == "signup" {
                result = await jacSignup(email, password);
                if result["success"] {
                    await root spawn init_influencer();
                    dr = await root spawn get_pending_drafts();
                    if dr.reports { drafts = dr.reports[0]["drafts"]; }
                    logged_in = True;
                } else {
                    auth_error = result["error"] if result["error"] else "Signup failed";
                }
            } else {
                success = await jacLogin(email, password);
                if success {
                    await root spawn init_influencer();
                    dr = await root spawn get_pending_drafts();
                    if dr.reports { drafts = dr.reports[0]["drafts"]; }
                    logged_in = True;
                } else {
                    auth_error = "Invalid credentials. Please try again.";
                }
            }
            auth_loading = False;
        }

        def handle_logout() -> None {
            jacLogout();
            logged_in = False;
            messages = [];
            drafts = [];
        }

        # ── Chat ───────────────────────────────────────────────────────────────
        async def send_msg() -> None {
            current = input_val.trim();
            if not current { return; }
            input_val = "";
            messages = [*messages, {"role": "user", "text": current}];
            chat_loading = True;
            result = await root spawn chat_with_influencer(message=current);
            if result.reports {
                data = result.reports[-1];
                if "response" in data {
                    messages = [*messages, {"role": "influencer", "text": data["response"]}];
                } else {
                    messages = [*messages, {"role": "error", "text": "No response"}];
                }
            }
            chat_loading = False;
        }

        # ── Drafts ─────────────────────────────────────────────────────────────
        async def handle_generate() -> None {
            generate_loading = True;
            result = await root spawn generate_content(platform="instagram", count=3);
            if result.reports {
                data = result.reports[-1];
                if "drafts" in data {
                    drafts = [*drafts, *data["drafts"]];
                }
            }
            generate_loading = False;
            show_drafts = True;
        }

        async def handle_approve(draft_id: str) -> None {
            result = await root spawn approve_draft(draft_id=draft_id);
            if result.reports {
                drafts = [d for d in drafts if d["id"] != draft_id];
            }
        }

        async def handle_reject(draft_id: str, feedback: str) -> None {
            result = await root spawn reject_draft(draft_id=draft_id, feedback=feedback);
            if result.reports {
                drafts = [d for d in drafts if d["id"] != draft_id];
                rejecting_id = "";
                reject_feedback = "";
            }
        }

        # ── Render: loading ────────────────────────────────────────────────────
        if app_loading {
            return <div style={{"display": "flex", "alignItems": "center",
                                "justifyContent": "center", "height": "100vh",
                                "fontFamily": "sans-serif", "color": "#666"}}>
                Loading...
            </div>;
        }

        # ── Render: login / signup ─────────────────────────────────────────────
        if not logged_in {
            return <div style={{"maxWidth": "400px", "margin": "80px auto",
                                "padding": "32px", "fontFamily": "sans-serif",
                                "border": "1px solid #e0e0e0", "borderRadius": "12px",
                                "boxShadow": "0 2px 12px rgba(0,0,0,0.08)"}}>
                <h2 style={{"marginTop": "0", "color": "#1a1a2e"}}>
                    {("Create account") if auth_mode == "signup" else ("Welcome back")}
                </h2>
                <p style={{"color": "#666", "marginBottom": "24px"}}>
                    {("Sign up to manage your AI influencer") if auth_mode == "signup"
                     else ("Sign in to manage your AI influencer")}
                </p>
                <input
                    type="email"
                    placeholder="Email"
                    value={email}
                    onChange={lambda e: Any -> None { email = e.target.value; }}
                    style={{"width": "100%", "padding": "10px 12px", "marginBottom": "12px",
                            "border": "1px solid #ddd", "borderRadius": "8px",
                            "fontSize": "14px", "boxSizing": "border-box"}}
                />
                <input
                    type="password"
                    placeholder="Password"
                    value={password}
                    onChange={lambda e: Any -> None { password = e.target.value; }}
                    onKeyDown={lambda e: Any -> None {
                        if e.key == "Enter" { handle_auth(); }
                    }}
                    style={{"width": "100%", "padding": "10px 12px", "marginBottom": "16px",
                            "border": "1px solid #ddd", "borderRadius": "8px",
                            "fontSize": "14px", "boxSizing": "border-box"}}
                />
                {auth_error and <p style={{"color": "#e74c3c", "margin": "0 0 12px",
                                           "fontSize": "13px"}}>{auth_error}</p>}
                <button
                    onClick={lambda e: Any -> None { handle_auth(); }}
                    disabled={auth_loading}
                    style={{"width": "100%", "padding": "12px", "background": "#6c63ff",
                            "color": "#fff", "border": "none", "borderRadius": "8px",
                            "fontSize": "15px", "cursor": "pointer", "marginBottom": "16px"}}>
                    {("Signing in...") if auth_loading else
                     (("Sign Up") if auth_mode == "signup" else ("Sign In"))}
                </button>
                <p style={{"textAlign": "center", "color": "#888", "fontSize": "13px",
                           "margin": "0"}}>
                    {("Already have an account? ") if auth_mode == "signup"
                     else ("Don't have an account? ")}
                    <span
                        onClick={lambda e: Any -> None {
                            auth_mode = ("login") if auth_mode == "signup" else ("signup");
                            auth_error = "";
                        }}
                        style={{"color": "#6c63ff", "cursor": "pointer"}}>
                        {("Sign in") if auth_mode == "signup" else ("Sign up")}
                    </span>
                </p>
            </div>;
        }

        # ── Render: main app ───────────────────────────────────────────────────
        return <div style={{"maxWidth": "900px", "margin": "0 auto", "padding": "20px",
                            "fontFamily": "sans-serif"}}>

            <div style={{"display": "flex", "justifyContent": "space-between",
                         "alignItems": "center", "marginBottom": "20px",
                         "borderBottom": "1px solid #eee", "paddingBottom": "16px"}}>
                <div>
                    <h1 style={{"margin": "0", "color": "#1a1a2e", "fontSize": "22px"}}>
                        Aria
                    </h1>
                    <p style={{"margin": "4px 0 0", "color": "#888", "fontSize": "13px"}}>
                        Your AI Influencer
                    </p>
                </div>
                <div style={{"display": "flex", "gap": "8px"}}>
                    <button
                        onClick={lambda e: Any -> None { show_drafts = not show_drafts; }}
                        style={{"padding": "8px 16px", "background": "#f0f0f0",
                                "border": "none", "borderRadius": "8px",
                                "cursor": "pointer", "fontSize": "13px"}}>
                        {"Hide Drafts" if show_drafts else ("Drafts (" + String(drafts.length) + ")")}
                    </button>
                    <button
                        onClick={lambda e: Any -> None { handle_logout(); }}
                        style={{"padding": "8px 16px", "background": "none",
                                "border": "1px solid #ddd", "borderRadius": "8px",
                                "cursor": "pointer", "fontSize": "13px", "color": "#666"}}>
                        Sign out
                    </button>
                </div>
            </div>

            <div style={{"display": "flex", "gap": "20px"}}>

                <div style={{"flex": "1"}}>
                    <div style={{"height": "420px", "overflowY": "auto",
                                 "border": "1px solid #e8e8e8", "borderRadius": "12px",
                                 "padding": "16px", "marginBottom": "12px",
                                 "background": "#fafafa"}}>
                        {messages.length == 0 and
                            <p style={{"color": "#bbb", "textAlign": "center",
                                       "marginTop": "160px", "fontSize": "14px"}}>
                                Say hello to Aria...
                            </p>
                        }
                        {[<div style={{
                            "textAlign": ("right") if m["role"] == "user" else ("left"),
                            "margin": "8px 0"
                        }}>
                            <span style={{
                                "background": ("#6c63ff") if m["role"] == "user"
                                              else (("#fee2e2") if m["role"] == "error"
                                              else ("#f0f0f0")),
                                "color": ("#fff") if m["role"] == "user" else ("#333"),
                                "padding": "10px 14px",
                                "borderRadius": "16px",
                                "display": "inline-block",
                                "maxWidth": "80%",
                                "fontSize": "14px",
                                "lineHeight": "1.5"
                            }}>
                                {m["text"]}
                            </span>
                        </div> for m in messages]}
                        {chat_loading and
                            <div style={{"color": "#aaa", "fontSize": "13px",
                                         "fontStyle": "italic"}}>
                                Aria is typing...
                            </div>
                        }
                    </div>

                    <div style={{"display": "flex", "gap": "8px"}}>
                        <input
                            value={input_val}
                            onChange={lambda e: Any -> None { input_val = e.target.value; }}
                            onKeyDown={lambda e: Any -> None {
                                if e.key == "Enter" and not chat_loading { send_msg(); }
                            }}
                            placeholder="Tell Aria what you need..."
                            style={{"flex": "1", "padding": "12px 14px",
                                    "borderRadius": "8px", "border": "1px solid #ddd",
                                    "fontSize": "14px"}}
                        />
                        <button
                            onClick={lambda e: Any -> None { send_msg(); }}
                            disabled={chat_loading}
                            style={{"padding": "12px 20px", "borderRadius": "8px",
                                    "background": "#6c63ff", "color": "#fff",
                                    "border": "none", "cursor": "pointer",
                                    "fontSize": "14px"}}>
                            Send
                        </button>
                        <button
                            onClick={lambda e: Any -> None { handle_generate(); }}
                            disabled={generate_loading}
                            style={{"padding": "12px 16px", "borderRadius": "8px",
                                    "background": "#10b981", "color": "#fff",
                                    "border": "none", "cursor": "pointer",
                                    "fontSize": "13px"}}>
                            {("Generating...") if generate_loading else ("+ Drafts")}
                        </button>
                    </div>
                </div>

                {show_drafts and
                    <div style={{"width": "320px", "border": "1px solid #e8e8e8",
                                 "borderRadius": "12px", "padding": "16px",
                                 "background": "#fff", "height": "fit-content",
                                 "maxHeight": "500px", "overflowY": "auto"}}>
                        <h3 style={{"margin": "0 0 12px", "fontSize": "15px",
                                    "color": "#1a1a2e"}}>
                            Pending Drafts
                        </h3>
                        {drafts.length == 0 and
                            <p style={{"color": "#bbb", "fontSize": "13px"}}>
                                No drafts yet. Click "+ Drafts" to generate.
                            </p>
                        }
                        {[<div key={d["id"]} style={{"border": "1px solid #f0f0f0",
                                                       "borderRadius": "8px",
                                                       "padding": "12px",
                                                       "marginBottom": "10px"}}>
                            <p style={{"margin": "0 0 6px", "fontSize": "13px",
                                       "color": "#555", "lineHeight": "1.4"}}>
                                {d["caption"]}
                            </p>
                            <p style={{"margin": "0 0 10px", "fontSize": "11px",
                                       "color": "#6c63ff"}}>
                                {" ".join(["#" + h for h in d["hashtags"]])}
                            </p>
                            {rejecting_id == d["id"] and
                                <div>
                                    <input
                                        placeholder="Feedback (optional)"
                                        value={reject_feedback}
                                        onChange={lambda e: Any -> None {
                                            reject_feedback = e.target.value;
                                        }}
                                        style={{"width": "100%", "padding": "6px 8px",
                                                "borderRadius": "6px",
                                                "border": "1px solid #ddd",
                                                "fontSize": "12px",
                                                "marginBottom": "6px",
                                                "boxSizing": "border-box"}}
                                    />
                                    <div style={{"display": "flex", "gap": "6px"}}>
                                        <button
                                            onClick={lambda e: Any -> None {
                                                handle_reject(d["id"], reject_feedback);
                                            }}
                                            style={{"flex": "1", "padding": "6px",
                                                    "background": "#ef4444",
                                                    "color": "#fff", "border": "none",
                                                    "borderRadius": "6px",
                                                    "cursor": "pointer",
                                                    "fontSize": "12px"}}>
                                            Confirm Reject
                                        </button>
                                        <button
                                            onClick={lambda e: Any -> None {
                                                rejecting_id = "";
                                            }}
                                            style={{"padding": "6px 10px",
                                                    "background": "#f0f0f0",
                                                    "border": "none", "borderRadius": "6px",
                                                    "cursor": "pointer",
                                                    "fontSize": "12px"}}>
                                            Cancel
                                        </button>
                                    </div>
                                </div>
                            }
                            {rejecting_id != d["id"] and
                                <div style={{"display": "flex", "gap": "6px"}}>
                                    <button
                                        onClick={lambda e: Any -> None {
                                            handle_approve(d["id"]);
                                        }}
                                        style={{"flex": "1", "padding": "6px",
                                                "background": "#10b981", "color": "#fff",
                                                "border": "none", "borderRadius": "6px",
                                                "cursor": "pointer",
                                                "fontSize": "12px"}}>
                                        Approve
                                    </button>
                                    <button
                                        onClick={lambda e: Any -> None {
                                            rejecting_id = d["id"];
                                        }}
                                        style={{"flex": "1", "padding": "6px",
                                                "background": "#f9f9f9",
                                                "border": "1px solid #ef4444",
                                                "color": "#ef4444",
                                                "borderRadius": "6px",
                                                "cursor": "pointer",
                                                "fontSize": "12px"}}>
                                        Reject
                                    </button>
                                </div>
                            }
                        </div> for d in drafts]}
                    </div>
                }
            </div>
        </div>;
    }
}
