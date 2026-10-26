"""Disegna la mappa e il percorso di un agente (PNG per le slide).

Uso: python strumenti/disegna_partita.py mappe/m01_dietro_i_pozzi.json agenti/agente-3/agent.clp risultati/partita_m01_agente3.png
"""
import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from esegui_headless import esegui
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

mappa, agente, out = sys.argv[1:4]
d = json.load(open(mappa))
r = esegui(mappa, agente)
W, H = d["width"], d["height"]
fig, ax = plt.subplots(figsize=(W * 0.9, H * 0.9))
for x in range(W):
    for y in range(H):
        ax.add_patch(Rectangle((x, y), 1, 1, fill=False, ec="#c8cfd6", lw=1))
for x, y in d["walls"]:
    ax.add_patch(Rectangle((x, y), 1, 1, color="#2b3440"))
def testo(c, s, col):
    ax.text(c[0] + .5, c[1] + .5, s, ha="center", va="center", fontsize=20, fontweight="bold", color=col)
for p in d["pits"]:
    testo(p, "P", "#1e2a36")
testo(d["wumpus"], "W", "#b03a2e")
testo(d["gold"], "$", "#c48a00")
ax.add_patch(Rectangle((0, 0), 1, 1, color="#dbe8f2"))
# percorso
x, y = d.get("start", [0, 0])
pts = [(x, y)]
for a in r["azioni"].split():
    dx, dy = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}.get(a, (0, 0))
    nx, ny = x + dx, y + dy
    if (dx or dy) and 0 <= nx < W and 0 <= ny < H and [nx, ny] not in d["walls"]:
        x, y = nx, ny
        pts.append((x, y))
xs = [p[0] + .5 for p in pts]; ys = [p[1] + .5 for p in pts]
ax.plot(xs, ys, "-", color="#1f5f8b", lw=3, alpha=.75)
ax.plot(xs[-1], ys[-1], "o", color="#1f5f8b", ms=14)
ax.set_xlim(0, W); ax.set_ylim(H, 0); ax.set_aspect("equal"); ax.axis("off")
ax.set_title(f"premio {r['premio']:.0f} · {r['esito']} · {r['passi']} passi", fontsize=14)
plt.tight_layout(); plt.savefig(out, dpi=130); print(r["esito"], r["premio"])
