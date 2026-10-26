"""Confronta gli agenti su tutte le mappe e salva la tabella dei risultati.

Uso (dalla cartella clips-wumpus):
    python strumenti/esperimenti.py                  mappe "a tema" + 100 casuali
    python strumenti/esperimenti.py --soglie         anche le varianti dell'agente 3
                                                     con soglie di rischio diverse
Produce:
    risultati/risultati_mappe.csv      una riga per (agente, mappa a tema)
    risultati/risultati_casuali.csv    una riga per (agente, mappa casuale)
    risultati/riepilogo.csv            medie per agente sulle mappe casuali
    risultati/*.png                    grafici (se c'e' matplotlib)
"""
import csv, glob, os, re, sys, tempfile, statistics
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from esegui_headless import esegui

RADICE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
os.chdir(RADICE)

AGENTI = {
    "1-prudente": "agenti/agente-base/agent.clp",
    "2-logico": "agenti/agente-avanzato/agent.clp",
    "3-stratega": "agenti/agente-3/agent.clp",
}

def variante(soglia_rischio):
    """Copia dell'agente 3 con un'altra soglia di rischio (file temporaneo)."""
    testo = open(AGENTI["3-stratega"]).read()
    nuovo = re.sub(r"\(parametro \(nome soglia-rischio\) \(valore [0-9.]+\)\)",
                   f"(parametro (nome soglia-rischio) (valore {soglia_rischio}))", testo)
    assert nuovo != testo or f"(valore {soglia_rischio})" in testo
    f = tempfile.NamedTemporaryFile("w", suffix=".clp", delete=False)
    f.write(nuovo); f.close()
    return f.name

def corri(agenti, mappe, nome_csv):
    righe = []
    for nome_m in mappe:
        for nome_a, file_a in agenti.items():
            r = esegui(nome_m, file_a)
            r = {"agente": nome_a, "mappa": os.path.basename(nome_m), **r}
            righe.append(r)
    campi = ["agente", "mappa", "premio", "esito", "passi", "energia_residua", "oro", "morto",
             "pozzi_giusti", "pozzi_sbagliati", "urti", "azioni"]
    with open(nome_csv, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=campi); w.writeheader(); w.writerows(righe)
    return righe

def riepilogo(righe):
    out = []
    for a in dict.fromkeys(r["agente"] for r in righe):
        rr = [r for r in righe if r["agente"] == a]
        n = len(rr)
        out.append({
            "agente": a, "mappe": n,
            "premio_medio": round(statistics.mean(r["premio"] for r in rr), 2),
            "oro_%": round(100 * sum(r["oro"] for r in rr) / n, 1),
            "morti_%": round(100 * sum(r["morto"] for r in rr) / n, 1),
            "pozzi_giusti_medi": round(statistics.mean(r["pozzi_giusti"] for r in rr), 2),
            "pozzi_sbagliati_medi": round(statistics.mean(r["pozzi_sbagliati"] for r in rr), 2),
            "passi_medi": round(statistics.mean(r["passi"] for r in rr), 1),
            "energia_esaurita": sum(r["esito"] == "energia esaurita" for r in rr),
            "non_terminati": sum(r["esito"] == "non terminato" for r in rr),
        })
    return out

if __name__ == "__main__":
    os.makedirs("risultati", exist_ok=True)
    agenti = dict(AGENTI)
    if "--soglie" in sys.argv:
        for s in (0.0, 0.2, 0.34, 0.4, 0.5, 1.0):
            agenti[f"3-stratega rischio<={s}"] = variante(s)
    # le mappe del docente (map1, m00) non sono nel repository: si escludono
    # anche se presenti, cosi' i risultati pubblicati dipendono solo da mappe nostre
    DOCENTE = {"map1.json", "m00_default_simulatore.json"}
    tema = sorted(m for m in glob.glob("mappe/*.json") if os.path.basename(m) not in DOCENTE)
    casuali = sorted(glob.glob("mappe/casuali/*.json"))
    r1 = corri(AGENTI, tema, "risultati/risultati_mappe.csv")
    print(f"{'mappa':28s}" + "".join(f"{a:>14s}" for a in AGENTI))
    for m in tema:
        b = os.path.basename(m)
        print(f"{b:28s}" + "".join(f"{next(r['premio'] for r in r1 if r['mappa']==b and r['agente']==a):>14.0f}" for a in AGENTI))
    r2 = corri(agenti, casuali, "risultati/risultati_casuali.csv")
    rie = riepilogo(r2)
    with open("risultati/riepilogo.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rie[0])); w.writeheader(); w.writerows(rie)
    print()
    for r in rie:
        print(r)
