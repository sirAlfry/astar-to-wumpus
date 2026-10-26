"""Disegna i grafici della presentazione a partire da risultati/risultati.csv."""
import csv, os, sys
try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
except ImportError:
    sys.exit("matplotlib non installato: pip install matplotlib")

os.chdir(os.path.dirname(os.path.abspath(__file__)))
righe = list(csv.DictReader(open("risultati/risultati.csv")))

def serie(alg, heur, campo):
    pts = [(int(r["ottimo_atteso"]), float(r[campo])) for r in righe
           if r["dominio"] == "puzzle8" and r["algoritmo"] == alg and r["euristica"] == heur and r["esito"] == "ok"]
    return zip(*sorted(pts)) if pts else ([], [])

STILI = [("astar", "manhattan", "A* Manhattan", "#1f5f8b", "-"),
         ("idastar", "manhattan", "IDA* Manhattan", "#c0392b", "-"),
         ("astar", "fuori_posto", "A* fuori posto", "#1f5f8b", "--"),
         ("idastar", "fuori_posto", "IDA* fuori posto", "#c0392b", "--"),
         ("astar", "zero", "A* h=0 (costo uniforme)", "#7f8c8d", ":")]
for campo, etichetta, nome in (("nodi_espansi", "nodi espansi", "puzzle8_nodi.png"),
                               ("tempo_cpu_s", "tempo CPU (s)", "puzzle8_tempo.png")):
    plt.figure(figsize=(7, 4.2))
    for alg, heur, lab, col, ls in STILI:
        xs, ys = serie(alg, heur, campo)
        plt.plot(list(xs), list(ys), ls, marker="o", ms=3, color=col, label=lab)
    plt.yscale("log"); plt.xlabel("lunghezza della soluzione ottima (mosse)")
    plt.ylabel(etichetta + " (scala log)"); plt.title(f"Puzzle dell'8: {etichetta}")
    plt.grid(alpha=.3); plt.legend(fontsize=8); plt.tight_layout()
    plt.savefig("risultati/" + nome, dpi=150); plt.close()

labs = sorted({r["istanza"] for r in righe if r["dominio"] == "labirinto"})
fig, ax = plt.subplots(figsize=(7, 4.2))
x = np.arange(len(labs))
for k, (alg, col, lab) in enumerate((("astar", "#1f5f8b", "A*"), ("idastar", "#c0392b", "IDA*"))):
    rr = [next(r for r in righe if r["istanza"] == l and r["algoritmo"] == alg) for l in labs]
    v = [int(r["nodi_espansi"]) for r in rr]
    ax.bar(x + (k - .5) * .38, v, .38, color=col, label=lab)
    for xi, r, vi in zip(x, rr, v):
        testo = "timeout" if r["esito"] == "timeout" else ("nessuna\nuscita" if r["esito"] == "nessuna_soluzione" else "")
        if testo:
            ax.text(xi + (k - .5) * .38, vi * 1.3, testo, ha="center", va="bottom", fontsize=7)
ax.set_yscale("log"); ax.set_ylim(top=1e8)
ax.set_xticks(x); ax.set_xticklabels([l.replace(".pl", "") for l in labs], rotation=20, fontsize=8)
ax.set_ylabel("nodi espansi (scala log)"); ax.set_title("Labirinti: nodi espansi"); ax.legend(loc="upper left")
ax.grid(axis="y", alpha=.3); plt.tight_layout(); plt.savefig("risultati/labirinti_nodi.png", dpi=150)
print("Grafici salvati in risultati/")
