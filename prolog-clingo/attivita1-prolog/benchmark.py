"""Esegue A* e IDA* su tutte le istanze di test e salva le misure.

Uso (dalla cartella attivita1-prolog, con swipl nel PATH):
    python benchmark.py               timeout di default 60 s per esecuzione
    python benchmark.py 120           timeout personalizzato
    python grafici.py                 rifa' solo i grafici dal CSV

Produce:
    risultati/risultati.csv   una riga per (algoritmo, istanza, euristica)
    risultati/*.png           grafici per la presentazione (se c'e' matplotlib)

Ogni esecuzione gira in un processo swipl separato, cosi' le misure non
sono falsate da memoria o garbage collection delle esecuzioni precedenti.
La colonna "ottimo_ok" confronta il costo trovato con la lunghezza
ottima calcolata da una BFS indipendente (test/ottimi_attesi.csv).
"""
import csv, glob, os, subprocess, sys

TIMEOUT = int(sys.argv[1]) if len(sys.argv) > 1 else 60
QUI = os.path.dirname(os.path.abspath(__file__))
os.chdir(QUI)

attesi = {}
with open("test/ottimi_attesi.csv") as f:
    for r in csv.DictReader(f):
        attesi[os.path.basename(r["istanza"])] = r["ottimo"]

prove = []
for ist in sorted(glob.glob("test/labirinto/*.pl")):
    for alg in ("astar", "idastar"):
        prove.append((alg, "labirinto", ist, "manhattan"))
for ist in sorted(glob.glob("test/puzzle8/p*.pl")):
    for alg, heur in (("astar", "manhattan"), ("idastar", "manhattan"),
                      ("astar", "fuori_posto"), ("idastar", "fuori_posto"),
                      ("astar", "zero")):
        prove.append((alg, "puzzle8", ist, heur))

CAMPI = ["algoritmo", "dominio", "istanza", "euristica", "esito", "costo",
         "nodi_espansi", "iterazioni", "nodi_in_memoria", "tempo_cpu_s", "azioni"]
os.makedirs("risultati", exist_ok=True)
righe = []
for i, (alg, dom, ist, heur) in enumerate(prove, 1):
    cmd = ["swipl", "esegui.pl", alg, dom, ist, heur, str(TIMEOUT)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout.strip().splitlines()
    riga = next((l for l in reversed(out) if l.startswith(alg + ",")), None)
    if riga is None:
        print("ERRORE su", cmd); continue
    valori = riga.split(",", len(CAMPI) - 1)
    r = dict(zip(CAMPI, valori))
    atteso = attesi.get(os.path.basename(ist), "")
    r["ottimo_atteso"] = atteso
    if r["esito"] == "ok":
        r["ottimo_ok"] = "si" if r["costo"] == atteso else "NO"
    elif r["esito"] == "nessuna_soluzione":
        r["ottimo_ok"] = "si" if atteso == "" else "NO"
    else:
        r["ottimo_ok"] = ""
    righe.append(r)
    print(f"[{i:3d}/{len(prove)}] {alg:8s} {os.path.basename(ist):26s} {heur:12s} "
          f"{r['esito']:18s} costo={r['costo']:>3s} nodi={r['nodi_espansi']:>9s} "
          f"mem={r['nodi_in_memoria']:>7s} t={float(r['tempo_cpu_s']):8.3f}s  {r['ottimo_ok']}", flush=True)

with open("risultati/risultati.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=CAMPI[:-1] + ["ottimo_atteso", "ottimo_ok", "azioni"])
    w.writeheader()
    w.writerows(righe)
print("Salvato risultati/risultati.csv")

# Grafici per la presentazione (script separato: si puo' rilanciare da solo)
subprocess.run([sys.executable, "grafici.py"])
