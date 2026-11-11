#!/usr/bin/env python3
"""Blind test: several models through keyboard-proxy (Claude and Gemini).

Usage (Mac Terminal, in the folder with this file and sentences.json):
    python3 blind_test.py
It asks for your APP_TOKEN (hidden), runs every sentence through both models,
and writes results.html. Open it, pick the better answer for each sentence,
then press "Reveal" at the bottom.
"""
import getpass, html, json, os, random, sys, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

ENDPOINT = os.environ.get("KP_ENDPOINT", "https://keyboard-proxy.mancini-tan.workers.dev/check")
MODELS = os.environ.get("KP_MODELS", "haiku,haiku_think,sonnet,gemini_lite,gemini_flash").split(",")
HERE = os.path.dirname(os.path.abspath(__file__))


def call(token, item, model):
    payload = dict(item)
    payload.pop("tests", None)
    payload["model"] = model
    req = urllib.request.Request(
        ENDPOINT,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json",
                 "User-Agent": "keyboard-blind-test/1.0"},
        method="POST",
    )
    attempt = 0
    while attempt < 2:
        start = time.time()
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                body = json.loads(r.read().decode("utf-8"))
                return {"result": body, "total_ms": int((time.time() - start) * 1000),
                        "model_ms": int(r.headers.get("x-latency-ms") or 0)}
        except urllib.error.HTTPError as e:
            err = f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:200]}"
            if e.code == 401:
                sys.exit("Unauthorized: the APP_TOKEN doesn't match the Worker secret.")
            if e.code == 429:  # proxy rate limit (30/min per token): wait it out, don't count it
                time.sleep(int(e.headers.get("retry-after") or 60) + 1)
                continue
        except Exception as e:  # network hiccup
            err = str(e)
        attempt += 1
        time.sleep(1)
    return {"result": {"error": err}, "total_ms": 0, "model_ms": 0}


def render_answer(r):
    res = r["result"]
    if "error" in res:
        return f'<div class="err">Error: {html.escape(res["error"])}</div>'
    if res.get("status") == "ok":
        stiff = '<span class="pill">flagged stiff</span>' if res.get("stiff") else ""
        return f'<div class="ok">✓ Looks good {stiff}</div>'
    tip = html.escape(res.get("tip", ""))
    corrected = html.escape(res.get("corrected", ""))
    stiff = '<span class="pill">flagged stiff</span>' if res.get("stiff") else ""
    return f'<div class="fix"><div class="label">Suggests</div><div class="corr">{corrected}</div><div class="tip">{tip}</div>{stiff}</div>'


def profile_text(p):
    return " · ".join(f"{k.replace('_', ' ')}: {v}" for k, v in p.items())


def main():
    with open(os.path.join(HERE, "sentences.json"), encoding="utf-8") as f:
        items = json.load(f)
    token = os.environ.get("KP_TOKEN") or getpass.getpass("APP_TOKEN (hidden): ").strip()
    print(f"Running {len(items)} sentences × 2 models…")

    def run(i_item):
        i, item = i_item
        out = {m: call(token, item, m) for m in MODELS}
        print(f"  {i + 1}/{len(items)} done")
        return out

    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(run, enumerate(items)))

    letters = "ABCDEFGH"
    cards, key = [], []
    for i, (item, res) in enumerate(zip(items, results)):
        order = MODELS[:]
        random.shuffle(order)
        key.append({"order": order,
                    "ms": {m: [res[m]["model_ms"], res[m]["total_ms"]] for m in MODELS},
                    "err": {m: "error" in res[m]["result"] for m in MODELS}})
        ctx = f'<div class="ctx">Replying to: {html.escape(item["context"])}</div>' if item.get("context") else ""
        answers = "".join(
            f'<div class="ans"><div class="tag">{letters[j]} <span class="reveal" id="r{i}_{j}"></span></div>{render_answer(res[m])}</div>'
            for j, m in enumerate(order))
        buttons = "".join(f'<button type="button" data-i="{i}" data-v="{letters[j]}">{letters[j]} best</button>' for j in range(len(order)))
        cards.append(f'''
<section class="card" id="c{i}">
  <div class="meta"><span class="lang">{"한국어" if item["lang"] == "ko" else "中文"}</span> #{i + 1} · {html.escape(item.get("tests", ""))}</div>
  {ctx}
  <div class="text">{html.escape(item["text"])}</div>
  <div class="profile">{html.escape(profile_text(item.get("profile", {})))}</div>
  <div class="answers">{answers}</div>
  <div class="vote" role="group" aria-label="Best answer for sentence {i + 1}">
    {buttons}
    <button type="button" data-i="{i}" data-v="tie">All fine</button>
    <button type="button" data-i="{i}" data-v="bad">All wrong</button>
  </div>
</section>''')

    page = TEMPLATE.replace("__CARDS__", "".join(cards)).replace("__KEY__", json.dumps(key)).replace("__N__", str(len(items)))
    out = os.path.join(HERE, "results.html")
    with open(out, "w", encoding="utf-8") as f:
        f.write(page)
    print(f"\nDone. Open results.html (in Finder, or run: open \"{out}\")")


TEMPLATE = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Keyboard blind test</title>
<style>
body{margin:0;background:#111;color:#f2f2f2;font:16px/1.45 -apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo","PingFang SC",system-ui,sans-serif}
main{max-width:760px;margin:0 auto;padding:24px 16px 120px}
h1{font-size:24px;margin:0 0 4px}.sub{color:#b5b5b5;margin:0 0 20px}
.card{background:#1c1c1e;border-radius:16px;padding:16px;margin:0 0 14px}
.meta{font-size:13px;color:#b5b5b5}.lang{background:#2c2c2e;border-radius:6px;padding:1px 6px;margin-right:4px;color:#f2f2f2}
.ctx{font-size:14px;color:#b5b5b5;margin-top:8px}.text{font-size:20px;margin:6px 0 4px}
.profile{font-size:13px;color:#9a9a9a;margin-bottom:12px}
.answers{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:10px}
@media (max-width:560px){.answers{grid-template-columns:1fr}}
.ans{background:#2c2c2e;border-radius:12px;padding:12px}.tag{font-weight:700;margin-bottom:6px}
.reveal{font-weight:400;color:#ffb340;margin-left:6px;font-size:13px}
.ok{color:#9fd0ff}.label{font-size:12px;color:#b5b5b5}.corr{font-size:17px;margin:2px 0 6px}.tip{font-size:14px;color:#d0d0d0}
.pill{display:inline-block;font-size:12px;background:#3a3a3c;border-radius:8px;padding:1px 8px;margin-top:6px;color:#f2f2f2}
.err{color:#ffb340}
.vote{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}
.vote button{min-height:44px;border:0;border-radius:22px;padding:0 16px;background:#3a3a3c;color:#f2f2f2;font:inherit;font-size:15px;cursor:pointer}
.vote button[aria-pressed="true"]{background:#0a84ff;color:#fff;font-weight:600}
#bar{position:fixed;left:0;right:0;bottom:0;background:#1c1c1ecc;backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);padding:12px 16px;display:flex;gap:12px;align-items:center;justify-content:center}
#bar button{min-height:44px;border:0;border-radius:22px;padding:0 20px;background:#0a84ff;color:#fff;font:inherit;font-weight:600;cursor:pointer}
#summary{background:#1c1c1e;border-radius:16px;padding:16px;margin-top:20px;display:none}
table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:6px 4px;border-bottom:1px solid #333}
</style></head><body><main>
<h1>Keyboard blind test</h1>
<p class="sub">Each sentence was checked by several models, shown as A, B, C… in random order. Pick the best answer, then press Reveal.</p>
__CARDS__
<div id="summary" aria-live="polite"></div>
</main>
<div id="bar"><span id="count">0 / __N__ judged</span><button type="button" id="revealBtn">Reveal</button></div>
<script>
const KEY = __KEY__;
const votes = {};
try { Object.assign(votes, JSON.parse(localStorage.getItem("kb-blind-votes-v3") || "{}")); } catch (e) {}
function paint(){
  document.querySelectorAll(".vote button").forEach(b => b.setAttribute("aria-pressed", votes[b.dataset.i] === b.dataset.v ? "true" : "false"));
  document.getElementById("count").textContent = Object.keys(votes).length + " / " + KEY.length + " judged";
}
document.querySelectorAll(".vote button").forEach(b => b.addEventListener("click", () => {
  votes[b.dataset.i] = b.dataset.v; paint();
  try { localStorage.setItem("kb-blind-votes-v3", JSON.stringify(votes)); } catch (e) {}
}));
document.getElementById("revealBtn").addEventListener("click", () => {
  const L = "ABCDEFGH";
  const models = KEY[0].order.slice().sort();
  const wins = {}, ms = {}, errs = {};
  models.forEach(m => { wins[m] = 0; ms[m] = []; errs[m] = 0; });
  let tie = 0, bad = 0;
  KEY.forEach((k, i) => {
    k.order.forEach((m, j) => {
      document.getElementById("r" + i + "_" + j).textContent = m + " · " + k.ms[m][0] + " ms";
      if (k.err[m]) errs[m]++; else if (k.ms[m][0]) ms[m].push(k.ms[m][0]);
    });
    const v = votes[i];
    if (v && L.includes(v)) wins[k.order[L.indexOf(v)]]++; else if (v === "tie") tie++; else if (v === "bad") bad++;
  });
  const avg = a => a.length ? Math.round(a.reduce((x, y) => x + y, 0) / a.length) : 0;
  const s = document.getElementById("summary");
  s.style.display = "block";
  s.innerHTML = "<h2>Results</h2><table><tr><th>Model</th><th>Best picks</th><th>Avg model time</th><th>Errors</th></tr>" +
    models.map(m => "<tr><td>" + m + "</td><td>" + wins[m] + "</td><td>" + avg(ms[m]) + " ms</td><td>" + errs[m] + "</td></tr>").join("") +
    "</table><p>All fine: " + tie + " · All wrong: " + bad + "</p>";
  s.scrollIntoView({behavior: "smooth"});
});
paint();
</script></body></html>"""

if __name__ == "__main__":
    main()
