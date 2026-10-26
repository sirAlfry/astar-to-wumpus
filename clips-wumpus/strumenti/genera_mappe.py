"""Genera mappe casuali per gli esperimenti statistici.

Uso:  python strumenti/genera_mappe.py [quante] [seed]
      (default 100 mappe, seed 2026) -> mappe/casuali/casuale_NNN.json

Regole (le stesse del simulatore): partenza (0,0) libera, oro, pozzi,
muri e Wumpus non si sovrappongono. Dimensioni da 5x5 a 8x8, circa 10%
di muri e 12% di pozzi, un Wumpus. Le mappe NON sono garantite risolvibili
in sicurezza: come nel gioco vero, a volte l'oro e' irraggiungibile senza
rischiare, ed e' proprio li' che si vede la differenza tra gli agenti.
"""
import json, os, random, sys

def genera(rnd):
    w, h = rnd.randint(5, 8), rnd.randint(5, 8)
    celle = [(x, y) for x in range(w) for y in range(h) if (x, y) != (0, 0)]
    rnd.shuffle(celle)
    n_muri = round(0.10 * w * h)
    n_pozzi = max(1, round(0.12 * w * h))
    muri = celle[:n_muri]
    pozzi = celle[n_muri:n_muri + n_pozzi]
    wumpus = celle[n_muri + n_pozzi]
    oro = celle[n_muri + n_pozzi + 1]
    return {"width": w, "height": h, "start": [0, 0],
            "walls": [list(c) for c in muri], "pits": [list(c) for c in pozzi],
            "wumpus": list(wumpus), "gold": list(oro),
            "max_steps": 4 * w * h, "step_cost": -1.0, "death_cost": -100.0,
            "grab_reward": 100.0, "end_on_grab": True}

if __name__ == "__main__":
    quante = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    seed = int(sys.argv[2]) if len(sys.argv) > 2 else 2026
    rnd = random.Random(seed)
    cartella = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mappe", "casuali")
    os.makedirs(cartella, exist_ok=True)
    for i in range(1, quante + 1):
        with open(os.path.join(cartella, f"casuale_{i:03d}.json"), "w") as f:
            json.dump(genera(rnd), f)
    print(f"{quante} mappe in mappe/casuali/")
