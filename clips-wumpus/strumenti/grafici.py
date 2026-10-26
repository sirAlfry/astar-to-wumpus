"""Grafici per la presentazione, dai CSV in risultati/."""
import csv, os, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "risultati"))
rie = list(csv.DictReader(open("riepilogo.csv")))
COL = {"1-prudente": "#95a5a6", "2-logico": "#1f5f8b", "3-stratega": "#c0392b"}

# 1. confronto dei tre agenti
base = [r for r in rie if r["agente"] in COL]
fig, ax = plt.subplots(1, 3, figsize=(10, 3.4))
for k, (campo, tit) in enumerate((("premio_medio", "premio medio"), ("oro_%", "oro preso (%)"),
                                   ("pozzi_giusti_medi", "pozzi dichiarati giusti (media)"))):
    v = [float(r[campo]) for r in base]
    b = ax[k].bar([r["agente"] for r in base], v, color=[COL[r["agente"]] for r in base])
    ax[k].bar_label(b, fmt="%.1f", fontsize=8)
    ax[k].set_title(tit, fontsize=10); ax[k].tick_params(axis="x", labelsize=8)
    ax[k].spines[["top", "right"]].set_visible(False)
fig.suptitle("100 mappe casuali: nessun agente muore, ma premio e oro crescono con la KB", fontsize=10)
plt.tight_layout(); plt.savefig("confronto_agenti.png", dpi=150); plt.close()

# 2. soglia di rischio dell'agente 3
var = [r for r in rie if "rischio<=" in r["agente"]]
if var:
    s = [float(r["agente"].split("<=")[1]) for r in var]
    fig, ax1 = plt.subplots(figsize=(6.5, 3.6))
    ax1.plot(s, [float(r["premio_medio"]) for r in var], "o-", color="#1f5f8b", label="premio medio")
    ax1.set_xlabel("soglia di rischio (pericolo stimato massimo accettato)"); ax1.set_ylabel("premio medio", color="#1f5f8b")
    ax2 = ax1.twinx()
    ax2.plot(s, [float(r["morti_%"]) for r in var], "s--", color="#c0392b", label="morti %")
    ax2.set_ylabel("morti (%)", color="#c0392b")
    ax1.axvline(0.3, color="gray", ls=":", lw=1); ax1.text(0.31, ax1.get_ylim()[1] - 1, "default 0.3", fontsize=8, color="gray", va="top")
    ax1.set_title("Agente 3: prudenza contro audacia", fontsize=10)
    plt.tight_layout(); plt.savefig("soglia_rischio.png", dpi=150); plt.close()

# 3. calibrazione dei certainty factors
if os.path.exists("calibrazione_cf.csv"):
    cal = [r for r in csv.DictReader(open("calibrazione_cf.csv")) if int(r["ingressi_a_rischio"]) > 0]
    centri = {"0-0.2": .1, "0.2-0.3": .25, "0.3-0.4": .35, "0.4-0.6": .5, "0.6-1": .8}
    x = [centri[r["fascia_cf"]] for r in cal]; y = [float(r["frequenza_morte"]) for r in cal]
    n = [int(r["ingressi_a_rischio"]) for r in cal]
    plt.figure(figsize=(4.8, 3.8))
    plt.plot([0, 1], [0, 1], ":", color="gray", label="stima perfetta")
    plt.scatter(x, y, s=[20 + 3 * k for k in n], color="#c0392b", zorder=3, label="osservato (area = n. ingressi)")
    for xi, yi, k in zip(x, y, n):
        plt.annotate(f"n={k}", (xi, yi), textcoords="offset points", xytext=(6, -10), fontsize=7)
    plt.xlabel("pericolo stimato con i CF"); plt.ylabel("frequenza reale di morte")
    plt.xlim(0, 1); plt.ylim(0, 1); plt.legend(fontsize=7, loc="upper left")
    plt.title("I CF sono una stima (prudente) del rischio", fontsize=10)
    plt.tight_layout(); plt.savefig("calibrazione_cf.png", dpi=150); plt.close()
print("grafici salvati in risultati/")
