"""Genera le istanze di test per labirinto e puzzle dell'8.

Uso:  python genera_test.py        (dalla cartella test/)

Le istanze sono deterministiche (seed fisso), quindi rigenerandole si
ottengono sempre gli stessi file. Lo script verifica anche, con una BFS
indipendente dal codice Prolog, la lunghezza del cammino ottimo: serve
come controllo incrociato dei risultati di A* e IDA*.
"""
import collections, random, re, os

ATTESI = []          # (file, lunghezza ottima attesa o None se irrisolvibile)

# ----------------------------------------------------------------- labirinti
def scrivi_lab(nome, descr, R, C, start, uscite, muri):
    with open(f"labirinto/{nome}.pl", "w") as f:
        f.write(f"% {nome}.pl\n")
        for d in descr:
            f.write(f"% {d}\n")
        f.write(f"\nnum_righe({R}).\nnum_col({C}).\n")
        f.write(f"iniziale(pos({start[0]},{start[1]})).\n")
        for e in uscite:
            f.write(f"finale(pos({e[0]},{e[1]})).\n")
        f.write("\n")
        for (r, c) in sorted(muri):
            f.write(f"occupata(pos({r},{c})).\n")
    d = bfs(R, C, start, muri)
    dist = [d.get(e) for e in uscite]
    raggiungibili = [x for x in dist if x is not None]
    ATTESI.append((f"labirinto/{nome}.pl", min(raggiungibili) if raggiungibili else None))
    print(f"{nome:28s} {R}x{C}  muri={len(muri):4d}  distanze uscite={dist}")

def leggi_lab(fn):
    s = open(fn).read()
    R = int(re.search(r"num_righe\((\d+)\)", s).group(1))
    C = int(re.search(r"num_col\((\d+)\)", s).group(1))
    st = tuple(map(int, re.search(r"iniziale\(pos\((\d+),(\d+)\)\)", s).groups()))
    ex = [tuple(map(int, m)) for m in re.findall(r"finale\(pos\((\d+),(\d+)\)\)", s)]
    w = {tuple(map(int, m)) for m in re.findall(r"occupata\(pos\((\d+),(\d+)\)\)", s)}
    return R, C, st, ex, w

def bfs(R, C, st, muri):
    d = {st: 0}
    q = collections.deque([st])
    while q:
        r, c = q.popleft()
        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (r + dr, c + dc)
            if 1 <= n[0] <= R and 1 <= n[1] <= C and n not in muri and n not in d:
                d[n] = d[(r, c)] + 1
                q.append(n)
    return d

def labirinti():
    os.makedirs("labirinto", exist_ok=True)
    # 1. labirinto piccolo disegnato a mano, due uscite
    righe = ["S.........",
             ".####.###.",
             ".#......#.",
             ".#.####.#.",
             "...#.E#...",
             "##.#..####",
             "...#......",
             ".###.####.",
             ".....#....",
             "####...#.E"]
    muri = {(r + 1, c + 1) for r, riga in enumerate(righe) for c, ch in enumerate(riga) if ch == "#"}
    uscite = [(r + 1, c + 1) for r, riga in enumerate(righe) for c, ch in enumerate(riga) if ch == "E"]
    scrivi_lab("lab1_piccolo", ["Labirinto 10x10 disegnato a mano, con due uscite: (5,6) al centro e (10,10) in fondo."],
               10, 10, (1, 1), uscite, muri)
    # 2. labirinto grande 20x40 "a corridoi" generato con una visita in profondita'
    #    casuale (labirinto perfetto), poi con il 15% di pareti abbattute per creare
    #    cicli. Una seconda uscita in (1,40) e' murata: non raggiungibile.
    rnd = random.Random(42)
    R, C = 20, 40
    muri = {(r, c) for r in range(1, R + 1) for c in range(1, C + 1)}
    celle = [(r, c) for r in range(1, R, 2) for c in range(1, C, 2)]      # celle dispari
    visitate, pila = {(1, 1)}, [(1, 1)]
    muri.discard((1, 1))
    while pila:
        r, c = pila[-1]
        vicini = [(r + dr, c + dc) for dr, dc in ((2, 0), (-2, 0), (0, 2), (0, -2))
                  if 1 <= r + dr < R and 1 <= c + dc < C and (r + dr, c + dc) not in visitate]
        if not vicini:
            pila.pop(); continue
        nr, nc = rnd.choice(vicini)
        muri.discard(((r + nr) // 2, (c + nc) // 2)); muri.discard((nr, nc))
        visitate.add((nr, nc)); pila.append((nr, nc))
    pareti = [(r, c) for (r, c) in muri if 1 < r < R - 1 and 1 < c < C - 1 and
              ((r % 2 == 1) != (c % 2 == 1))]
    for p in rnd.sample(sorted(pareti), len(pareti) * 15 // 100):
        muri.discard(p)
    muri.discard((R - 1, C - 1))
    muri.discard((1, C)); muri.add((2, C)); muri.add((1, C - 1))     # uscita (1,40) murata
    scrivi_lab("lab2_grande", ["Labirinto 20x40 a corridoi, generato (DFS casuale, seed 42) con il 15% di pareti",
               "abbattute per creare cicli. Uscita (19,39) raggiungibile; uscita (1,40) murata."],
               R, C, (1, 1), [(R - 1, C - 1), (1, C)], muri)
    # 3. trappola per l'euristica: l'uscita vicina e' murata, quella lontana e' libera
    R, C = 15, 15
    muri = set()
    for c in range(8, 16): muri.add((5, c))      # recinto attorno all'uscita (2,13)
    for r in range(1, 5):  muri.add((r, 8))
    for c in range(1, 13): muri.add((10, c))     # lungo muro: obbliga un giro largo
    scrivi_lab("lab3_trappola", ["15x15: l'uscita (2,13) e' la piu' vicina in linea d'aria ma e' recintata;",
               "l'unica raggiungibile e' (15,1). L'euristica (min Manhattan) attira la ricerca nel vicolo cieco."],
               R, C, (7, 7), [(2, 13), (15, 1)], muri)
    # 4. nessuna uscita raggiungibile
    R, C = 8, 8
    muri = {(4, c) for c in range(1, 9)}
    scrivi_lab("lab4_senza_uscita", ["8x8 diviso in due da un muro: entrambe le uscite sono dall'altra parte.",
               "A* deve dimostrare che non c'e' soluzione; IDA* esplora tutti i cammini semplici."],
               R, C, (2, 2), [(8, 1), (8, 8)], muri)
    # 5-6. griglie aperte con ostacoli casuali (molti cammini equivalenti)
    for nome, R, C, dens, seed, start, uscite in [
        ("lab5_aperto_20", 20, 20, 0.20, 7, (1, 1), [(20, 20), (20, 1)]),
        ("lab6_aperto_30", 30, 30, 0.25, 11, (1, 1), [(30, 30), (1, 30)]),
    ]:
        rnd = random.Random(seed)
        while True:
            muri = {(r, c) for r in range(1, R + 1) for c in range(1, C + 1)
                    if rnd.random() < dens} - {start, *uscite}
            d = bfs(R, C, start, muri)
            if any(e in d for e in uscite):
                break
        scrivi_lab(nome, [f"{R}x{C} con ostacoli casuali (densita' {dens}, seed {seed}).",
                   "Spazio aperto: molti cammini equivalenti, caso sfavorevole per IDA* (niente lista dei chiusi)."],
                   R, C, start, uscite, muri)

# ------------------------------------------------------------- puzzle dell'8
GOAL = (1, 2, 3, 4, 5, 6, 7, 8, 0)

def vicini(s):
    i = s.index(0)
    r, c = divmod(i, 3)
    for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        if 0 <= r + dr < 3 and 0 <= c + dc < 3:
            j = (r + dr) * 3 + c + dc
            t = list(s); t[i], t[j] = t[j], t[i]
            yield tuple(t)

def distanze_dal_goal():
    d = {GOAL: 0}
    q = collections.deque([GOAL])
    while q:
        s = q.popleft()
        for n in vicini(s):
            if n not in d:
                d[n] = d[s] + 1
                q.append(n)
    return d              # 181440 stati risolvibili

def puzzle():
    os.makedirs("puzzle8", exist_ok=True)
    d = distanze_dal_goal()
    per_lung = collections.defaultdict(list)
    for s, k in d.items():
        per_lung[k].append(s)
    rnd = random.Random(2026)
    scelti = []
    for k in (4, 8, 12, 16, 18, 20, 22, 24, 26, 28, 30):
        stati = sorted(per_lung[k])
        scelti.append((k, rnd.choice(stati)))
    scelti.append((31, (8, 6, 7, 2, 5, 4, 3, 0, 1)))   # una delle due istanze piu' difficili
    for k, s in scelti:
        lista = ",".join("v" if x == 0 else str(x) for x in s)
        nome = f"p{k:02d}"
        with open(f"puzzle8/{nome}.pl", "w") as f:
            f.write(f"% {nome}.pl - soluzione ottima di {k} mosse (verificata con BFS)\n")
            f.write(f"iniziale([{lista}]).\n")
        ATTESI.append((f"puzzle8/{nome}.pl", k))
        print(f"{nome}: {s}  ottimo={k}")
    # istanza irrisolvibile: si scambiano due tessere del goal
    with open("puzzle8/irrisolvibile.pl", "w") as f:
        f.write("% irrisolvibile.pl - goal con 7 e 8 scambiati: numero di inversioni dispari.\n")
        f.write("% Non va data in pasto agli algoritmi: si controlla con risolvibile/1.\n")
        f.write("iniziale([1,2,3,4,5,6,8,7,v]).\n")
    print("stati risolvibili:", len(d), " massimo:", max(d.values()))

if __name__ == "__main__":
    labirinti()
    puzzle()
    with open("ottimi_attesi.csv", "w") as f:
        f.write("istanza,ottimo\n")
        for fn, k in ATTESI:
            f.write(f"{fn},{'' if k is None else k}\n")
