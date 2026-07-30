import json, subprocess, sys, os, time, concurrent.futures as cf

CAP = 150  # секунд на запрос; решение о вызове скилла принимается в первые секунды

def triggered(q):
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
    p = subprocess.Popen(["claude","-p",q,"--output-format","stream-json","--verbose",
                          "--include-partial-messages","--model","claude-opus-5"],
                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                         stdin=subprocess.DEVNULL, text=True, env=env)
    t0, hit = time.time(), False
    try:
        for line in p.stdout:
            try: ev = json.loads(line)
            except Exception: continue
            blob = json.dumps(ev, ensure_ascii=False)
            if '"name":"Skill"' in blob or '"name": "Skill"' in blob:
                if "optimize-harness" in blob:
                    hit = True; break
            if time.time() - t0 > CAP: break
    finally:
        p.kill(); p.wait()
    return hit

evals = json.load(open(sys.argv[1]))
with cf.ThreadPoolExecutor(max_workers=7) as ex:
    res = list(ex.map(lambda e: (e, triggered(e["query"])), evals))
tp=fp=tn=fn=0
for e, t in res:
    exp = e["should_trigger"]
    ok = t == exp
    if exp and t: tp+=1
    elif exp and not t: fn+=1
    elif not exp and t: fp+=1
    else: tn+=1
    print(f"{'PASS' if ok else 'FAIL'}  fired={str(t):5} expect={str(exp):5} {e['query'][:58]}")
print(f"\nrecall {tp}/{tp+fn}   precision {tp}/{tp+fp or 1}   accuracy {(tp+tn)}/{len(res)}")
