// keyboard-proxy: Cloudflare Worker between the keyboard and the LLM APIs.
// Secrets (Worker › Settings › Variables and Secrets):
//   ANTHROPIC_API_KEY, GEMINI_API_KEY, APP_TOKEN
// Privacy: this Worker never logs or stores the text it receives.

const VERSION = "3.4";
const DEFAULT_MODEL = "haiku";
const MAX_TEXT = 1000;      // characters per request
const MAX_CONTEXT = 500;
const TIMEOUT_MS = 12000;

// Model options the keyboard (or the blind test) can ask for.
// Claude: Haiku 5.5 can turn thinking off; Sonnet 5.5 can't. Forcing a tool call
// while thinking is on is rejected, so thinking models use tool_choice "auto".
// Gemini: thinking level MINIMAL/LOW keeps it fast.
const MODELS = {
  haiku:        { provider: "claude", id: "claude-haiku-5-5",  thinking: { type: "disabled" }, forceTool: true,  extraTokens: 0 },
  haiku_think:  { provider: "claude", id: "claude-haiku-5-5",  effort: "low",                  forceTool: false, extraTokens: 2000 },
  sonnet:       { provider: "claude", id: "claude-sonnet-5-5", effort: "low",                  forceTool: false, extraTokens: 2000 },
  gemini_lite:  { provider: "gemini", id: "gemini-3.5-flash-lite", thinkingLevel: "MINIMAL", extraTokens: 1000 },
  gemini_flash: { provider: "gemini", id: "gemini-3.8-flash",      thinkingLevel: "LOW",     extraTokens: 2000 },
  gemini_lite31: { provider: "gemini", id: "gemini-3.1-flash-lite", thinkingLevel: "MINIMAL", extraTokens: 1000 },
  gemini_flash36: { provider: "gemini", id: "gemini-3.6-flash",     thinkingLevel: "MINIMAL", extraTokens: 1000 },
};

// Slang glossary: sent with every request so slang is never "corrected".
// Plan: move to KV and refresh monthly.
const SLANG = {
  ko: [
    "ㄹㅇ = 진짜 (for real)",
    "ㅇㅈ = 인정 (agreed)",
    "개- prefix = very (e.g. 개좋아), casual",
    "킹받다 = annoyed, playful",
  ],
  zh: [
    "绝绝子 = amazing (mainland, playful)",
    "yyds = 永远的神, the best (mainland)",
    "超讚 = awesome (Taiwan)",
  ],
};

// ---------- prompts ----------

const LANG_NAME = { ko: "Korean", zh: "Mandarin Chinese" };
// Language for "tip" and "note" (set in the app). Corrected text stays in the checked language.
const EXPLAIN_NAME = {
  en: "English",
  ko: "Korean (simple, polite 해요체)",
  "zh-Hans": "Chinese, simplified characters",
  "zh-Hant": "Chinese, traditional characters",
};

function profileLines(lang, p = {}) {
  const lines = [];
  if (p.relationship) lines.push(`Talking to: ${p.relationship}`);
  if (lang === "ko") {
    if (p.speech_level) lines.push(`Speech level the user chose: ${p.speech_level} (banmal = 반말, haeyo = 해요체, hapsyo = 합쇼체)`);
    if (p.listener_age) lines.push(`Listener is ${p.listener_age === "same" ? "the same age as" : p.listener_age + " than"} the user`);
    if (p.listener_gender) lines.push(`Listener gender: ${p.listener_gender}`);
    if (p.speaker_gender) lines.push(`User's gender: ${p.speaker_gender}`);
  }
  if (lang === "zh") {
    if (p.region) lines.push(`Region style: ${p.region} (mainland or taiwan)`);
    if (p.script) lines.push(`Script: ${p.script} (simplified or traditional)`);
  }
  if (p.tone) lines.push(`Tone the user wants: ${p.tone}`);
  return lines.length ? lines.join("\n") : "No profile set. Infer the register from the text and the message being replied to.";
}

const LANG_RULES = {
  ko: `Korean rules:
- Check every verb and adjective ending, including connective endings (-어서, -는데, -고), for valid conjugation.
- The speech level in the profile (반말 / 해요체 / 합쇼체) is the user's deliberate choice, whatever the relationship. Text already in that level is correct. Flag only text in a different level or mixing levels, and always correct TO the chosen level, never to another one.
- Honorifics also apply to people being talked ABOUT, even in 반말: respected people (grandparents, parents, teachers, bosses, older strangers) take -(으)시- on their verbs and honorific particles/verbs (께, 드리다, 계시다, 드시다).
- Address terms must match the speaker's and listener's genders: a male speaker says 형 / 누나, a female speaker says 오빠 / 언니. Check them when genders are given.
- Natural texting shortcuts are correct and must not be "fixed": dropped particles (집 가), omitted subjects, endings like -는 중 or noun endings without 이야, ㅋㅋ / ㅠㅠ.
- Type the way Koreans actually type: OST, TV, PC, not 오에스티, 티비, 피씨.`,
  zh: `Chinese rules:
- Follow the region setting (mainland vs Taiwan vocabulary and particles) and the script setting (simplified vs traditional characters). Output text in the chosen script.
- Taiwan Mandarin rarely uses 儿化: never add 兒/儿 for Taiwan, and 哪 / 哪裡 are standard there.
- Watch measure words, aspect markers (了 / 过 / 着), complements (的 / 得 / 地), word order and wrong characters from pinyin input (在 / 再).`,
};

function checkSystem(lang, outputLine) {
  return `You are the correction engine inside a mobile keyboard. The user is an intermediate learner of ${LANG_NAME[lang]} texting real people.

Decide, for the user's text only:
- "fix": there is a real error (grammar, conjugation, particles, wrong word, wrong speech level, honorifics or address terms for this listener). "corrected" must differ from the user's text.
- "ok": no errors. This includes text that is correct but formal or textbook-like.
- "stiff": true only when the text is correct but clearly sounds textbook-like for texting in this relationship. Style issues never make a "fix".

Hard rules:
- If nothing needs changing, the status is "ok". Never return "fix" with unchanged text.
- If the only changes you would make are word choice, contractions or a more casual or natural phrasing of correct text, the status is "ok" with "stiff": true. A "fix" may contain only the changes needed to correct errors.
- Keep every word that doesn't need correcting. Never drop or add content.
- Never "correct" slang, abbreviations, laughter (ㅋㅋ, 哈哈), emoji or casual online spelling into standard forms. Only flag them if misused.
- Make the smallest change that fixes the error. Keep the user's words, voice and casualness.
- "tip" is one short line (max 90 characters) in the explanation language given with the request, explaining the main fix and quoting the changed words. No em dashes.
- If unsure whether something is wrong, choose "ok".

${LANG_RULES[lang]}

Current slang (never correct these): ${SLANG[lang].join("; ")}

${outputLine}`;
}

function rephraseSystem(lang, outputLine) {
  return `You are the rephrasing engine inside a mobile keyboard. The user is an intermediate learner of ${LANG_NAME[lang]} and wants their correct text to sound like a native texting in this situation.

Give exactly two options:
1. "Natural": how a native speaker would naturally text this to this listener. Contractions and common spoken forms, no forced slang.
2. "Very casual": more relaxed, with natural contractions and current slang where it genuinely fits. If the profile is formal (teacher, senior, 합쇼체, stranger), keep option 2 polite and just make it warmer and less stiff.

Rules:
- Keep the meaning. Do not add new information.
- "note" is one short line (max 90 characters) in the explanation language given with the request, naming the key changes and quoting the words. No em dashes.

${LANG_RULES[lang]}

Current slang you may use where natural: ${SLANG[lang].join("; ")}

${outputLine}`;
}

const CHECK_SCHEMA = {
  type: "object",
  properties: {
    status: { type: "string", enum: ["ok", "fix"] },
    stiff: { type: "boolean", description: "Correct but noticeably textbook-like for texting" },
    corrected: { type: "string", description: "Full corrected text, only when status is fix" },
    tip: { type: "string", description: "One short line in the explanation language, only when status is fix" },
  },
  required: ["status", "stiff"],
};

const REPHRASE_SCHEMA = {
  type: "object",
  properties: {
    options: {
      type: "array",
      minItems: 2,
      maxItems: 2,
      items: {
        type: "object",
        properties: {
          label: { type: "string", enum: ["Natural", "Very casual"] },
          text: { type: "string" },
          note: { type: "string" },
        },
        required: ["label", "text", "note"],
      },
    },
  },
  required: ["options"],
};

// ---------- helpers ----------

function json(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", ...extra },
  });
}

// Rate limits (bindings in wrangler.jsonc). Limits count per Cloudflare
// location and are approximate; provider spending caps are the hard backstop.
// If a binding is missing or errors, the request is allowed (fail open) so a
// config slip never breaks the keyboard.
async function withinLimit(limiter, key) {
  if (!limiter) return true;
  try {
    const { success } = await limiter.limit({ key });
    return success;
  } catch {
    return true;
  }
}

// Short hash so the raw token is never used as a limiter key.
async function tokenKey(token) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return [...new Uint8Array(digest).slice(0, 8)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function tooMany() {
  return json({ error: "rate limited" }, 429, { "retry-after": "60" });
}

// Constant-time comparison so the token can't be guessed by timing.
function safeEqual(a, b) {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] || 0) ^ (y[i] || 0);
  return diff === 0;
}

function parseJsonText(text) {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end <= start) throw new Error("no json in reply");
  return JSON.parse(text.slice(start, end + 1));
}

async function upstreamError(res) {
  // Provider error type and message describe the request settings, never the user's text.
  let detail = "";
  try {
    const e = await res.json();
    const err = e?.error || {};
    detail = `${err.type || err.status || ""}: ${String(err.message || "").slice(0, 200)}`;
  } catch {}
  const error = new Error(`upstream ${res.status}`);
  error.status = res.status;
  error.detail = detail;
  return error;
}

// ---------- providers ----------

async function callClaude(env, m, { system, schema, toolName, userContent, maxTokens }) {
  const body = {
    model: m.id,
    max_tokens: maxTokens + m.extraTokens,
    system: [{ type: "text", text: system, cache_control: { type: "ephemeral" } }],
    tools: [{ name: toolName, description: "Return the result.", input_schema: schema }],
    tool_choice: m.forceTool ? { type: "tool", name: toolName } : { type: "auto" },
    messages: [{ role: "user", content: userContent }],
  };
  if (m.thinking) body.thinking = m.thinking;
  if (m.effort) body.output_config = { effort: m.effort };

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!res.ok) throw await upstreamError(res);
  const data = await res.json();
  const block = (data.content || []).find((b) => b.type === "tool_use");
  if (block) return block.input;
  const text = (data.content || []).filter((b) => b.type === "text").map((b) => b.text).join("");
  if (text) return parseJsonText(text);
  throw new Error(data.stop_reason === "max_tokens" ? "ran out of tokens" : "no result");
}

async function callGemini(env, m, { system, schema, userContent, maxTokens }) {
  if (!env.GEMINI_API_KEY) throw new Error("GEMINI_API_KEY not set");
  const body = {
    systemInstruction: { parts: [{ text: system }] },
    contents: [{ role: "user", parts: [{ text: userContent }] }],
    generationConfig: {
      responseMimeType: "application/json",
      responseJsonSchema: schema,
      maxOutputTokens: maxTokens + m.extraTokens,
      thinkingConfig: { thinkingLevel: m.thinkingLevel },
    },
  };
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${m.id}:generateContent`, {
    method: "POST",
    headers: { "x-goog-api-key": env.GEMINI_API_KEY, "content-type": "application/json" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!res.ok) throw await upstreamError(res);
  const data = await res.json();
  const parts = data?.candidates?.[0]?.content?.parts || [];
  const text = parts.filter((p) => !p.thought && typeof p.text === "string").map((p) => p.text).join("");
  if (!text) throw new Error(`no result (${data?.candidates?.[0]?.finishReason || "unknown"})`);
  return parseJsonText(text);
}

// ---------- result clean-up ----------

const norm = (s) => String(s || "").replace(/\s+/g, " ").trim();

function cleanCheck(result, text) {
  const stiff = !!result.stiff;
  // A "fix" that changes nothing (or has no corrected text) is really "ok".
  if (result.status !== "fix" || !result.corrected || norm(result.corrected) === norm(text)) {
    return { status: "ok", stiff };
  }
  return { status: "fix", stiff, corrected: result.corrected, tip: result.tip || "" };
}

// ---------- handler ----------

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/") {
      return json({ ok: true, service: "keyboard-proxy", version: VERSION, models: Object.keys(MODELS) });
    }
    if (request.method !== "POST" || !["/check", "/rephrase"].includes(url.pathname)) {
      return json({ error: "not found" }, 404);
    }

    // Per-IP limit first, so token guessing and junk traffic are capped too.
    const ip = request.headers.get("cf-connecting-ip") || "unknown";
    if (!(await withinLimit(env.IP_LIMITER, `ip:${ip}`))) return tooMany();

    const auth = request.headers.get("authorization") || "";
    const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    if (!env.APP_TOKEN || !safeEqual(token, env.APP_TOKEN)) {
      return json({ error: "unauthorized" }, 401);
    }

    // Per-token limit: one leaked token can't run up the API bill.
    if (!(await withinLimit(env.TOKEN_LIMITER, `tok:${await tokenKey(token)}`))) return tooMany();

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: "invalid json" }, 400);
    }

    const { lang, text, context = "", profile = {}, note = "", explain = "en" } = body || {};
    const modelKey = MODELS[body?.model] ? body.model : DEFAULT_MODEL;
    const m = MODELS[modelKey];
    if (!LANG_NAME[lang]) return json({ error: "lang must be ko or zh" }, 400);
    if (typeof text !== "string" || !text.trim()) return json({ error: "text required" }, 400);
    if (text.length > MAX_TEXT || String(context).length > MAX_CONTEXT || String(note).length > 200) {
      return json({ error: "too long" }, 413);
    }

    const isCheck = url.pathname === "/check";
    const toolName = isCheck ? "report" : "options";
    const outputLine = m.provider === "claude"
      ? `Always answer by calling the ${toolName} tool.`
      : "Answer only with JSON matching the response schema.";
    const userContent = [
      `Explanation language: ${EXPLAIN_NAME[explain] || EXPLAIN_NAME.en}`,
      `Profile:\n${profileLines(lang, profile)}`,
      context ? `Message being replied to:\n${context}` : "",
      note ? `What the user means: ${note}` : "",
      `User's text:\n${text}`,
    ].filter(Boolean).join("\n\n");

    const args = {
      system: isCheck ? checkSystem(lang, outputLine) : rephraseSystem(lang, outputLine),
      schema: isCheck ? CHECK_SCHEMA : REPHRASE_SCHEMA,
      toolName,
      userContent,
      maxTokens: isCheck ? 400 : 600,
    };

    const started = Date.now();
    try {
      const raw = m.provider === "claude" ? await callClaude(env, m, args) : await callGemini(env, m, args);
      const result = isCheck ? cleanCheck(raw, text) : raw;
      return json(result, 200, { "x-latency-ms": String(Date.now() - started), "x-model": modelKey });
    } catch (e) {
      const status = e.name === "TimeoutError" ? 504 : 502;
      return json({
        error: e.status ? `${m.provider} ${e.status}` : e.name === "TimeoutError" ? "timeout" : e.message || "upstream error",
        detail: e.detail || undefined,
        model: modelKey,
      }, status);
    }
  },
};
