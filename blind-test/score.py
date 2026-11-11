import json, urllib.request, urllib.error, sys, time
from concurrent.futures import ThreadPoolExecutor
EP="https://keyboard-proxy.mancini-tan.workers.dev/check"; TOK=sys.argv[1]
items=json.load(open("sentences.json",encoding="utf-8"))
# expected: ("ok",) or ("fix", must_contain[], must_not_contain[])
E={1:("fix",["께","드렸"],[]),2:("fix",["오셨"],[]),3:("fix",[],["있어?"]),4:("fix",["갑니다"],[]),5:("ok",),6:("ok",),7:("ok",),8:("ok",),
9:("fix",["먹어서"],[]),10:("fix",["잤어"],["잤었"]),11:("ok",),12:("fix",[],[]),13:("ok",),14:("fix",["누나"],[]),15:("ok",),16:("fix",["좋아"],["습니다"]),
17:("ok",),18:("fix",["안 해서"],[]),19:("ok",),20:("ok",),21:("fix",["니다"],[]),22:("ok",),23:("fix",["께","드릴"],[]),24:("fix",["OST"],[]),
25:("fix",[],["东西了"]),26:("fix",["跑得"],[]),27:("ok",),28:("ok",),29:("fix",["一本书"],[]),30:("ok",),31:("ok",),32:("fix",[],["儿","兒"]),
33:("fix",[],["兴趣在"]),34:("fix",[],["了过"]),35:("fix",["再去","一次"],[]),36:("ok",)}
def call(a):
    item,m=a; p=dict(item); p.pop("tests",None); p["model"]=m
    req=urllib.request.Request(EP,data=json.dumps(p,ensure_ascii=False).encode(),headers={"Authorization":"Bearer "+TOK,"Content-Type":"application/json","User-Agent":"score"},method="POST")
    tries=0
    while tries<2:
        try:
            with urllib.request.urlopen(req,timeout=25) as r: return json.loads(r.read())
        except urllib.error.HTTPError as e:
            if e.code==429: time.sleep(int(e.headers.get("retry-after") or 60)+1); continue  # proxy rate limit
            err=str(e)
        except Exception as e: err=str(e)
        tries+=1; time.sleep(1)
    return {"error":err}
def good(i,r):
    e=E[i]
    if "error" in r: return False
    if e[0]=="ok": return r.get("status")=="ok"
    if r.get("status")!="fix": return False
    c=r.get("corrected","")
    return all(x in c for x in e[1]) and not any(x in c for x in e[2])
models=sys.argv[2].split(","); runs=int(sys.argv[3])
res={m:[] for m in models}
for m in models:
    for k in range(runs):
        with ThreadPoolExecutor(6) as ex: out=list(ex.map(call,[(it,m) for it in items]))
        res[m].append([good(i+1,r) for i,r in enumerate(out)])
print(f"{'model':12} " + " ".join(f"run{k+1}" for k in range(runs)) + "  avg   always-right  flaky  always-wrong")
for m in models:
    scores=[sum(r) for r in res[m]]
    per=[sum(res[m][k][i] for k in range(runs)) for i in range(36)]
    print(f"{m:12} " + " ".join(f"{s:>4}" for s in scores) + f"  {sum(scores)/runs:4.1f}   {sum(p==runs for p in per):>6}       {sum(0<p<runs for p in per):>3}   {sum(p==0 for p in per):>5}")
    print("   always wrong: ", [i+1 for i,p in enumerate(per) if p==0])
    print("   flaky:        ", [i+1 for i,p in enumerate(per) if 0<p<runs])
