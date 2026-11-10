# Language Keyboard

iOS keyboard that checks Korean and Chinese (later German and English) as you text, with corrections, natural rephrasing and a learning mode.

| Folder | What's in it |
|---|---|
| `docs/PROJECT.md` | Living project doc: spec, decisions, roadmap, issues. **Start here.** |
| `proxy/` | Cloudflare Worker `keyboard-proxy` (Claude + Gemini). Deploys automatically from `main` |
| `blind-test/` | Model comparison script and test sentences |

Secrets are never committed. They live in Cloudflare › keyboard-proxy › Settings › Variables and Secrets.
