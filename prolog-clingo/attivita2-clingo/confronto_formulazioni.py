"""Confronta due formulazioni equivalenti dell'ottimizzazione principale.

  A) #maximize sugli incontri a pari punteggio   (traduzione letterale del requisito)
  B) #minimize sugli incontri misti               (quella usata in torneo.lp)

Le due versioni hanno gli stessi answer set ottimi, perche' il numero di
incontri di un turno e' fisso (n/2 per difetto). Cambia invece quanto il
solver fatica a DIMOSTRARE l'ottimalita'.

Uso:  python confronto_formulazioni.py      (timeout 60 s per prova)
"""
import os, time, clingo, threading

QUI = os.path.dirname(os.path.abspath(__file__))
B = open(os.path.join(QUI, "torneo.lp")).read()
A = B.replace("#minimize { 1@3,P,Q : misto(P,Q) }.",
              "#maximize { 1@3,P,Q : incontro(P,Q), pt(P,N), pt(Q,N) }.")
assert A != B
TIMEOUT = 60

def prova(programma, n):
    ctl = clingo.Control(["--opt-mode=opt"])
    ctl.add("base", [], programma)
    ctl.add("base", [], " ".join(f"giocatore(g{i:02d})." for i in range(n)))
    ctl.ground([("base", [])])
    t0 = time.perf_counter()
    with ctl.solve(async_=True) as h:
        finito = h.wait(TIMEOUT)
        if not finito:
            h.cancel()
            return None
    return time.perf_counter() - t0

print(f"{'giocatori':>9s} | {'A) #maximize pari':>18s} | {'B) #minimize misti':>18s}")
with open(os.path.join(QUI, "risultati", "confronto_formulazioni.csv"), "w") as f:
    f.write("giocatori,maximize_s,minimize_s\n")
    for n in (6, 8, 10, 12, 14, 16, 20, 24, 32):
        ta, tb = prova(A, n), prova(B, n)
        fa = f"{ta:.3f} s" if ta is not None else f"> {TIMEOUT} s"
        fb = f"{tb:.3f} s" if tb is not None else f"> {TIMEOUT} s"
        print(f"{n:9d} | {fa:>18s} | {fb:>18s}", flush=True)
        f.write(f"{n},{'' if ta is None else round(ta,4)},{'' if tb is None else round(tb,4)}\n")
