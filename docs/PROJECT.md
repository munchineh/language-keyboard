# Language Keyboard: project doc

> Living document. Paste or attach this at the start of any new chat about the keyboard.
> Last updated: 2026-11-11 · Owner: Mancini · Status: proxy v3 live (Claude + Gemini); 5-model blind test ready to judge; iOS app skeleton builds green in GitHub Actions

## How to use this doc (for Claude in future chats)

- Read this whole file before answering anything about the keyboard.
- Update it as work happens, without being asked: new decisions go in **Decisions**, finished work in **Status** and **Changelog**, small problems in **Issues log** (don't report small fixable problems in chat; log them here).
- Never write secret values (API keys, tokens) in this file. Only say where they live.
- Keep it scannable: tables over prose. No em dashes in anything written in Mancini's voice.
- When a chat ends or branches, finish with an updated copy of this file.

---

## 0. Handoff (read first)

Chat B (iOS project + CI) ended 2026-11-11. The app skeleton builds and tests green on GitHub Actions. Branch `ios-app`, [PR #1](https://github.com/munchineh/language-keyboard/pull/1) to `main` open.

| Item | State |
|---|---|
| Next task | **1.** Mancini at the Mac once: open Xcode, accept the licence, install the iOS component (asks for the Mac password), sign in with his Apple ID. **2.** Claude: Simulator check (Finder › `~/Projects/language-keyboard/app/LanguageKeyboard.xcodeproj`, scheme LanguageKeyboard, Run). **3.** TestFlight: Team ID into `project.yml`, register bundle IDs + App Group, App Store Connect API key as GitHub secrets, add an upload job. **4.** Chat C: RIME for Chinese |
| iOS app | `app/` (see section 3, "iOS app"). **MVP built 2026-11-11** to Mancini's feedback: two-tone icons, card above the bar (blue highlights, reason in the chosen language, blue arrow), bar = settings icon + suggestions, long-press return applies, emoji page, settings panel with Done to save and in-keyboard text fields, Korean word suggestions, pinyin input for Chinese (simplified = mainland, traditional = Taiwan words). 18 tests + 24 snapshots |
| CI | `.github/workflows/ios.yml` on `macos-26` (Xcode 26.6): XcodeGen, Simulator build, unsigned device build, tests, then commits the generated `.xcodeproj`, Info.plists and entitlements back with `[skip ci]`. ~4 min per run. Claude can read run results through `api.github.com` from the cloud session |
| Mac access | Mac "mancinis-laptop-local" via the Claude desktop app. `~/Projects` connected 2026-11-11. Computer use granted for Xcode (click-only) and Finder, background mode. **Xcode is still at its first-launch licence screen** (Claude didn't accept it). Simulator isn't installed until the iOS component is. The Mac shell (`device_bash`) is a Linux VM with no GitHub credentials, so code reaches the Mac as a snapshot (tarball copied in, then extracted) |
| Mac copy | `~/Projects/language-keyboard` = snapshot of `ios-app` at commit `b508a82`. Re-copy after changes. `~/Projects/_to_delete/language-keyboard.tar.gz` can be deleted |
| Waiting on Mancini | Xcode first launch + Apple ID (above). Team ID from developer.apple.com › Account › Membership. Blind-test picks |
| Model default | App default **Sonnet 5.5** (Checks tab, changeable). Proxy default is still `haiku`. Final call after blind test |
| Proxy change pending | `proxy/worker.js` v3.3 adds `explain` (language of tips/notes). Cloudflare deploys from `main`, so it goes live when PR #1 is merged; until then tips stay in English |
| Open items | Rotate `APP_TOKEN` before daily use (then paste it into the app's Checks tab); blind-test judging page; Apple on-device model test (M2.5); Siri AI proposals in `docs/research/` |

---|---|
| Next task | Create the Xcode project in this repo (`app/`): companion app + keyboard extension, shared App Group, built around the mockup. Then open it on the Mac by clicking in Xcode and build in the iPhone Simulator |
| Mac access | Mac "mancinis-laptop-local" via the Claude desktop app. Folders: `~/Projects`, `~/Downloads`, Desktop, Documents, Movies, Pictures. Computer use: background mode preferred. **Terminal and Xcode are click-only (no typing)**, so generate the project files in the repo (e.g. a hand-written `.xcodeproj` or a generator run elsewhere) and copy them to `~/Projects/language-keyboard`. The Mac shell (`device_bash`) is a Linux VM: it can't run Xcode |
| Waiting on Mancini | First Xcode launch (component install, Mac password) and signing in to Xcode with his Apple ID. Apple Developer Program enrolled (Individual) |
| Model default | Leaning **Sonnet 5.5** for both languages (most accurate in 3-run scoring, ~1.5s). Not yet confirmed; Mancini's blind-test picks pending |
| UI path | Swift directly (web prototype skipped) |
| Build without the Mac (planned) | Mancini won't be at the Mac for a while. Plan: XcodeGen spec (`app/project.yml`) in the repo; **GitHub Actions macOS runner** builds on every push; once the Apple Developer membership is active, an App Store Connect API key (stored as GitHub secrets) lets the workflow sign and upload to **TestFlight**, and Mancini installs from the TestFlight app on his iPhone. The Mac is optional: Simulator checks via computer use (Finder opens the project, Xcode Run is a click; Simulator is full-access). Simulator builds don't need an Apple ID sign-in |
| Open items | Rotate `APP_TOKEN` before daily use; blind-test judging page; Apple on-device model test (M2.5); Siri AI proposals in `docs/research/` |

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
| `gemini_lite31` | gemini-3.1-flash-lite | Thinking MINIMAL (speed test only) |
| `gemini_flash36` | gemini-3.6-flash | Thinking MINIMAL (speed test only) |
- Slang glossary is a list inside the Worker for now (plan: move to Cloudflare KV, refresh monthly).

### iOS app (`app/`)

| Part | Files | Notes |
|---|---|---|
| Project spec | `project.yml` | XcodeGen. Targets: `LanguageKeyboard` (app), `Keyboard` (extension, `RequestsOpenAccess`), `SharedTests`. iOS 18+, iPhone only |
| IDs | `com.mancinitan.LanguageKeyboard`, `.Keyboard`, App Group `group.com.mancinitan.LanguageKeyboard` | Register in the developer portal before the first signed build |
| Shared | `Shared/` | `HangulComposer` (2-beolsik, jamo backspace), `Models` (languages, profiles, settings), `SettingsStore` (App Group), `ProxyClient` (`/check`, `/rephrase`, one reused connection), `TextDiff` (highlights changed parts) |
| Keyboard | `Keyboard/` | `KeyboardViewController` hosts SwiftUI. `KeyboardModel`: typing, pause check (punctuation = now, else after `pauseSeconds`), cancels on typing, Apply/rephrase replace the text only if it's unchanged. `KeyboardView`: bar, result card, keys (44pt, mockup colours, full-width touch areas, delete repeats). `SettingsPanel`: mockup's "Check settings" |
| Companion app | `App/` | Tabs: Set up (steps + try-it field), Profiles (per language, edit/add/delete, speaker gender, Chinese region/script, "What I mean"), Checks (on/off, pause, model, proxy URL + token, test check with timing) |
| Tests | `Tests/` | Hangul composition and backspace, diff highlighting, settings decoding. Also run on Linux with the Swift toolchain for quick checks |
| Suggestions | `Shared/Lexicons.swift`, `Keyboard/Resources/` | Korean: 26.8k words (wordfreq), matched on jamo so 안녀 → 안녕 and 갑 → 가방. Chinese: 40k words with pinyin, simplified + Taiwan traditional (OpenCC s2twp); candidates = whole match, then longest leading word, then 3 longer words. Emoji: Unicode 16 and older. Rebuild with `tools/build_lexicons.py` |
| Snapshots | `SnapshotTests/` | 8 states × light/dark, drawn in a chat frame. Light palette: white letter keys, grey function keys, #007aff blue, deeper orange (#c95c00) and green (#248a3d) for contrast on white. The grey platter behind the keys is only for snapshots; on a device the system draws the keyboard background |

### Where things live (no secret values here)

| Item | Location |
|---|---|
| Code + this doc | GitHub repo `language-keyboard` (private): `proxy/`, `docs/`, `blind-test/`. Cloudflare deploys `proxy/` on every push to `main` |
| `ANTHROPIC_API_KEY` | Cloudflare › keyboard-proxy › Settings › Variables and Secrets (Secret) |
| `GEMINI_API_KEY` | Same place. Key from Google AI Studio, on the **billed** project (free tier data may be used by Google and read by reviewers) |
| `APP_TOKEN` | Same place, plus Mancini's password manager ("keyboard-proxy token"). **Rotate before daily use** (an earlier one appeared in a screenshot) |
| Claude API credits | Claude Console org (Individual), linked via claude.ai (web only) › Settings › Billing › API credits |
| Worker code | `proxy/worker.js` (v3) + `proxy/wrangler.jsonc` in the repo |
| iOS code | `app/` in the repo. Edit `app/project.yml`, never the `.xcodeproj` (CI regenerates it) |
| Proxy token on the phone | Pasted into the companion app (Checks tab), stored in the App Group. Not in the repo |
| Blind test | v3 run complete: 36 sentences × 5 models, 0 errors. Judging page: [Keyboard blind test](https://claude.ai/artifact/4AKy3ivDKKEW1PvRASiYMH) (pick the best answer per sentence, then Reveal). Model time: haiku avg 1.10s (median 1.03s) · haiku_think 2.03s (1.80s) · sonnet 1.64s (1.49s) · gemini_lite 1.36s (0.79s, p90 2.7s) · gemini_flash 4.14s (3.61s). Waiting on Mancini's picks |
| Auto-scored (prompt 3.2, 3 runs × 36) | **sonnet 32.0** (31 always right, 2 flaky) · haiku_think 30.3 · gemini_lite 30.0 (5 flaky) · haiku 28.0. Haiku now always misses 선생님께 드렸어, 오셨어, 안 했어서 (it caught some of these under prompt 3.1, so 3.2 may have hurt Haiku). Expected answers for #10 잤었어, #23 전화를 할게요, #35 再一次去 are debatable |

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
| D17 | XcodeGen spec in the repo; CI generates the project and commits it back | Mac Terminal and Xcode are click-only and Mancini is away from the Mac; the committed project opens in Xcode with no commands | Hand-written `.xcodeproj` (fragile); generating on the Mac (no typing) |
| D18 | GitHub Actions macOS runner for builds now, TestFlight upload later in the same workflow | Works from anywhere, logs readable by Claude; Xcode Cloud needs Xcode GUI setup on the Mac first | Xcode Cloud |
| D19 | SwiftUI keyboard inside `UIInputViewController`; shared code compiled into each target | Fast to build to the mockup; no framework embedding to get wrong | Separate shared framework (later, if build times grow) |
| D20 | Mockup's emoji key becomes the language toggle (shows the language it switches to) | Third-party keyboards can't open Apple's emoji keyboard; the system draws globe and mic below the keyboard on Face ID iPhones | Dead emoji key |
| D21 | Proxy token in App Group storage for now | Personal use; simple | Shared Keychain (move there before going public) |
| D22 | App default model Sonnet 5.5, changeable in the app | Matches the current leaning (most accurate in 3-run scoring) without a proxy change | Proxy default `haiku` |
| D23 | Light and dark mode both supported; keyboard follows the host app's keyboard appearance, then the system setting, and updates live | Mockup was dark only; Apple's keyboard does both | Dark only |
| D25 | Bar = two-tone settings icon (language mark in the lighter tone; green after a clean check, pulsing while checking) + word suggestions. Corrections move to the card above | Mancini's feedback: "2 fixes · Friend · 반말" was clutter; match Apple's predictive bar | Status text in the bar |
| D26 | Card: corrected text with changes in iOS blue, one-line reason in the chosen language, blue arrow to apply; concentric with the keyboard corners (6pt margin all round, radius 24) | Feedback: blue matches iOS; equal margins | Orange highlights, Apply capsule |
| D27 | Long-press return (0.45s) applies whatever the card shows (correction or rewrite), with a haptic; return turns blue while there's something to apply | Quick apply without reaching up; Mancini: long press just means Apply | Swipe on space |
| D36 | Settings icon: a solid gear (6 wide spokes, crisp edges) with the language mark (한 / 中) cut out of the centre as negative space. The mark never changes colour | Chosen over sliders with an overlapping mark (busier at bar size) and an outlined gear | Mancini's reference: two-tone line icons; a colour change on the mark was unclear | Mark turning green / pulsing (D25, replaced) |
| D37 | Check status sits where suggestions go: spinner + "Checking…" (only when there are no suggestions), green check + "Looks right!" when nothing to fix. Green is used only for success | Clearer than recolouring the icon | Status on the icon |
| D38 | Explanations under corrections and rewrites in a fainter grey than the text | Hierarchy: the corrected text matters most | Same grey as secondary text |
| D35 | One rewrite at a time: "Rewrite as" Natural / Very casual is a setting (keyboard panel + app); the card shows only that version | Card height eats into the chat | Showing both options |
| D28 | No quick language key. Emoji key opens the keyboard's own emoji page (recents + Unicode groups) | Feedback: language only in settings. Third-party keyboards can't open Apple's emoji keyboard | Language toggle key (D20, replaced) |
| D29 | Settings panel: native segmented controls, compact rows, same height for both languages; changes are a draft saved on Done. Korean: language, speech level, speaking to, age + gender (M/F/–), tone, what I mean. Chinese: language, script, speaking to, tone, what I mean | Feedback; fits the keyboard height without scrolling | Scrolling panel |
| D30 | "Speaking to" is optional free text (replaces profiles); gender has a "not set" option and the check then assumes nothing | Feedback | Fixed profile chips |
| D31 | Settings text fields are typed with the keyboard's own keys (field shown in the bar, ABC/한 toggle only there) | A keyboard can't type into a text field inside itself | Editing only in the companion app |
| D32 | Chinese: simplified = mainland vocabulary, traditional = Taiwan vocabulary, for both checks and suggestions. Malaysia and HK later | Keep it simple | Separate region setting |
| D33 | Chinese input MVP: own pinyin engine on a frequency list (marked text in the app's field) instead of RIME for now | Ships today, no C++ build; RIME can replace it later if quality needs it | RIME first |
| D34 | Explanation language setting (English, 한국어, 简体, 繁體) sent to the proxy as `explain` | Feedback: reasoning localised to user settings | English only |
| D24 | CI renders every keyboard state in light and dark (`KeyboardSnapshots` test target) and uploads them as the `keyboard-snapshots` artifact | Lets Mancini and Claude review the UI from a phone with no Mac or Simulator | Waiting for Simulator checks |

---

## 5. Status

| Area | State |
|---|---|
| Spec and mockup | Done (V1 scope agreed) |
| Cloudflare Worker | Live (v1). **v3 written and mock-tested**: Claude + Gemini, 5 model options, no-change guard, stricter prompt, error details. Auto-deploys from `main` (repo connected 2026-11-11, root path `/proxy`) |
| Claude API access | Working (Haiku confirmed live) |
| Blind test | Haiku (thinking off) on 36 sentences: avg 1.18s model time (0.75–2.6s). About 23 good, 4 real misses, 5 over-corrections or no-change "fixes". Sonnet failed (400), needs re-run after v2. Add a third candidate: Haiku with thinking at low effort |
| Measured speed | Haiku ~1.1–1.2s model time; ~2–3s total from curl on a Mac (cold connections, served from Cloudflare SEA/LAX). Expect ~1.4s per check in the keyboard with a reused connection |
| iOS app | **Skeleton done (2026-11-11)**: XcodeGen project, companion app, keyboard extension built to the mockup, 13 unit tests, CI green (Simulator + unsigned device builds). Not yet run in a Simulator or on the iPhone. Earlier: Mac ready (2026-11-11): Xcode installed from the App Store; ~67 GB free after cleanup. Apple Developer Program: enrolled 2026-11-11 (Individual). Claude can reach the Mac remotely: folders `~/Projects`, `~/Downloads`, Desktop, Documents, Movies, Pictures; computer use (Terminal and Xcode are click-only, so the Xcode project is generated in the repo and opened in Xcode by clicking). Still needs Mancini at the Mac once: Xcode first-launch component install (may ask for the Mac password) and signing in to Xcode with his Apple ID |

---

## 6. Roadmap

| Milestone | Contents | Estimate | Status |
|---|---|---|---|
| M0 Proxy + model choice | Worker, blind test (5 models), pick a model per language, prompt tuning | days | In progress |
| M0.5 Dev setup | GitHub repo + Worker auto-deploy (done), Apple Developer account (done), XcodeGen + GitHub Actions build (done), TestFlight upload so builds can be installed away from the Mac | 1–2 days | In progress |
| M1 Usable daily | Keyboard shell (fork Hamster or own), Korean + Chinese layouts, in-keyboard toggle, RIME, Hangul, pause check, settings + profiles, language pack structure | ~4–5 weeks | Not started |
| M2 Typing quality | Autocorrect on space, word completion, next-word, learning from typing, rephrase UI | ~2–3 weeks | Not started |
| M3 Learning mode | Long-press dictionary panel, offline dictionaries + LLM note, study list | ~1–2 weeks | Not started |
| M4 Anki | Deck export and/or AnkiMobile add, ties into his card pipeline | ~1 week | Not started |
| M5 More languages | English, German packs | 2–4 days each | Later |
| M2.5 Apple AI | 1-day device test: can the keyboard call Apple's on-device model (Foundation Models), with and without Full Access? Then a Siri study loop (App Shortcuts + Spotlight now, Siri AI tool intents when the Developer Preview reaches the App Store, spring 2027). See `docs/research/Siri AI keyboard integration.md` | 1 day test, then 1.5–2 weeks | Not started |
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
| **B. Dev setup** | Right after A (done 2026-11-11 except TestFlight) | GitHub repo, Worker auto-deploy, Apple Developer, XcodeGen + Actions, TestFlight |
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
| 2026-11-11 | Sonnet 5.5 returned 400 on every check. Most likely cause: Sonnet 5.5 can't turn thinking off, and v1 forced a tool call. Not confirmed because v1 hid the error message | Fixed in v3: Sonnet ran 36/36 without errors |
| 2026-11-11 | Proxy errors hid Anthropic's error message, slowing diagnosis | Fixed in v2 (returns error type and message, never user text) |
| 2026-11-11 | APP_TOKEN visible in a Terminal screenshot | Rotate before daily use |
| 2026-11-11 | Requests from Seoul served by Cloudflare SEA/LAX | Accepted: Anthropic API is US-hosted, so the Pacific hop happens anyway |
| 2026-11-11 | Haiku returned "fix" with unchanged text 3 times (one tip said "placeholder") | Fixed in v3 (guard) |
| 2026-11-11 | Haiku put style changes into "fix" (그런데 그것은 → 그거 진짜) and "fixed" natural texting (집 가는 중 → 가는 중이야) | v3 prompt tightened; confirm on re-run |
| 2026-11-11 | Prompt now includes general rules for address terms by gender and texting shortcuts. Same prompt for every model, so the comparison stays fair, but some test sentences overlap these rules | Note when reading results; add fresh real messages to the test set |
| 2026-11-11 | Smoke test: haiku_think passed 안 했어서 as ok, while haiku (thinking off), sonnet and both Geminis caught it | Watch in blind-test results |
| 2026-11-11 | gemini_flash (3.8 Flash) averages 4.1s; LOW is its lowest thinking level | Likely too slow for the pause check regardless of quality |
| 2026-11-11 | Speed-only rerun (36 sentences, one model at a time): gemini_lite median 0.80s / p90 0.96s · gemini_lite31 0.85s / 1.10s · haiku 0.96s / 1.23s · gemini_flash36 1.29s / 1.55s. The earlier 2.7s p90 for gemini_lite came from running 5 models at once | Fastest: Gemini 3.5 Flash-Lite. Quality decided by the blind test |
| 2026-11-11 | Haiku vs Gemini 3.5 Flash-Lite, my read of the 36 answers: Haiku clearly better on 6 (follows the chosen speech level, keeps meaning, correct-but-stiff handled right), Flash-Lite better on 3 (all Chinese: 的/得, Taiwan 哪, a more natural Korean reason clause). Flash-Lite overrode the chosen 해요체/합쇼체 three times and once dropped 책을 | Leaning: Haiku for Korean, Flash-Lite worth considering for Chinese. Mancini's own picks still to come |
| 2026-11-11 | Both models: missed 할머니가 왔어 → 오셨어; changed a chosen 해요체 to 반말 for a friend; put style edits into "fix" | Done in proxy 3.2 |
| 2026-11-11 | Run-to-run variance is large: single runs can't separate models. Use `score.py` with 3+ runs for decisions | Process rule |
| 2026-11-11 | gemini_lite once corrupted text (교수님 → 교수닐) and once changed meaning (我想再去了) | Watch: a correction that introduces errors is worse than none |
| 2026-11-11 | Haiku missed: 안 했어서, 언니 from a male speaker, 왜냐하면 structure, 오에스티 → OST | Open: compare Sonnet and Haiku with thinking on |
| 2026-11-11 | Chinese layout types pinyin letters only | Done: own pinyin engine (D33). Missing: abbreviations (nh → 你好), fuzzy pinyin, learning from use |
| 2026-11-11 | Korean suggestions are word stems (wordfreq splits particles: 친구 not 친구랑); no next-word prediction after a space yet | M2 |
| 2026-11-11 | Emoji page has no skin tones or search | Later |
| 2026-11-11 | Korean word list loads in ~0.3s off the main thread; suggestions appear once it's ready | Watch on device |
| 2026-11-11 | "What I mean" can't be typed inside the keyboard (the keys type into the host app) | Done: keys type into settings fields (D31) |
| 2026-11-11 | No predictions yet: idle bar shows the profile summary (e.g. "Friend · 반말") | Done: Korean completions, Chinese candidates |
| 2026-11-11 | Missing Apple-keyboard touches: key popups, click sound, haptics, double-space full stop, autocorrect on space, caps lock | M1/M2 |
| 2026-11-11 | Settings changed inside the keyboard aren't saved without Full Access (App Group is read-only then) | By design; panel says so |
| 2026-11-11 | Hangul composition replaces the syllable with delete + insert (no marked text). Some apps limit `documentContextBeforeInput`, which also limits what gets checked | Watch on device |
| 2026-11-11 | Keyboard height grows when the correction card appears (`allowsSelfSizing`); not yet seen on screen | Check in Simulator |
| 2026-11-11 | Xcode on the Mac is at its first-launch licence screen; Simulator not installed yet | Waiting on Mancini |
| 2026-11-11 | Mac shell has no GitHub credentials, so the Mac copy is a snapshot | Re-copy after changes, or sign in to GitHub in Xcode (Settings › Accounts) and pull there |
| 2026-11-11 | Copying to the Mac: re-sending a file under the same name kept the old copy. Use a new file name each time (e.g. `lk-<commit>.tar.gz` in `~/Projects/_to_delete/`), extract in the Mac shell, then `cp -R` over `~/Projects/language-keyboard` | Workaround in use |
| 2026-11-11 | Computer use can't operate Xcode's Open panel (separate system process) or Finder while Mancini is in a full-screen app; opening the project needs one double-click from him | Ask him; afterwards Xcode lists it under recent projects |
| 2026-11-11 | App icon is a placeholder (한 key with an orange underline) | Replace before TestFlight if wanted |
| 2026-11-11 | Snapshot review: correction tip was cut off after one line; "Their gender" column squeezed to "T" | Fixed (text wraps, gender column 112pt) |
| 2026-11-11 | Settings panel shows down to "They are / Their gender"; the rest (Tone, What I mean) needs a scroll | Done: compact rows fit without scrolling (D29) |
| 2026-11-11 | `gh` CLI token in the cloud session is invalid | Use plain `curl` to `api.github.com` (with `Content-Type: application/json` for POSTs): reading runs and opening PRs both work |

---

## 10. Changelog

| Date | Change |
|---|---|
| 2026-11-10 | Scoped the keyboard: full keyboard, RIME, pause check, profiles, learning mode, rephrase. Mockup made |
| 2026-11-10 | Chose Claude (Ultra credits) over Gemini for now; Cloudflare Worker proxy; secrets set |
| 2026-11-11 | Proxy v1 live; Korean check verified (선생님한테 줬어 → 선생님께 드렸어); latency measured |
| 2026-11-11 | Blind test built (36 sentences); Haiku run complete; Sonnet bug found; proxy v2 written; this doc created |
| 2026-11-11 | Proxy v3: Gemini added (3.5 Flash-Lite, 3.8 Flash), Haiku-with-thinking option, no-change guard, stricter prompt. Blind test upgraded to 5 models. Repo `munchineh/language-keyboard` created and connected to Cloudflare Builds (path `/proxy`, preview builds off). GEMINI_API_KEY added |
| 2026-11-11 | v3 deployed via GitHub; all 5 models working; blind test run and published for judging |
| 2026-11-11 | Proxy 3.1: added gemini_lite31 and gemini_flash36 for speed comparison |
| 2026-11-11 | Proxy 3.2 prompt (chosen speech level is deliberate, honorific subjects, style-only edits are "stiff", Taiwan 儿化, keep content). Added `blind-test/score.py` (automatic scoring vs expected answers, multiple runs) |
| 2026-11-11 | Research: Siri AI Developer Preview (iOS 27.3) and Foundation Models; 3 integration proposals saved in docs/research |
| 2026-11-11 | Mac setup started remotely: Xcode download from App Store; folders granted |
| 2026-11-11 | Xcode installed; Apple Developer Program enrolled; ~12 GB freed on the Mac |
| 2026-11-11 | One rewrite at a time (D35); long-press applies whatever the card shows; settings panel: Done moved onto the Language row so "Rewrite as" fits. Proxy still returns both options; asking for one would save time and tokens (later) |
| 2026-11-11 | MVP to Mancini's feedback (D25–D34): two-tone icons, concentric card with blue highlights and arrow, suggestions bar, long-press return, emoji page, settings draft + Done, in-keyboard fields, Korean suggestions, pinyin input, explanation language. Proxy v3.3 (`explain`) waits for merge |
| 2026-11-11 | Light and dark mode: tuned light palette, live appearance updates, CI snapshots of 8 states in both modes |
| 2026-11-11 | Chat B: iOS app skeleton in `app/` (XcodeGen, companion app, keyboard extension to the mockup, Hangul composer, proxy client, tests) and `.github/workflows/ios.yml`. CI green on `macos-26`. Snapshot copied to `~/Projects/language-keyboard` on the Mac. Branch `ios-app` |
