"""Quanto sono affidabili i certainty factors dell'agente 3?

Per ogni volta che l'agente entra "a rischio" in una cella incerta, si
registra il pericolo stimato (CF) e se e' morto davvero. Raggruppando
per fasce di CF si confronta la stima con la frequenza reale di morte.

Uso:  python strumenti/calibrazione_cf.py [soglia_rischio]   (default 1.0 = rischia sempre)
"""
import collections, glob, os, re, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from esegui_headless import wumpus, silenzio

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
soglia = sys.argv[1] if len(sys.argv) > 1 else "1.0"
testo = open("agenti/agente-3/agent.clp").read()
testo = re.sub(r"\(parametro \(nome soglia-rischio\) \(valore [0-9.]+\)\)",
               f"(parametro (nome soglia-rischio) (valore {soglia}))", testo)
tmp = tempfile.NamedTemporaryFile("w", suffix=".clp", delete=False); tmp.write(testo); tmp.close()

MOSSE = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}
eventi = []          # (pericolo stimato, morto?)
for mappa in sorted(glob.glob("mappe/casuali/*.json")):
    mondo = wumpus.WumpusWorld.from_json(mappa); mondo.reset()
    with silenzio(True):
        ag = wumpus.ClipsAgent(tmp.name)
    for _ in range(1000):
        if mondo.done:
            break
        with silenzio(True):
            az = ag.run_and_get_action()
        bersagli = [(f["x"], f["y"], float(f["pericolo"])) for f in ag.env.facts()
                    if f.template.name == "bersaglio-rischio"]
        rischio = None
        if az in MOSSE and bersagli:
            bx, by, p = bersagli[0]
            dx, dy = MOSSE[az]
            if (mondo.x + dx, mondo.y + dy) == (bx, by):
                rischio = p
        res = mondo.step(az)
        if rischio is not None:
            eventi.append((rischio, mondo.dead))
        ag.clear_action_facts(); ag.assert_percept(res.obs); ag.update_time_counter(res.obs)

fasce = collections.OrderedDict((f, [0, 0]) for f in ("0-0.2", "0.2-0.3", "0.3-0.4", "0.4-0.6", "0.6-1"))
def fascia(p):
    return "0-0.2" if p < 0.2 else "0.2-0.3" if p < 0.3 else "0.3-0.4" if p < 0.4 else "0.4-0.6" if p < 0.6 else "0.6-1"
for p, morto in eventi:
    f = fasce[fascia(p)]; f[0] += 1; f[1] += morto
os.makedirs("risultati", exist_ok=True)
with open("risultati/calibrazione_cf.csv", "w") as out:
    out.write("fascia_cf,ingressi_a_rischio,morti,frequenza_morte\n")
    print(f"{'CF stimato':>10s} {'ingressi':>9s} {'morti':>6s} {'freq. reale':>11s}")
    for k, (n, m) in fasce.items():
        fr = m / n if n else 0
        print(f"{k:>10s} {n:9d} {m:6d} {fr:11.2f}")
        out.write(f"{k},{n},{m},{fr:.3f}\n")
print(f"totale ingressi a rischio: {len(eventi)}")
