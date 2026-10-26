"""L'oracolo LOGICO: l'agente 2 sfrutta TUTTO quello che si puo' dedurre?

A fine partita si prende cio' che l'agente ha davvero osservato (celle
visitate con brezza/puzza, muri urtati) e si calcola, con un ragionamento
completo per modelli (model checking, indipendente dalle regole CLIPS),
quali celle sono DIMOSTRABILMENTE sicure: una cella e' sicura se in nessun
mondo compatibile con le osservazioni contiene un pozzo o il Wumpus.

Il controllo e' esatto ed efficiente perche' i vincoli hanno forma speciale:
  - brezza in b      -> almeno un pozzo tra le vicine di b
  - niente brezza    -> nessun pozzo tra le vicine
  - puzza / no puzza -> idem per il Wumpus, che e' UNO SOLO
  - pozzo e Wumpus non stanno nella stessa cella
Per sapere se una cella c puo' essere un pozzo basta cercare una posizione
del Wumpus compatibile per cui ogni brezza resti spiegata; idem per il Wumpus.

Se a fine partita esiste una cella dimostrabilmente sicura, raggiungibile e
mai visitata, l'agente ha "lasciato sul tavolo" qualcosa che la logica gli
permetteva di prendere. Se non esiste MAI, le sue regole d'inferenza sono
complete per questo gioco: per fare di piu' bisogna rischiare.

Uso:  python strumenti/oracolo_logico.py
"""
import glob, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from esegui_headless import esegui

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
MOSSE = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}

def vicine(c):
    x, y = c
    return [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]

def ricostruisci(d, azioni):
    """Rigioca le azioni: celle visitate e muri scoperti dall'agente."""
    W, H = d["width"], d["height"]
    muri = {tuple(c) for c in d["walls"]}
    pos = tuple(d.get("start", [0, 0]))
    visitate, urti = {pos}, set()
    for a in azioni:
        if a in MOSSE:
            n = (pos[0] + MOSSE[a][0], pos[1] + MOSSE[a][1])
            if 0 <= n[0] < W and 0 <= n[1] < H and n not in muri:
                pos = n; visitate.add(n)
            else:
                urti.add(n)
    return visitate, urti

def sicure_dimostrabili(d, visitate, urti):
    pozzi = {tuple(c) for c in d["pits"]}
    wumpus = tuple(d["wumpus"])
    brezza = {v: any(n in pozzi for n in vicine(v)) for v in visitate}
    puzza = {v: wumpus in vicine(v) for v in visitate}
    noti = visitate | urti                                   # celle di cui so tutto
    frontiera = {n for v in visitate for n in vicine(v)
                 if n[0] >= 0 and n[1] >= 0 and n not in noti}
    no_pozzo = {n for v in visitate if not brezza[v] for n in vicine(v)}
    no_wumpus = {n for v in visitate if not puzza[v] for n in vicine(v)}
    puzze = [v for v in visitate if puzza[v]]
    brezze = [v for v in visitate if brezza[v]]
    # posizioni possibili del Wumpus: adiacenti a TUTTE le puzze, mai escluse
    if puzze:
        cand_w = {c for c in frontiera if c not in no_wumpus and all(c in vicine(p) for p in puzze)}
    else:
        cand_w = {c for c in frontiera if c not in no_wumpus} | {"altrove"}   # anche fuori dalla frontiera
    def brezze_spiegabili(pozzo_forzato, w):
        # ogni brezza ha almeno una vicina che puo' essere pozzo (non esclusa, non il Wumpus)
        for b in brezze:
            if not any((n == pozzo_forzato) or (n in frontiera and n not in no_pozzo and n != w)
                       for n in vicine(b)):
                return False
        return True
    def puo_essere_pozzo(c):
        if c in no_pozzo:
            return False
        return any(w != c and brezze_spiegabili(c, w) for w in cand_w)
    def puo_essere_wumpus(c):
        return c in cand_w and brezze_spiegabili(None, c)
    return {c for c in frontiera if not puo_essere_pozzo(c) and not puo_essere_wumpus(c)}

if __name__ == "__main__":
    agenti = {"2-logico": "agenti/agente-avanzato/agent.clp", "3-stratega": "agenti/agente-3/agent.clp",
              "1-prudente": "agenti/agente-base/agent.clp"}
    for nome, file in agenti.items():
        mancate, totale_celle, esempi = 0, 0, []
        for fn in sorted(glob.glob("mappe/casuali/*.json")):
            d = json.load(open(fn))
            r = esegui(fn, file)
            if r["morto"]:
                continue
            visitate, urti = ricostruisci(d, r["azioni"].split())
            sicure = sicure_dimostrabili(d, visitate, urti)
            if sicure and not r["oro"]:          # con l'oro preso la partita e' finita apposta
                mancate += 1; totale_celle += len(sicure); esempi.append((os.path.basename(fn), sorted(sicure)))
        print(f"{nome:12s}: partite chiuse lasciando celle dimostrabilmente sicure inesplorate: {mancate}/100"
              f"  (celle: {totale_celle})")
        for e in esempi[:3]:
            print("      es.", e)
