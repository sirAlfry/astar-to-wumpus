"""Simula un torneo completo turno dopo turno usando torneo.lp.

Uso (dalla cartella attivita2-clingo):
    pip install clingo
    python simula_torneo.py                   torneo di esempio, 5 turni
    python simula_torneo.py --giocatori 32 --turni 7 --seed 3   torneo grande

A ogni turno:
  1. scrive l'istanza (giocatori, incontri disputati, BYE avuti, punti)
     in istanze/sim_turnoK.lp
  2. chiama clingo su torneo.lp + istanza e prende l'answer set ottimo
  3. VERIFICA in Python, indipendentemente da ASP, che i vincoli siano
     rispettati (BYE unico e mai ripetuto, coppie mai ripetute, tutti
     impegnati) e conta le coppie a pari punteggio
  4. estrae a caso i vincitori (seed fisso: risultati riproducibili),
     assegna 2 punti alla vittoria e al BYE, aggiunge eventuali nuovi
     iscritti
Al termine stampa la classifica e i tempi di clingo per turno.
"""
import argparse, random, time, os
import clingo

QUI = os.path.dirname(os.path.abspath(__file__))
PUNTI_VITTORIA = 2

def risolvi(istanza_txt):
    ctl = clingo.Control(["--opt-mode=opt"])
    ctl.load(os.path.join(QUI, "torneo.lp"))
    ctl.add("base", [], istanza_txt)
    t0 = time.perf_counter()
    ctl.ground([("base", [])])
    t1 = time.perf_counter()
    migliore = []
    def on_model(m):
        migliore[:] = [m.symbols(shown=True), m.cost]
    res = ctl.solve(on_model=on_model)
    t2 = time.perf_counter()
    if not res.satisfiable:
        return None, None, t1 - t0, t2 - t1
    simboli, costo = migliore
    incontri = [(str(s.arguments[0]), str(s.arguments[1])) for s in simboli if s.name == "incontro"]
    bye = [str(s.arguments[0]) for s in simboli if s.name == "bye"]
    return incontri, (bye[0] if bye else None, costo), t1 - t0, t2 - t1

def istanza(giocatori, giocati, bye_avuti, punti, turno):
    righe = [f"% sim_turno{turno}.lp - generato da simula_torneo.py"]
    righe.append("giocatore(" + "; ".join(sorted(giocatori)) + ").")
    righe += [f"giocato({a},{b})." for a, b in sorted(giocati)]
    righe += [f"bye_avuto({p})." for p in sorted(bye_avuti)]
    righe += [f"punti({p},{n})." for p, n in sorted(punti.items()) if n > 0]
    return "\n".join(righe) + "\n"

def verifica(giocatori, giocati, bye_avuti, incontri, bye):
    visti = [p for c in incontri for p in c] + ([bye] if bye else [])
    assert sorted(visti) == sorted(giocatori), "qualcuno non e' impegnato o lo e' due volte"
    assert (len(giocatori) % 2 == 1) == (bye is not None), "BYE presente se e solo se dispari"
    assert bye not in bye_avuti, "BYE assegnato due volte"
    for a, b in incontri:
        assert (a, b) not in giocati and (b, a) not in giocati, f"{a}-{b} si sono gia' affrontati"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--giocatori", type=int, default=0, help="0 = torneo di esempio")
    ap.add_argument("--turni", type=int, default=5)
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--salva", action="store_true", help="salva le istanze in istanze/")
    a = ap.parse_args()
    rnd = random.Random(a.seed)

    if a.giocatori == 0:
        giocatori = ["anna", "bruno", "carla", "dario", "elena"]
        nuovi = {2: ["filippo", "giulia", "hugo"], 4: ["irene"]}   # turno -> chi entra
    else:
        giocatori = [f"g{i:02d}" for i in range(1, a.giocatori + 1)]
        nuovi = {}
    giocati, bye_avuti = set(), set()
    punti = {p: 0 for p in giocatori}

    for t in range(1, a.turni + 1):
        for p in nuovi.get(t, []):
            giocatori.append(p); punti[p] = 0
        txt = istanza(giocatori, giocati, bye_avuti, punti, t)
        if a.salva:
            with open(os.path.join(QUI, "istanze", f"sim_turno{t}.lp"), "w") as f:
                f.write(txt)
        incontri, info, tg, ts = risolvi(txt)
        print(f"\n=== Turno {t}  ({len(giocatori)} giocatori, grounding {tg*1000:.1f} ms, solving {ts*1000:.1f} ms)")
        if incontri is None:
            print("UNSATISFIABLE: non esiste un abbinamento che rispetti i vincoli")
            print("(tutte le coppie possibili si sono gia' affrontate o il BYE non e' assegnabile)")
            break
        bye, costo = info
        verifica(giocatori, giocati, bye_avuti, incontri, bye)
        prima = dict(punti)                       # classifica prima del turno
        pari = sum(1 for x, y in incontri if prima[x] == prima[y])
        for x, y in sorted(incontri, key=lambda c: -max(punti[c[0]], punti[c[1]])):
            vincitore = rnd.choice((x, y))
            punti[vincitore] += PUNTI_VITTORIA
            giocati.add((x, y))
            segno = "=" if prima[x] == prima[y] else " "    # "=" = pari punteggio
            print(f"  {x:>9s} vs {y:<9s} {segno}  vince {vincitore}")
        if bye:
            print(f"  {bye:>9s}: BYE")
            bye_avuti.add(bye); punti[bye] += PUNTI_VITTORIA
        print(f"  incontri a pari punteggio: {pari}/{len(incontri)}   costo ottimo clingo: {costo}")
    print("\nClassifica finale:")
    for p, n in sorted(punti.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"  {p:10s} {n:3d}")

if __name__ == "__main__":
    main()
