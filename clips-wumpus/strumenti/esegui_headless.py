"""Esegue un agente CLIPS sul simulatore SENZA interfaccia grafica.

Serve per gli esperimenti ripetibili (molte mappe, molti agenti) e per
il debug. Usa le stesse classi del simulatore ufficiale (WumpusWorld e
ClipsAgent di simulatore/wumpus.py, che NON viene modificato) e ripete
esattamente il ciclo del pulsante "Step" della GUI:

    azione = agente.run_and_get_action()
    risultato = mondo.step(azione)
    agente.clear_action_facts(); agente.assert_percept(...); agente.update_time_counter(...)

Uso (dalla cartella clips-wumpus):
    python strumenti/esegui_headless.py -m mappe/map1.json -a agenti/agente-avanzato/agent.clp -v
    python strumenti/esegui_headless.py ... --traccia     stampa anche le printout dell'agente

Importabile come modulo: esegui(mappa, agente) -> dizionario di misure.
"""
import argparse, contextlib, io, json, os, sys, types

QUI = os.path.dirname(os.path.abspath(__file__))
SIM = os.path.join(QUI, "..", "simulatore")
sys.path.insert(0, SIM)

# wumpus.py importa tkinter a livello di modulo. Se tkinter manca (server,
# container) lo sostituiamo con un modulo vuoto: la GUI qui non serve.
try:
    import tkinter  # noqa: F401
except ImportError:
    finto = types.ModuleType("tkinter")
    finto.__all__ = []
    sys.modules["tkinter"] = finto

import wumpus  # noqa: E402  (simulatore ufficiale)

DIREZIONI = {"pit-north": (0, -1), "pit-south": (0, 1), "pit-west": (-1, 0), "pit-east": (1, 0)}


@contextlib.contextmanager
def silenzio(attivo):
    """Zittisce le printout di CLIPS (scrivono sul descrittore 1, non su sys.stdout)."""
    if not attivo:
        yield
        return
    sys.stdout.flush()
    salvato = os.dup(1)
    nullo = os.open(os.devnull, os.O_WRONLY)
    os.dup2(nullo, 1)
    try:
        yield
    finally:
        sys.stdout.flush()
        os.dup2(salvato, 1)
        os.close(nullo); os.close(salvato)


def esegui(mappa, agente, max_iter=1000, verbose=False, traccia=False):
    mondo = wumpus.WumpusWorld.from_json(mappa)
    with silenzio(not traccia):
        ag = wumpus.ClipsAgent(agente)
    mondo.reset()
    azioni, pozzi_ok, pozzi_ko, urti = [], 0, 0, 0
    for _ in range(max_iter):
        if mondo.done:
            break
        with silenzio(not traccia):
            az = ag.run_and_get_action()
        x0, y0, e0 = mondo.x, mondo.y, mondo.energy
        if az in DIREZIONI:
            dx, dy = DIREZIONI[az]
            if (x0 + dx, y0 + dy) in mondo.pits:
                pozzi_ok += 1
            else:
                pozzi_ko += 1
        res = mondo.step(az)
        if az in ("up", "down", "left", "right") and (mondo.x, mondo.y) == (x0, y0) and not mondo.dead:
            urti += 1
        azioni.append(az)
        if verbose:
            print(f"passo {mondo.steps:3d}: {az:10s} -> ({mondo.x},{mondo.y}) energia={mondo.energy:3d} premio={mondo.reward}")
        ag.clear_action_facts()
        ag.assert_percept(res.obs)
        ag.update_time_counter(res.obs)
    esito = ("morto" if mondo.dead else
             "oro" if mondo.has_gold else
             "uscito" if azioni and azioni[-1] == "quit" and (mondo.x, mondo.y) == mondo.start else
             "energia esaurita" if mondo.energy <= 0 else
             "non terminato")
    return {
        "premio": mondo.reward, "esito": esito, "passi": mondo.steps,
        "energia_residua": mondo.energy, "oro": mondo.has_gold, "morto": mondo.dead,
        "pozzi_giusti": pozzi_ok, "pozzi_sbagliati": pozzi_ko, "urti": urti,
        "azioni": " ".join(azioni),
    }


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("-m", "--map", required=True)
    ap.add_argument("-a", "--agent", required=True)
    ap.add_argument("-v", "--verbose", action="store_true")
    ap.add_argument("--traccia", action="store_true")
    a = ap.parse_args()
    r = esegui(a.map, a.agent, verbose=a.verbose, traccia=a.traccia)
    print(json.dumps({k: v for k, v in r.items() if k != "azioni"}, ensure_ascii=False))
