"""L'oracolo: quanto si potrebbe ottenere AL MASSIMO senza mai morire?

Un agente che vede tutta la mappa (pozzi, Wumpus, muri) e non sbaglia mai
puo' ottenere, senza rischiare:
  - l'oro (+100) se esiste un cammino dalla partenza all'oro che non passa
    da pozzi, Wumpus o muri;
  - +25 per ogni pozzo ADIACENTE a una cella che puo' raggiungere
    (per dichiararlo bisogna stargli accanto).
Nessun agente reale che non muore puo' fare di meglio: e' un LIMITE
SUPERIORE. Confrontarlo con i risultati degli agenti dice quanto della
differenza dipende dagli agenti e quanto dalla mappa ("l'oro non si puo'
proprio prendere").

Uso (dopo strumenti/esperimenti.py):  python strumenti/oracolo.py
Produce risultati/oracolo.csv e stampa il confronto.
"""
import collections, csv, glob, json, os

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

def oracolo(fn):
    d = json.load(open(fn))
    W, H = d["width"], d["height"]
    muri = {tuple(c) for c in d["walls"]}
    pozzi = {tuple(c) for c in d["pits"]}
    wumpus = tuple(d["wumpus"]) if d.get("wumpus") else None
    vietate = muri | pozzi | ({wumpus} if wumpus else set())
    start = tuple(d.get("start", [0, 0]))
    visti, coda = {start}, collections.deque([start])
    while coda:
        x, y = coda.popleft()
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= n[0] < W and 0 <= n[1] < H and n not in vietate and n not in visti:
                visti.add(n); coda.append(n)
    oro = tuple(d["gold"]) in visti
    dichiarabili = sum(1 for (px, py) in pozzi
                       if any(v in visti for v in ((px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1))))
    return oro, dichiarabili, 100 * oro + 25 * dichiarabili

righe = {}
for fn in sorted(glob.glob("mappe/casuali/*.json")):
    righe[os.path.basename(fn)] = oracolo(fn)
with open("risultati/oracolo.csv", "w", newline="") as f:
    w = csv.writer(f); w.writerow(["mappa", "oro_raggiungibile", "pozzi_dichiarabili", "premio_massimo"])
    for m, (o, p, pr) in righe.items():
        w.writerow([m, o, p, pr])

n = len(righe)
oro_max = sum(o for o, _, _ in righe.values())
pozzi_max = sum(p for _, p, _ in righe.values())
premio_max = sum(pr for _, _, pr in righe.values()) / n
print(f"ORACOLO (limite superiore senza morire) su {n} mappe:")
print(f"  oro raggiungibile senza passare da pericoli: {oro_max}/{n} mappe ({100*oro_max/n:.0f}%)")
print(f"  pozzi dichiarabili: {pozzi_max/n:.2f} per mappa   premio massimo medio: {premio_max:.1f}\n")

ris = list(csv.DictReader(open("risultati/risultati_casuali.csv")))
print(f"{'agente':28s} {'premio':>7s} {'% del max':>9s} {'oro':>5s} {'oro/raggiung.':>13s} {'pozzi/dichiar.':>14s}")
riepilogo = []
for a in dict.fromkeys(r["agente"] for r in ris):
    rr = [r for r in ris if r["agente"] == a]
    premio = sum(float(r["premio"]) for r in rr) / len(rr)
    oro = sum(r["oro"] == "True" for r in rr)
    oro_su_ragg = sum(r["oro"] == "True" for r in rr if righe[r["mappa"]][0])
    pozzi = sum(int(r["pozzi_giusti"]) for r in rr)
    morti = sum(r["morto"] == "True" for r in rr)
    print(f"{a:28s} {premio:7.1f} {100*premio/premio_max:8.0f}% {oro:5d} {oro_su_ragg:6d}/{oro_max:<6d} {pozzi:7d}/{pozzi_max:<6d}"
          + (f"  ({morti} morti)" if morti else ""))
    riepilogo.append({"agente": a, "premio_medio": round(premio, 2), "percentuale_del_massimo": round(100 * premio / premio_max, 1),
                      "oro_su_raggiungibili": f"{oro_su_ragg}/{oro_max}", "pozzi_su_dichiarabili": f"{pozzi}/{pozzi_max}", "morti": morti})
with open("risultati/oracolo_confronto.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(riepilogo[0])); w.writeheader(); w.writerows(riepilogo)
