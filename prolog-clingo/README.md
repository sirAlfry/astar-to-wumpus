# Parte 1: ricerca in Prolog e ASP con Clingo

Due attività:

1. **A\* e IDA\* in Prolog**, confrontati su due domini classici: un labirinto con più uscite (non tutte raggiungibili) e il puzzle dell'8;
2. **il calendario di un torneo a turni in ASP** (Clingo): a ogni turno si abbinano i giocatori rispettando i vincoli del torneo e preferendo avversari con lo stesso punteggio.

```
prolog-clingo/
├── attivita1-prolog/
│   ├── ricerca/            astar.pl, idastar.pl, idastar_cut.pl, comune.pl   algoritmi generici
│   ├── domini/labirinto/   labirinto.pl                         azioni + euristica
│   ├── domini/puzzle8/     puzzle8.pl                           azioni + 2 euristiche + risolvibilita'
│   ├── test/               6 labirinti, 12 puzzle, genera_test.py, ottimi_attesi.csv,
│   │                       verifica_euristiche.pl, cut/ (demo e confronto sui cut)
│   ├── esegui.pl           esegue un algoritmo su un'istanza e stampa le misure
│   ├── benchmark.py        tutte le prove -> risultati/risultati.csv
│   ├── grafici.py          grafici
│   └── risultati/
└── attivita2-clingo/
    ├── torneo.lp                  il programma ASP
    ├── istanze/                   turno1.lp, turno2.lp (torneo di esempio), sim_turno*.lp
    ├── simula_torneo.py           torneo completo turno per turno, con verifica dei vincoli
    ├── confronto_formulazioni.py  #maximize contro #minimize (vedi sotto)
    └── risultati/
```

Tutte le istanze sono nostre e si rigenerano con `test/genera_test.py` (seed fissi).

## Cosa serve installare

| Strumento | Perché | Dove |
|---|---|---|
| **SWI-Prolog** ≥ 9 | Attività 1 | <https://www.swi-prolog.org/download/stable> (su Windows spunta "add to PATH") |
| **Python** ≥ 3.10 | script di test e grafici | <https://www.python.org/downloads/> |
| **clingo** | Attività 2 | `pip install clingo`: installa il modulo Python, che si lancia con `python -m clingo` (è il comando usato qui sotto). In alternativa l'eseguibile `clingo` si scarica da <https://github.com/potassco/clingo/releases> |
| **matplotlib** | grafici (facoltativo) | `pip install matplotlib` |

---

## Attività 1: A* e IDA* in Prolog

### Come si esegue

```powershell
cd prolog-clingo\attivita1-prolog
swipl esegui.pl astar   labirinto test\labirinto\lab1_piccolo.pl
swipl esegui.pl idastar puzzle8   test\puzzle8\p20.pl manhattan
swipl esegui.pl astar   puzzle8   test\puzzle8\p31.pl fuori_posto 120     # timeout 120 s
python benchmark.py          # tutte le 72 prove (circa 4 minuti), poi i grafici
```

Oppure in modo interattivo:

```prolog
?- [ricerca/astar, domini/puzzle8/puzzle8, 'test/puzzle8/p12'].
?- astar(Azioni, Costo), nodi_espansi(N).
?- imposta_euristica(fuori_posto), astar(Azioni, Costo), nodi_espansi(N).
```

### Scelte di progetto

1. **Algoritmi e domini separati.** Gli algoritmi conoscono solo un'interfaccia classica per la ricerca nello spazio degli stati: `iniziale/1`, `finale/1`, `applicabile/2`, `trasforma/3`, più `euristica/2`. Lo stesso `astar.pl` risolve labirinti e puzzle senza cambiare una riga. È la stessa separazione dominio/motore della pianificazione.
2. **A\*** (`ricerca/astar.pl`):
   - la frontiera è una **coda di priorità** (`library(heaps)`), così inserimento ed estrazione del minimo costano O(log n), contro l'O(n) di una lista ordinata;
   - i chiusi sono un **albero AVL** (`library(assoc)`), con test di appartenenza in O(log n) invece dell'O(n) di `member/2`;
   - la **cancellazione è pigra**: se uno stato entra due volte in frontiera, la copia peggiore si scarta quando viene estratta;
   - con un'euristica **consistente** non serve mai riaprire un nodo chiuso, e le euristiche usate lo sono;
   - a parità di f si preferisce h minore (priorità `F-H`).
3. **IDA\*** (`ricerca/idastar.pl`):
   - è una profondità limitata sulla soglia f = g + h;
   - la prossima soglia è il **minimo f tra i nodi tagliati**, salvato con `nb_setval/nb_getval`: è una variabile globale che sopravvive al backtracking, come `assert/retract` ma più veloce;
   - il controllo dei cicli riguarda **solo il cammino corrente** (`\+ memberchk`);
   - la soluzione trovata viene "congelata" dal `->` (if-then-else), che taglia le alternative come farebbe un cut.
4. **Euristiche:**
   - **labirinto**: distanza di Manhattan dall'**uscita più vicina**, perché le uscite sono più di una;
   - **puzzle**: **Manhattan** e **tessere fuori posto**, più h = 0 come riferimento (A* diventa ricerca a costo uniforme).

   Sono tutte ammissibili e consistenti; le motivazioni sono nei commenti del codice.
5. **Istanze verificate in modo indipendente.**
   - `test/genera_test.py` calcola l'ottimo di ogni istanza con una BFS in Python.
   - Per il puzzle esplora tutti i 181.440 stati risolvibili.
   - `benchmark.py` controlla che A* e IDA* trovino **sempre** quell'ottimo: colonna `ottimo_ok`, tutte "si".
6. **Euristiche verificate, non solo argomentate.** `test/verifica_euristiche.pl` calcola con una BFS in Prolog la distanza vera d* di **ogni** stato (tutti i 181.440 del puzzle, ogni cella libera dei labirinti). Poi controlla stato per stato h ≤ d* (ammissibilità) e, arco per arco, h(s) ≤ 1 + h(s') (consistenza). Risultato in `risultati/verifica_euristiche.txt`:
   - Manhattan e tessere fuori posto: **ammissibili e consistenti su tutti i 181.440 stati**, e Manhattan ≥ fuori posto in ogni stato (dominanza);
   - in media Manhattan vale il **63,7%** della distanza vera, le tessere fuori posto solo il **32,4%**: è la misura numerica di "più informata", e spiega perché espande da 18 a 190 volte meno nodi;
   - labirinti: ammissibile e consistente su tutte le istanze. Vale circa l'87% della distanza vera nelle griglie aperte, il 46% in `lab3_trappola` (l'uscita murata la inganna) e solo il 33% in `lab1_piccolo`, dove i corridoi obbligano a lunghi giri.
7. **Risolvibilità del puzzle.** `risolvibile/1` conta le inversioni: un'istanza è risolvibile solo se sono pari. È un invariante delle mosse, e metà delle configurazioni non è risolvibile: su quelle IDA* non termina in tempi utili, e A* termina solo dopo aver visitato 181.440 stati.

### Risultati (tempi CPU indicativi; contano gli ordini di grandezza)

**Labirinti.** Nodi espansi; tutti i costi trovati sono ottimi.

| Labirinto | Ottimo | A* nodi | A* tempo | IDA* nodi | IDA* tempo |
|---|---|---|---|---|---|
| lab1_piccolo (10×10 a corridoi, 2 uscite) | 21 | 45 | 0,04 s | 249 | 0,04 s |
| lab2_grande (20×40 a corridoi con cicli, un'uscita murata) | 76 | 397 | 0,05 s | 35.625 | 0,4 s |
| lab3_trappola (uscita vicina recintata) | 26 | 125 | 0,04 s | > 4 milioni | **timeout 60 s** |
| lab4_senza_uscita | nessuna | 24 | 0,04 s | 374.646 | 3,8 s |
| lab5_aperto_20 | 27 | 54 | 0,04 s | 2.059 | 0,06 s |
| lab6_aperto_30 | 39 | 79 | 0,04 s | 23.127 | 0,3 s |

**Puzzle dell'8.** Nodi espansi; "memoria" indica quanti stati sono tenuti in memoria alla fine (A*: frontiera + chiusi; IDA*: il cammino corrente).

| Istanza | Mosse | A* Manhattan | IDA* Manhattan | A* fuori posto | IDA* fuori posto | A* h=0 | Memoria A* / IDA* |
|---|---|---|---|---|---|---|---|
| p08 | 8 | 9 | 8 | 10 | 18 | 265 | 18 / 9 |
| p16 | 16 | 61 | 56 | 464 | 905 | 10.555 | 106 / 17 |
| p20 | 20 | 404 | 636 | 3.185 | 13.117 | 52.643 | 667 / 21 |
| p24 | 24 | 783 | 3.544 | 14.569 | 114.040 | 144.086 | 1.239 / 25 |
| p28 | 28 | 3.321 | 13.331 | 52.715 | 633.878 | 177.572 | 5.249 / 29 |
| p31 (la più difficile) | 31 | 6.726 | 14.195 | 121.530 | 2.656.643 | 181.439 | 10.394 / 32 |

La tabella completa è in `risultati/risultati.csv`; i grafici sono `puzzle8_nodi.png`, `puzzle8_tempo.png` e `labirinti_nodi.png`.

### Analisi critica

- **Nel puzzle IDA\* è competitivo.**
  - Espande da 1 a 4 volte più nodi di A* con Manhattan, ma ogni nodo costa meno: niente heap, niente albero dei chiusi. I **tempi sono praticamente uguali** (p31: 0,45 s per entrambi).
  - Usa **memoria lineare**: 32 stati contro 10.394. È il motivo per cui esiste.
  - Il puzzle ha pochi cammini alternativi verso lo stesso stato, quindi l'assenza della lista dei chiusi pesa poco.
- **Nei labirinti IDA\* crolla.** Una griglia aperta ha moltissimi cammini equivalenti verso la stessa cella (trasposizioni). Senza lista dei chiusi IDA* li rivisita tutti, fino a oltre 4 milioni di nodi. A* ne espande al massimo qualche centinaio. Più il labirinto ha cicli, peggio va: nei corridoi di `lab2_grande` IDA* espande 35 mila nodi, nelle griglie aperte molti di più in proporzione alla lunghezza della soluzione.
- **L'euristica conta più dell'algoritmo.** Su p31, A* espande 181.439 nodi con h = 0, 121.530 con le tessere fuori posto e 6.726 con Manhattan. Per IDA*, passare dalle tessere fuori posto a Manhattan riduce i nodi di quasi 200 volte. Manhattan **domina** le tessere fuori posto (h₂ ≥ h₁ in ogni stato), quindi non espande mai più nodi.
- **Uscite irraggiungibili.**
  - In `lab3_trappola` l'uscita più vicina è recintata, e l'euristica (minimo sulle uscite) attira la ricerca nel vicolo cieco. Resta ammissibile ma diventa poco informativa.
  - A* se ne libera in 125 nodi grazie ai chiusi; IDA* alza la soglia di 1 alla volta e riesplora tutto il recinto a ogni iterazione.
  - Con `lab4_senza_uscita` **A\* dimostra in 24 nodi che non c'è soluzione**. IDA* ci arriva solo dopo aver enumerato tutti i 374.646 cammini semplici.
- **Possibili miglioramenti:**
  - IDA* con una tabella di trasposizione limitata, come fanno i programmi di gioco;
  - un'euristica con *pattern database* o *linear conflict* per il puzzle;
  - un'euristica per il labirinto che ignori le uscite già dimostrate irraggiungibili.

---

## Attività 2: calendario del torneo in Clingo

Il problema: a ogni turno si devono abbinare i giocatori, partendo dagli iscritti, dagli incontri già disputati e dalla classifica. Nuovi giocatori possono iscriversi tra un turno e l'altro. I vincoli sono quelli tipici del sistema svizzero:
- con un numero dispari di giocatori uno riposa (BYE), e vale come vittoria;
- il BYE spetta al massimo una volta a ciascuno;
- due giocatori si affrontano al massimo una volta;
- si preferiscono gli incontri tra giocatori con lo stesso punteggio.

### Come si esegue

```powershell
cd prolog-clingo\attivita2-clingo
python -m clingo torneo.lp istanze\turno1.lp
python -m clingo torneo.lp istanze\turno2.lp --opt-mode=optN 0   # tutti gli abbinamenti ottimi
python simula_torneo.py                                   # torneo di esempio, 5 turni
python simula_torneo.py --giocatori 32 --turni 7 --seed 3 # torneo grande
python confronto_formulazioni.py                          # circa 5 minuti
```

### Come è fatto `torneo.lp` (generate, define, test, optimize)

- **Input**: `giocatore/1`, `giocato/2` (incontri già disputati), `bye_avuto/1`, `punti/2`. Chi non ha punti, come i nuovi iscritti, vale 0.
- **Generate**:
  - `1 { bye(P) : giocatore(P), not bye_avuto(P) } 1 :- dispari.` sceglie un solo BYE, solo se i partecipanti sono dispari e solo tra chi non l'ha ancora avuto;
  - `{ incontro(P,Q) : ..., P < Q, not gia_affrontati(P,Q) }.` propone gli incontri. Il vincolo "mai due volte" è già nella generazione, e `P < Q` evita i doppioni (a,b)/(b,a).
- **Test**: ogni giocatore è impegnato **esattamente** una volta (incontro o BYE). Due vincoli: "almeno uno" con `not impegnato(P)` e "al più uno" con l'aggregato `2 { ... }`.
- **Optimize**, con priorità decrescenti:
  - `@3` **minimizzare gli incontri tra punteggi diversi**, che equivale a massimizzare quelli a pari punteggio;
  - `@2` minimizzare la somma delle differenze di punteggio negli incontri misti;
  - `@1` dare il BYE a chi ha meno punti, come nel sistema svizzero.

### Risultati

- **Torneo di esempio, turno 2** (`istanze/turno2.lp`): 8 giocatori, di cui 3 a 2 punti. Un answer set ottimo è `anna-carla, bruno-elena, dario-filippo, giulia-hugo`, con costo [1, 2]. Il costo si legge così:
  - c'è 1 incontro misto (3 su 4 a pari punteggio), ed è inevitabile perché i giocatori a 2 punti sono in numero dispari;
  - la somma delle differenze vale 2.
- Gli abbinamenti ottimi sono 39, tutti elencati da `--opt-mode=optN 0`.
- `simula_torneo.py` gioca 5 turni con iscritti in arrivo nei turni 2 e 4. A ogni turno **verifica in Python, indipendentemente da ASP**, tutti i vincoli. Con 32 giocatori e 7 turni ogni turno si risolve in meno di 0,1 s.
- **Caso impossibile**: con 4 giocatori, dopo 3 turni tutti si sono già affrontati e il quarto turno è **UNSATISFIABLE**. ASP lo dimostra invece di "inventare" un abbinamento, e lo mostra `risultati/simulazione_4_giocatori_unsat.txt`.

### Il risultato più interessante: due formulazioni equivalenti, prestazioni opposte

La traduzione letterale del requisito è `#maximize` sugli incontri a pari punteggio. Ha gli **stessi answer set ottimi** di `#minimize` sugli incontri misti, perché il numero di incontri è fisso (n/2). Ma:

| Giocatori | `#maximize` pari punteggio | `#minimize` incontri misti |
|---|---|---|
| 12 | 0,14 s | 0,000 s |
| 14 | 3,4 s | 0,000 s |
| 16 | **> 60 s** | 0,001 s |
| 32 | **> 60 s** | 0,002 s |

Il motivo: per dimostrare che 8 coppie sono il massimo, il solver deve escludere che ne esistano 9. È un ragionamento di tipo "piccionaia" (pigeonhole), notoriamente difficile per i solver CDCL. Minimizzando gli incontri misti, invece, l'ottimo 0 si certifica subito. **In ASP la formulazione conta quanto il modello.**

---

## Il cut: `ricerca/idastar_cut.pl`

`idastar.pl` usa l'if-then-else (`->`), che taglia ma non mostra il simbolo `!`. Per discutere il cut c'è anche **`idastar_cut.pl`**: lo stesso algoritmo scritto "alla Prolog classico", con clausole separate e quattro cut commentati uno per uno. Dà risultati **identici** (costo, nodi, iterazioni: 27/27 prove, `python test/cut/confronta_cut.py`).

| Cut | Dove | Cosa taglia | Senza il cut | Tipo |
|---|---|---|---|---|
| 1 | fine di `iter_cut/4` | altre soluzioni e iterazioni successive | con `;` si ottengono altri piani, poi piani più lunghi | rosso |
| 2 | `dfs_cut/6`, nodo oltre soglia (schema **cut-fail**) | le clausole "goal" ed "espandi" | un goal oltre la soglia verrebbe restituito: soluzione non ottima | rosso |
| 3 | `dfs_cut/6`, nodo goal | l'espansione del goal | in backtracking, cammini che passano dal goal | rosso |
| 4 | `aggiorna_minimo_cut/1` | la clausola che aggiorna il minimo | **sembra verde, è rosso**: subito dopo c'è `fail`, che fa backtracking dentro il predicato e sovrascrive il minimo con un f più grande | rosso |

Il cut 4 è il più istruttivo: `swipl test/cut/demo_cut4.pl` lo toglie su un grafo di 5 nodi e IDA* restituisce un piano di **costo 4 invece di 3**. Sulle nostre istanze a costi unitari il costo resta ottimo per caso, ma le iterazioni cambiano (p26 con tessere fuori posto: 19 invece di 21). Morale: per classificare un cut bisogna guardare anche **chi chiama** il predicato.

In `domini/puzzle8/puzzle8.pl` c'è invece un **cut verde**: in `applicabile/2` e `trasforma/3`, dopo `nth0(I, S, v), !` (la casella vuota è una sola, cercarne altre sarebbe solo tempo perso).

## Domande frequenti sul codice

| Domanda | Risposta in breve |
|---|---|
| Perché IDA* trova l'ottimo? | Ogni iterazione visita tutti i nodi con f ≤ soglia, e la soglia sale al minimo f escluso. Il primo goal trovato ha quindi f = g minimo, perché h(goal) = 0 e h è ammissibile. |
| Perché A* non riapre i nodi chiusi? | L'euristica è consistente: quando uno stato viene estratto ha già il g ottimo. Con un'euristica solo ammissibile andrebbe gestita la riapertura. |
| A cosa serve `nb_setval`? | A ricordare il minimo f tagliato attraverso il backtracking: una variabile normale verrebbe disfatta. |
| Dove c'è un "cut" nel codice? | Quattro cut rossi commentati in `idastar_cut.pl` (vedi la tabella sopra), il `->` di `idastar.pl` e `astar.pl`, e un **cut verde** in `applicabile/2` del puzzle (c'è una sola vuota). |
| Come sappiamo che l'euristica è ammissibile? | Oltre all'argomento, lo abbiamo verificato su tutti i 181.440 stati con `test/verifica_euristiche.pl`. |
| Perché Manhattan è migliore delle tessere fuori posto? | Entrambe sono ammissibili, ma Manhattan ≥ fuori posto in ogni stato (la domina), quindi è più informata ed espande meno nodi. |
| Perché nei labirinti IDA* va così male? | Mancano i chiusi: le trasposizioni (stessa cella, cammini diversi) vengono riesplorate a ogni iterazione. |
| Cosa elimina il vincolo `:- giocatore(P), not impegnato(P).`? | Gli answer set in cui qualcuno resta senza avversario e senza BYE. |
| Perché `P < Q` nella regola di scelta? | Per non generare lo stesso incontro due volte, come (a,b) e (b,a): dimezza lo spazio di ricerca ed elimina simmetrie. |
| Cosa succede se nessun abbinamento è possibile? | Il programma è UNSATISFIABLE (caso a 4 giocatori). |
