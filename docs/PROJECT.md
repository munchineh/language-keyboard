# Language Keyboard: project doc

> Living document. Paste or attach this at the start of any new chat about the keyboard.
> Last updated: 2026-11-11 · Owner: Mancini · Status: proxy v3 ready (Claude + Gemini), waiting on GitHub repo + deploy, then 5-model blind test

## How to use this doc (for Claude in future chats)

- Read this whole file before answering anything about the keyboard.
- Update it as work happens, without being asked: new decisions go in **Decisions**, finished work in **Status** and **Changelog**, small problems in **Issues log** (don't report small fixable problems in chat; log them here).
- Never write secret values (API keys, tokens) in this file. Only say where they live.
- Keep it scannable: tables over prose. No em dashes in anything written in Mancini's voice.
- When a chat ends or branches, finish with an updated copy of this file.

---

## 1. What we're building

An iOS keyboard (one keyboard, all languages) that helps Mancini text naturally in Korean and Chinese first, German and English later.

| Priority | Goal |
|---|---|
| 1 | Improve his Korean and Chinese while texting real people |
| 2 | Learn casual, online-native texting styles (contractions, slang) rather than textbook forms |
| 3 | A build project that shows his product design and AI-assisted build skills |

Personal use first. Planned so it can go public later without a rebuild.

Existing apps tried (Oct 2026): Keyfred (close, Korean only, no pause-check bubble), Typeciao (good, German only). Neither covers all his languages or the learning features.

---

## 2. Product spec (V1)

**Mockup:** [Language Keyboard Mockup](https://claude.ai/artifact/MqdsHE3fHTUHD33v6fyQZW) (6 screens: Korean typing, correction, nothing-to-fix tick, Chinese RIME, settings, learning mode)

| Feature | Behaviour |
|---|---|
| Layout | Apple-like keyboard with a Liquid Glass look (close match, not pixel-identical). Suggestion bar on top; left icon (where Apple has Writing Tools) opens settings and the language switch |
| Languages | One keyboard, language toggle inside it. **Korean and Chinese first**, then English/German, then others as packs |
| Typing aids | Autocorrect on space (spelling), word completion and next-word prediction, learning from his typing (reset buried in settings) |
| Pause check | Triggers on full stop / ? / ! (and 。？！) or a pause (1–1.5s, adjustable). Not on commas. Never while composing (pinyin buffer or unfinished Hangul syllable). Cancels if he resumes typing |
| Check covers | Sentence structure, conjugation, particles, speech level, honorifics, tone for the recipient |
| Results in bar | **Wrong:** correction + one-line tip + Apply. **Correct but stiff:** tick + "More natural ›". **Natural:** tick only |
| Rephrase | "More natural" opens two options, **Natural** and **Very casual**, with changes highlighted and a note. Generated only when tapped. Follows the profile (no slang to a teacher). Learns which styles he dismisses |
| Settings / profiles | Per language. Korean: speech level (반말/해요체/합쇼체), listener older/same/younger, listener and own gender (형/오빠/누나/언니), relationship, tone. Chinese: mainland/Taiwan, simplified/traditional, register. Shared: tone, emotion, "what I mean" note. Saved profiles (e.g. Friend, Senior, Teacher) |
| Learning mode | Long-press a word in the bar → dictionary panel: meaning, meaning in this sentence, commonly confused words, common pairings, Save to study list |
| Study list | Saved words export to Anki later (deck file or AnkiMobile link), from the companion app |
| Nothing to fix | Shows a tick |

---

## 3. Architecture

```
iPhone keyboard extension ──HTTPS──▶ Cloudflare Worker "keyboard-proxy" ──▶ Claude API
   (Swift, RIME, Hangul,              (checks APP_TOKEN, builds prompts,      (Haiku 5.5 /
    predictions on device)             picks model, logs nothing)              Sonnet 5.5)
            │
     Companion app (settings, profiles, study list, Anki export)
```

| Part | Tech | Notes |
|---|---|---|
| Keyboard + companion app | Swift (SwiftUI + UIKit), Xcode | Needs paid Apple Developer account (US$99/yr) for App Groups and a non-expiring install |
| Chinese input | RIME (librime, BSD licence), e.g. via LibrimeKit; 雾凇拼音 schema | Consider forking Hamster (仓输入法); **check Hamster's licence first** |
| Korean input | Own Hangul composition in Swift | Jamo-level prefix matching for predictions |
| Predictions | On-device word lists + personal history | Korean data: chat/subtitle-style frequency lists; NIKL 모두의 말뭉치 has a messenger corpus (application + redistribution limits) |
| Dictionaries | 한국어기초사전 (CC BY-SA 2.0 KR), CC-CEDICT (CC BY-SA), Wiktionary data | Attribution page needed if public |
| Proxy | Cloudflare Worker `keyboard-proxy` at `https://keyboard-proxy.mancini-tan.workers.dev` | Free plan: 100k requests/day, waiting on the API doesn't count toward CPU time |
| LLM | Claude API via Console org linked to his **Ultra** plan ($200/month API credits); Gemini API via his billed Google account | Model chosen per request; final choice after the blind test |

### Proxy API (v3)

`POST /check` and `POST /rephrase`, header `Authorization: Bearer <APP_TOKEN>`

```json
{ "lang": "ko|zh", "text": "...", "context": "message being replied to",
  "profile": { "relationship": "friend", "speech_level": "banmal|haeyo|hapsyo",
               "listener_age": "older|same|younger", "listener_gender": "male|female",
               "speaker_gender": "male|female", "tone": "...", "region": "mainland|taiwan",
               "script": "simplified|traditional" },
  "note": "what I mean (optional)",
  "model": "haiku|haiku_think|sonnet|gemini_lite|gemini_flash (optional, default haiku)" }
```

- `/check` returns `{"status":"ok","stiff":bool}` or `{"status":"fix","stiff":bool,"corrected":"...","tip":"..."}`. The keyboard works out the changed words itself by comparing the two sentences. A "fix" that changes nothing is turned into "ok" by the proxy.
- `/rephrase` returns `{"options":[{"label":"Natural","text":"...","note":"..."},{"label":"Very casual",...}]}`
- Response headers: `x-latency-ms` (model time), `x-model`. `GET /` returns the version and model list.
- Limits: text ≤ 1000 chars, context ≤ 500, note ≤ 200. Timeout 12s.

| Model key | Model | Settings |
|---|---|---|
| `haiku` (default) | claude-haiku-5-5 | Thinking off, forced tool call |
| `haiku_think` | claude-haiku-5-5 | Thinking on, effort low, tool_choice auto |
| `sonnet` | claude-sonnet-5-5 | Thinking can't be turned off; effort low, tool_choice auto |
| `gemini_lite` | gemini-3.5-flash-lite | Thinking MINIMAL, JSON schema output |
| `gemini_flash` | gemini-3.8-flash | Thinking LOW (its lowest), JSON schema output |
- Slang glossary is a list inside the Worker for now (plan: move to Cloudflare KV, refresh monthly).

### Where things live (no secret values here)

| Item | Location |
|---|---|
| Code + this doc | GitHub repo `language-keyboard` (private): `proxy/`, `docs/`, `blind-test/`. Cloudflare deploys `proxy/` on every push to `main` |
| `ANTHROPIC_API_KEY` | Cloudflare › keyboard-proxy › Settings › Variables and Secrets (Secret) |
| `GEMINI_API_KEY` | Same place. Key from Google AI Studio, on the **billed** project (free tier data may be used by Google and read by reviewers) |
| `APP_TOKEN` | Same place, plus Mancini's password manager ("keyboard-proxy token"). **Rotate before daily use** (an earlier one appeared in a screenshot) |
| Claude API credits | Claude Console org (Individual), linked via claude.ai (web only) › Settings › Billing › API credits |
| Worker code | `proxy/worker.js` (v3) + `proxy/wrangler.jsonc` in the repo |
| Blind test | `blind_test.py` + `sentences.json` (36 starter sentences) |

---

## 4. Decisions and rationale

| # | Decision | Why | Alternatives rejected |
|---|---|---|---|
| D1 | Build a full keyboard, not a check-only one | Check-only (type with Apple's keyboard, switch to check) felt cumbersome | Check-only: 1.5–2 weeks, but bad UX |
| D2 | Use RIME for Chinese | Apple's pinyin engine isn't available to third-party keyboards; RIME is mature, offline, BSD | Building a pinyin engine (months) |
| D3 | Pause/punctuation trigger, not every keystroke | LLM needs a full clause; live checks would be slow, costly and noisy | Comma trigger (false flags on half sentences) |
| D4 | Corrections and rephrasing are separate | Correct-but-formal shouldn't be treated as an error; keeps checks fast | One combined "rewrite" |
| D5 | Never "correct" slang into standard forms; slang glossary in the prompt | He wants online-native texting; no LLM knows slang after its cutoff (June 2026 for Claude) | Live web search on every check (too slow) |
| D6 | Server proxy from day one (Cloudflare Worker) | Keeps the API key off the phone, lets models/prompts/glossary change without app updates, enables rate limits and subscriptions later | Key inside the app (extractable) |
| D7 | Claude and Gemini both available through the proxy | Claude paid from Ultra credits; Gemini already billed. Pick per language on blind-test results | Locking into one provider now |
| D8 | Haiku by default, Sonnet for rephrase/learning/deep check, final call after blind test | Speed priority; Haiku measured ~1.1–1.2s model time | Opus/Fable (too slow for a ~2s target) |
| D9 | Korean and Chinese first | His main daily languages | All four at once |
| D10 | Language packs architecture | Adding a language later becomes data work (2–4 days for Latin-script languages) | Hard-coded languages |
| D11 | Liquid Glass look, close not identical | Exact match isn't possible from a keyboard extension (separate process, private tuning, memory limits) | Pixel-perfect clone |
| D12 | Personal use first, planned for public | Keeps V1 small; avoids a rebuild later | Public V1 |
| D13 | Keep the early check start (send at ~0.6s pause) | Cancelled calls still cost, but credits are covered by Ultra | Waiting the full pause |
| D14 | Rephrase default: only when noticeably stiff (pending confirmation) | Avoids nagging | Always / off |
| D15 | Code and this doc live in a GitHub repo with Cloudflare auto-deploy | He builds away from his Mac; any future chat or Claude Code session can read and update the doc and ship proxy changes | Pasting code into the dashboard; API token deploys |
| D16 | Proxy guards against bad model output (no-change "fix" becomes "ok") | Haiku returned unchanged "fixes" 3 times in the first run | Trusting raw model output |

---

## 5. Status

| Area | State |
|---|---|
| Spec and mockup | Done (V1 scope agreed) |
| Cloudflare Worker | Live (v1). **v3 written and mock-tested**: Claude + Gemini, 5 model options, no-change guard, stricter prompt, error details. Deploys once the repo is connected |
| Claude API access | Working (Haiku confirmed live) |
| Blind test | Haiku (thinking off) on 36 sentences: avg 1.18s model time (0.75–2.6s). About 23 good, 4 real misses, 5 over-corrections or no-change "fixes". Sonnet failed (400), needs re-run after v2. Add a third candidate: Haiku with thinking at low effort |
| Measured speed | Haiku ~1.1–1.2s model time; ~2–3s total from curl on a Mac (cold connections, served from Cloudflare SEA/LAX). Expect ~1.4s per check in the keyboard with a reused connection |
| iOS app | Not started |

---

## 6. Roadmap

| Milestone | Contents | Estimate | Status |
|---|---|---|---|
| M0 Proxy + model choice | Worker, blind test (5 models), pick a model per language, prompt tuning | days | In progress |
| M0.5 Dev setup | GitHub repo + Worker auto-deploy (in progress), Apple Developer account, Xcode Cloud + TestFlight so builds can be installed away from the Mac | 1–2 days | In progress |
| M1 Usable daily | Keyboard shell (fork Hamster or own), Korean + Chinese layouts, in-keyboard toggle, RIME, Hangul, pause check, settings + profiles, language pack structure | ~4–5 weeks | Not started |
| M2 Typing quality | Autocorrect on space, word completion, next-word, learning from typing, rephrase UI | ~2–3 weeks | Not started |
| M3 Learning mode | Long-press dictionary panel, offline dictionaries + LLM note, study list | ~1–2 weeks | Not started |
| M4 Anki | Deck export and/or AnkiMobile add, ties into his card pipeline | ~1 week | Not started |
| M5 More languages | English, German packs | 2–4 days each | Later |
| M6 Public | Sign in with Apple, subscriptions, rate limits, privacy policy, works without Full Access | TBD | Later |

Calendar time will be longer than estimates (full-time classes).

---

## 7. Open questions

- Blind test result: best of haiku / haiku_think / sonnet / gemini_lite / gemini_flash per language (after v3 deploy).
- Pause length default: 1s or 1.5s?
- Rephrase default frequency (only when stiff / always / off) and whether to offer one or two options.
- Fork Hamster vs own shell (check Hamster's licence).
- Dictionary source: offline + LLM note, or LLM only?
- Anki route: deck export, AnkiMobile direct add, built-in review?
- Skip very short messages (ㅇㅇ, ㅋㅋ, 好的) automatically?
- Use Cloudflare AI Gateway (logging off) for rate limits/fallback, or plain Worker?
- Slang glossary: editable via a small web page, or edit a file?
- Public later: subscription, bring-your-own-key, or both?

---

## 8. When to start a new chat

Branch when a task has its own deliverable and only needs this doc as context, not the whole conversation. Start each new chat by attaching this file and saying which section it covers. End each chat with an updated copy.

| Chat | Branch when | Covers |
|---|---|---|
| **A. Proxy, prompts, model choice** (this chat) | Now, until the blind test is judged and the model is picked | Worker, prompts, slang glossary, blind tests |
| **B. Dev setup** | Right after A | GitHub repo, Worker auto-deploy, Apple Developer, Xcode Cloud/TestFlight |
| **C. Keyboard shell + Chinese (RIME)** | After B | Hamster fork or own shell, layouts, Liquid Glass styling, RIME |
| **D. Korean input + predictions** | After C has a working shell | Hangul composition, word lists, autocorrect, learning |
| **E. Settings, profiles, companion app** | Can run in parallel with D | Profile UI, App Group storage, settings panel |
| **F. Learning mode, dictionaries, Anki** | After M1 | Dictionary data, panel UI, study list, export |
| **G. Going public** | Much later | Auth, subscriptions, privacy policy, App Store review |

Also branch when a chat gets long enough that answers slow down or earlier details get missed, or when switching from planning to building in code.

---

## 9. Issues log

| Date | Issue | Status |
|---|---|---|
| 2026-11-11 | Sonnet 5.5 returned 400 on every check. Most likely cause: Sonnet 5.5 can't turn thinking off, and v1 forced a tool call. Not confirmed because v1 hid the error message | Fixed in v2/v3 (auto tool choice, low effort, extra tokens, error details shown). Confirm on re-run |
| 2026-11-11 | Proxy errors hid Anthropic's error message, slowing diagnosis | Fixed in v2 (returns error type and message, never user text) |
| 2026-11-11 | APP_TOKEN visible in a Terminal screenshot | Rotate before daily use |
| 2026-11-11 | Requests from Seoul served by Cloudflare SEA/LAX | Accepted: Anthropic API is US-hosted, so the Pacific hop happens anyway |
| 2026-11-11 | Haiku returned "fix" with unchanged text 3 times (one tip said "placeholder") | Fixed in v3 (guard) |
| 2026-11-11 | Haiku put style changes into "fix" (그런데 그것은 → 그거 진짜) and "fixed" natural texting (집 가는 중 → 가는 중이야) | v3 prompt tightened; confirm on re-run |
| 2026-11-11 | Prompt now includes general rules for address terms by gender and texting shortcuts. Same prompt for every model, so the comparison stays fair, but some test sentences overlap these rules | Note when reading results; add fresh real messages to the test set |
| 2026-11-11 | Haiku missed: 안 했어서, 언니 from a male speaker, 왜냐하면 structure, 오에스티 → OST | Open: compare Sonnet and Haiku with thinking on |

---

## 10. Changelog

| Date | Change |
|---|---|
| 2026-11-10 | Scoped the keyboard: full keyboard, RIME, pause check, profiles, learning mode, rephrase. Mockup made |
| 2026-11-10 | Chose Claude (Ultra credits) over Gemini for now; Cloudflare Worker proxy; secrets set |
| 2026-11-11 | Proxy v1 live; Korean check verified (선생님한테 줬어 → 선생님께 드렸어); latency measured |
| 2026-11-11 | Blind test built (36 sentences); Haiku run complete; Sonnet bug found; proxy v2 written; this doc created |
| 2026-11-11 | Proxy v3: Gemini added (3.5 Flash-Lite, 3.8 Flash), Haiku-with-thinking option, no-change guard, stricter prompt. Blind test upgraded to 5 models. Repo files prepared |
