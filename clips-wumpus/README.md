# Parte 2: agenti CLIPS per il mondo del Wumpus

Una variante del classico **mondo del Wumpus**: una caverna a griglia, buia, con muri, pozzi senza fondo, un Wumpus e dell'oro. L'agente percepisce solo brezza (pozzo vicino), puzza (Wumpus vicino) e scintillio (oro nella cella), si muove una cella alla volta, può dichiarare dove crede ci sia un pozzo (premio se ha ragione, penalità se sbaglia) e deve uscire dalla cella di partenza prima di finire l'energia.

Qui ci sono tre agenti di "intelligenza" crescente, tutti organizzati in **moduli** CLIPS. Il terzo usa i **certainty factors**. Sono confrontati su 9 mappe "a tema" e su 100 mappe casuali, tutte nostre.

```
clips-wumpus/
├── simulatore/          NON incluso: il simulatore Python fornito dal corso (vedi sotto)
├── agenti/
│   ├── agente-base/agent.clp       1 - "prudente"  (PERCEZIONE, DECISIONE, AZIONE)
│   ├── agente-avanzato/agent.clp   2 - "logico"    (+ INFERENZA, DISTANZE)
│   └── agente-3/agent.clp          3 - "stratega"  (+ CERTEZZA con i certainty factors)
├── mappe/               m01..m09 a tema (ognuna ha un campo "descrizione"), casuali/ (100)
├── strumenti/
│   ├── esegui_headless.py   esegue un agente senza grafica (stesso ciclo della GUI)
│   ├── esperimenti.py       tutti gli agenti su tutte le mappe -> risultati/*.csv
│   ├── genera_mappe.py      mappe casuali riproducibili (seed)
│   ├── calibrazione_cf.py   i CF stimano bene il pericolo reale?
│   ├── oracolo.py           limite superiore: cosa farebbe chi vede tutta la mappa
│   ├── oracolo_logico.py    le regole dell'agente 2 deducono TUTTO il deducibile?
│   ├── disegna_partita.py   immagine della mappa con il percorso di un agente
│   ├── prepara_file_docente.py  ricrea le mappe del corso, per chi ha il simulatore
│   └── grafici.py
└── risultati/           CSV e grafici
```

## Il simulatore

Gli agenti girano su un simulatore Python (con `clipspy` e un'interfaccia `tkinter`) fornito dal corso. È materiale didattico che non si può ridistribuire, quindi **non è in questo repository**. Chi segue il corso copia i suoi file in `clips-wumpus/simulatore/` e, se vuole anche le mappe del corso, lancia `python strumenti\prepara_file_docente.py`.

L'interfaccia tra simulatore e agente è semplice:
- a ogni passo il simulatore asserisce un fatto `percept` (posizione, brezza, puzza, scintillio, energia) e aggiorna `counter`;
- poi esegue `(run)` e legge **un solo** fatto `(action (move ...))`.

## Come si esegue (Windows, PowerShell)

Serve **Python 3.12 o superiore**: il simulatore usa una sintassi delle f-string introdotta in quella versione.

```powershell
cd clips-wumpus
python -m venv .venv
.\.venv\Scripts\Activate.ps1           # se e' bloccato: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
pip install clipspy matplotlib         # tkinter e' gia' incluso nel Python ufficiale per Windows

# Con interfaccia grafica: dalla cartella simulatore, perche' carica un'immagine con percorso relativo
cd simulatore
python wumpus.py -m ..\mappe\m01_dietro_i_pozzi.json -a ..\agenti\agente-3\agent.clp
cd ..

# Senza grafica (veloce, stampa il ragionamento dell'agente passo per passo)
python strumenti\esegui_headless.py -m mappe\m04_deduzione.json -a agenti\agente-avanzato\agent.clp --traccia

# Tutti gli esperimenti (circa 2 minuti) e i grafici
python strumenti\esperimenti.py --soglie
python strumenti\calibrazione_cf.py
python strumenti\oracolo.py
python strumenti\oracolo_logico.py
python strumenti\grafici.py
```

Nella GUI, **Step** esegue un passo e **Run** li esegue di seguito. Nel riquadro *Facts* si vede la memoria dell'agente: `sicura`, `pozzo`, `cf`, `dist`, ...

---

## L'architettura comune: un passo = un giro dei moduli

```
MAIN ──(counter cambia)──> focus PERCEZIONE  INFERENZA  CERTEZZA  DISTANZE  DECISIONE  AZIONE
                                (tutti)       (2, 3)     (3)       (2, 3)    (tutti)    (tutti)
```

- **MAIN**: definisce ed esporta i template. La regola `avvia-passo` scatta perché `counter` viene **modificato** dal simulatore: è un fatto nuovo, quindi la rifrazione non la blocca. Con `(focus A B C ...)` impila i moduli; ognuno esce quando la sua agenda è vuota e passa il controllo al successivo.
- **PERCEZIONE**: aggiorna posizione ed energia, marca la cella come visitata e sicura, scarta i percept vecchi. Riconosce gli **urti**: se l'agente ha chiesto un movimento ed è rimasto fermo, la cella di destinazione è un muro o è fuori mappa.
- **INFERENZA**, agenti 2 e 3: deduzione logica.
  - Niente brezza in una cella significa nessun pozzo nelle celle vicine; niente puzza, nessun Wumpus.
  - Ogni brezza ha i suoi **candidati**. Quando ne resta uno solo, quello è un **pozzo certo**, per eliminazione. Lo stesso vale per il Wumpus.
  - **C'è un solo Wumpus**, quindi deve essere adiacente a *tutte* le celle in cui si è sentita puzza.
  - Le saliance separano le fasi: prima si generano i candidati, poi si eliminano, infine si conclude. Così non si trae una conclusione prima di avere tutti i candidati.
- **CERTEZZA**, solo agente 3: certainty factors (vedi sotto).
- **DISTANZE**, agenti 2 e 3: cammini minimi con una **BFS "a ondata" scritta a regole**.
  - Dai bersagli (d = 0) si propaga d+1 alle celle vicine percorribili.
  - La regola `accorcia` corregge le distanze trovate prima lungo un giro più lungo (Bellman-Ford).
  - Un **gettone** `(ricalcola)` fa cancellare i campi del passo precedente una sola volta, all'inizio. Senza, le distanze nuove verrebbero cancellate appena create: un ciclo infinito.
- **DECISIONE**: regole in ordine di priorità (salience). Ognuna richiede `(not (decisione))`, quindi a ogni passo ne scatta **al massimo una**. Le regole di "cambio fase" hanno salience più alta e non decidono nulla.
- **AZIONE**: trasforma la decisione nell'unico fatto `action` e ricorda l'ultima mossa, che serve a riconoscere gli urti al passo dopo.

## I tre agenti

| | 1 – prudente | 2 – logico | 3 – stratega |
|---|---|---|---|
| Quando una cella è sicura | solo se è vicina di una cella **senza brezza e senza puzza** | combina celle diverse (no-pozzo da una, no-Wumpus da un'altra) | come il 2 |
| Pozzi e Wumpus | non li deduce | per eliminazione, "un solo Wumpus" | come il 2, più i **CF** sulle celle incerte |
| Dichiarazione dei pozzi | mai | pozzi certi, quando ci passa accanto | anche CF ≥ 0,75; va apposta nelle celle adiacenti |
| Movimento | profondità con la **pila** del cammino (torna indietro sui suoi passi) | **cammino minimo** verso la cella sicura più vicina | come il 2 |
| Oro | lo prende subito | lo prende subito | **prima** esplora e dichiara, poi torna all'oro |
| Energia | ritorno se energia ≤ lunghezza della pila + 2 | ritorno se energia ≤ distanza da casa + 2 | riserva per tornare all'oro **e** da lì a casa |
| Nessuna cella sicura | torna a casa | torna a casa | **rischio calcolato** nella cella meno pericolosa, se pericolo ≤ 0,3 e l'oro non è stato trovato |

### I certainty factors dell'agente 3

- Per ogni percezione (brezza o puzza) in una cella B con k candidati, ogni candidato riceve un'evidenza di **1/k**.
- Se la brezza è già **spiegata** da un pozzo certo vicino, l'evidenza è solo un piccolo CF "a priori" (0,2): un secondo pozzo è possibile ma poco probabile.
- Le evidenze di celle diverse si combinano con la regola MYCIN: **CF = a + b(1 − a)**.
- I pozzi certi hanno CF = 1, le celle escluse non hanno CF.
- **Pericolo di una cella** = combinazione del CF pozzo e del CF Wumpus.
- A parità di pericolo si sceglie la cella che scopre più celle nuove (guadagno informativo).

**I CF sono affidabili?** `calibrazione_cf.py` registra ogni ingresso "a rischio" sulle 100 mappe casuali, con soglia 1 (rischia sempre):

| CF stimato | Ingressi | Morti | Frequenza reale |
|---|---|---|---|
| 0,2–0,3 | 68 | 3 | 0,04 |
| 0,3–0,4 | 18 | 5 | 0,28 |
| 0,4–0,6 | 74 | 28 | 0,38 |
| 0,6–1 | 3 | 2 | 0,67 |

La stima è **monotona**: a CF più alto corrisponde un pericolo reale più alto. È anche **prudente**, perché sovrastima il rischio sotto 0,3. È quanto basta per decidere, ed è il punto forte dei CF: modulari ed economici, anche se non sono probabilità vere.

## Risultati

**Mappe a tema** (premio finale; ogni mappa ha un campo `descrizione` che spiega cosa mette alla prova):

| Mappa | 1 prudente | 2 logico | 3 stratega | Cosa mostra |
|---|---|---|---|---|
| m01_dietro_i_pozzi | 0 | 25 | **225** | il 2 si ferma dove finisce la certezza; il 3 dichiara 5 pozzi, rischia una cella con pericolo 0,2 e prende l'oro |
| m02_oro_vicino | 100 | 100 | **125** | |
| m03_classica_RN | 0 | 125 | 125 | la disposizione dell'esempio classico del Russell–Norvig |
| m04_deduzione | **0** | 125 | 125 | per passare bisogna combinare due celle |
| m05_wumpus_incrociato | 100 | 100 | **125** | |
| m06_vicolo_rischioso | 0 | 0 | **25** | l'oro richiede una scommessa 50/50: il 3 rinuncia |
| m07_poca_energia | 0 | 0 | 0 | test di sicurezza: tutti tornano vivi (finire l'energia costa −100) |
| m08_labirinto_muri | 0 | 100 | 100 | cammini lunghi e molti urti |
| m09_oro_in_partenza | 100 | 125 | 125 | il primo `grab`, "alla cieca", prende l'oro subito |

**100 mappe casuali** (da 5×5 a 8×8, ~10% muri, ~12% pozzi; `risultati/riepilogo.csv`):

| Agente | Premio medio | Oro | Morti | Pozzi giusti (media) | Pozzi sbagliati (media) |
|---|---|---|---|---|---|
| 1 – prudente | 24,0 | 24% | 0% | 0 | 0 |
| 2 – logico | 38,8 | 27% | 0% | 0,47 | 0 |
| 3 – stratega (soglia 0,3) | **58,5** | 30% | 0% | 1,16 | 0,02 |
| 3 con soglia 0,5 | 69,5 | 58% | **35%** | 1,91 | 0,05 |

- **Più conoscenza nella KB porta più premio, senza morire.** Il premio medio cresce di 2,4 volte dall'agente 1 al 3.
- L'oro cresce poco, dal 24% al 30%: il perché lo spiegano i due oracoli qui sotto.
- Il guadagno viene dalle **dichiarazioni dei pozzi** e dalla scelta di prendere l'oro **per ultimo**. È stata possibile capendo come il simulatore calcola il premio: il costo dei passi consuma energia ma non entra nel premio.
- **Prudenza contro audacia** (grafico `soglia_rischio.png`):
  - con soglia 0,5 l'agente 3 prende l'oro nel 58% delle mappe e ha un premio medio più alto, ma muore nel 35% dei casi;
  - con 0,3 non muore praticamente mai.

  Abbiamo scelto 0,3 come default: in una dimostrazione dal vivo, morire "costa" più di 11 punti di media. La soglia è comunque un parametro: `(parametro (nome soglia-rischio) (valore 0.3))` nella `deffacts` di MAIN.

### Gli oracoli: quanto si poteva fare meglio?

**Oracolo onnisciente** (`strumenti/oracolo.py`): vede tutta la mappa. Senza mai morire potrebbe prendere l'oro in **84 mappe su 100** e dichiarare in media 4,5 pozzi, per un premio medio massimo di **195,8**. L'agente 3 arriva al 30% di questo massimo.

**Oracolo logico** (`strumenti/oracolo_logico.py`): prende le osservazioni fatte davvero dall'agente e calcola con un **model checking completo**, indipendente dalle regole CLIPS, quali celle erano *dimostrabilmente* sicure. Abbiamo controllato che non sbagli: 109 celle dichiarate sicure, nessuna era un pozzo o il Wumpus.

| Agente | Partite chiuse lasciando inesplorate celle dimostrabilmente sicure |
|---|---|
| 1 – prudente | 7 su 100 (11 celle) |
| 2 – logico | **0 su 100** |
| 3 – stratega | **0 su 100** |

Le regole d'inferenza dell'agente 2 sono quindi **complete** per questo gioco: tutto ciò che la logica permette di esplorare, lo esplora. La distanza tra l'oro "possibile" (84%) e quello preso con la sola logica (27%) **non si colma con regole migliori, ma solo rischiando**. È esattamente ciò che fa l'agente 3, e il grafico `soglia_rischio.png` mostra quanto costa (con soglia 0,5 l'oro sale al 58%, ma le morti al 35%).

Perché l'eliminazione basta? Con vincoli "almeno un pozzo vicino a ogni brezza" una cella candidata può sempre essere un pozzo: la si dimostra libera solo con una cella senza brezza accanto, ed è certa solo quando è l'unico candidato rimasto. Sono esattamente le due regole dell'agente 2. Per il Wumpus, che è uno solo, serve in più l'intersezione delle puzze, anch'essa presente.

## Situazioni particolari gestite dagli agenti

- **Nessuna percezione al primo passo.** L'agente deve agire "alla cieca": usa `grab`, l'unica azione innocua, che costa 1 di energia e prende l'oro se è sulla casella di partenza (mappa m09).
- **Nessuna azione decisa.** Senza un fatto `action` il simulatore eseguirebbe un movimento di default, potenzialmente mortale. Ogni agente ha una regola "paracadute" a salience minima che asserisce `grab`.
- **Premio ed energia.** Il premio dipende solo da oro, dichiarazioni dei pozzi e morte; finire l'energia vale come una morte. Tutti gli agenti controllano l'energia, e l'agente 3 prende l'oro per ultimo.
- **Dopo il grab.** Anche se la mappa prevede la fine della partita al grab, l'agente non lo dà per scontato: dopo aver preso l'oro torna a casa ed esce.
- **Ogni pozzo si dichiara una volta sola** (fatto `dichiarato`), e `quit` si usa solo nella cella di partenza.
- **Coordinate.** `up` diminuisce la y e `down` la aumenta; le dichiarazioni dei pozzi (`pit-north`, ...) usano la stessa convenzione.

## Domande frequenti su CLIPS

Per ogni domanda c'è un esempio nel nostro codice:

| Domanda | Dove si vede nel nostro codice |
|---|---|
| Elementi fondamentali di CLIPS? | Fatti (template `pos`, `oss`, ...), regole (`defrule`), agenda, motore inferenziale. |
| Ciclo di funzionamento? | Match → conflict resolution (salience, poi strategia *depth*) → act. Un `(run)` va avanti finché tutte le agende sono vuote. |
| Cos'è la rifrazione? | Una regola non scatta due volte sugli **stessi** fatti. Per questo `avvia-passo` riparte a ogni passo (`counter` è modificato, quindi è un fatto nuovo) e le sorgenti di DISTANZE includono `(turno ...)`. |
| Moduli e focus? | Il `(focus ...)` di `avvia-passo` e i template esportati da MAIN. Un modulo esce quando la sua agenda è vuota. |
| Come decide se entrare in una cella? | Agente 2: solo se è `sicura`, cioè no-pozzo **e** no-Wumpus dimostrati. Agente 3: altrimenti valuta il pericolo stimato con i CF. |
| Come torna a casa? | Agente 1: ripercorre la pila. Agenti 2 e 3: seguono il campo `dist casa`, che passa **solo su celle visitate**, così non può incontrare muri nascosti. |
| Un errore trovato durante i test? | L'agente 3 finiva l'energia. Una funzione usata dentro un pattern veniva valutata quando arrivava il fatto `energia`, *prima* che le distanze del passo esistessero. Soluzione: calcolare la riserva come **fatto** a fine DISTANZE. È un ottimo esempio di come funziona il pattern matching (Rete). |

**Sviluppi futuri:**
- probabilità esatte con una rete bayesiana al posto dei CF;
- apprendimento della soglia di rischio (reinforcement learning);
- pianificazione con A* invece della BFS a ondata.
