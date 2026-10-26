"""Verifica che idastar_cut.pl (con i cut) e idastar.pl (con ->) diano
gli stessi risultati: costo, nodi espansi, iterazioni.

Uso (dalla cartella attivita1-prolog):  python test/cut/confronta_cut.py
"""
import glob, os, subprocess
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

def esegui(alg, dom, ist, heur):
    out = subprocess.run(["swipl", "esegui.pl", alg, dom, ist, heur, "30"],
                         capture_output=True, text=True).stdout.strip().splitlines()
    c = out[-1].split(",")
    return c[4], c[5], c[6], c[7]          # esito, costo, nodi, iterazioni

prove = [("labirinto", i, "manhattan") for i in sorted(glob.glob("test/labirinto/*.pl"))
         if "trappola" not in i]          # la trappola va in timeout con entrambi
prove += [("puzzle8", i, h) for i in sorted(glob.glob("test/puzzle8/p*.pl"))
          for h in ("manhattan", "fuori_posto") if not (h == "fuori_posto" and i[-6:-3] in ("p30", "p31"))]
uguali = 0
for dom, ist, h in prove:
    a, b = esegui("idastar", dom, ist, h), esegui("idastar_cut", dom, ist, h)
    ok = a == b
    uguali += ok
    print(f"{os.path.basename(ist):24s} {h:12s} idastar={a}  idastar_cut={b}  {'uguali' if ok else 'DIVERSI'}")
print(f"\n{uguali}/{len(prove)} prove con risultati identici")
