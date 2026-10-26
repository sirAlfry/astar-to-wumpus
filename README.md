# astar-to-wumpus

Progetto d'esame di **Intelligenza Artificiale e Laboratorio** (Università di Torino, a.a. 2025/2026), di Alfredo De Donno. Il percorso va dal labirinto risolto con A*/IDA* in Prolog fino alla caverna del Wumpus esplorata da agenti CLIPS.

| Parte | Contenuto | Dove |
| --- | --- | --- |
| 1. Programmazione logica e ASP | A\* e IDA\* in Prolog su labirinti e puzzle dell'8 · calendario di un torneo a turni in Clingo | [`prolog-clingo/`](prolog-clingo/README.md) |
| 2. Sistemi a regole | tre agenti CLIPS (con moduli e certainty factors) per il mondo del Wumpus | [`clips-wumpus/`](clips-wumpus/README.md) |

```
astar-to-wumpus/
├── prolog-clingo/         attivita1-prolog/, attivita2-clingo/, presentazione/
└── clips-wumpus/          agenti/, mappe/, strumenti/, risultati/, presentazione/
```

Si apre in VS Code con **File → Apri area di lavoro da file… → `astar-to-wumpus.code-workspace`**.

## In breve

- **A\* contro IDA\***. Trovano sempre la soluzione ottima, verificata con una BFS indipendente su tutte le istanze. Nel puzzle dell'8 hanno tempi simili e IDA*usa 300 volte meno memoria. Nei labirinti IDA* crolla: le trasposizioni, senza lista dei chiusi, gli costano oltre 4 milioni di nodi contro 125.
- **Torneo in ASP**. Generate, test e optimize con tre priorità. `#minimize` sugli incontri tra punteggi diversi risolve in millisecondi ciò che `#maximize` sugli incontri a pari punteggio non risolve in un minuto, pur avendo gli stessi ottimi.
- **Wumpus**. Tre agenti di intelligenza crescente. Sulle 100 mappe casuali il premio medio passa da 24 a 39 a 58,5, sempre con 0% di morti. Un "oracolo logico" dimostra che le regole d'inferenza dell'agente 2 sono complete: oltre, si va solo rischiando.
- **Verifiche indipendenti**. Le euristiche sono controllate su tutti i 181.440 stati del puzzle; una versione di IDA* con i cut espliciti dà risultati identici e mostra un cut che sembra verde ma è rosso.

## Requisiti

SWI-Prolog ≥ 9, Python ≥ **3.12**, `pip install clingo clipspy matplotlib`. Dettagli e comandi sono nei README delle due parti.

## Materiale del corso non incluso

Il regolamento del corso vieta di condividere i materiali didattici. Per questo il repository **non contiene** il simulatore del mondo del Wumpus usato dagli agenti CLIPS, né i testi delle consegne. Tutte le istanze di test (labirinti, puzzle, tornei, mappe) sono invece nostre.

Chi segue il corso copia i file del simulatore in `clips-wumpus/simulatore/` (cartella esclusa da git): i dettagli sono nel README di `clips-wumpus`.

## Dichiarazione sull'uso dell'intelligenza artificiale

Il codice, le istanze di test, gli esperimenti e le bozze delle presentazioni sono stati prodotti con l'aiuto di un assistente di IA generativa (Claude, di Anthropic), su indicazioni e sotto la supervisione dello studente. Lo studente ha:

- definito obiettivi e vincoli a partire dalle consegne;
- rieseguito tutte le prove e verificato i risultati riportati;
- studiato il codice per poterne discutere ogni scelta. Nei README di ogni parte ci sono le domande frequenti sul codice.

## Licenza

Il codice di questo repository è distribuito con licenza **MIT** (vedi [`LICENSE`](LICENSE)), © 2026 Alfredo De Donno. La licenza copre solo il codice scritto per questo progetto, non il materiale del corso.
