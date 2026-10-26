/* =====================================================================
   idastar.pl  -  Ricerca IDA* (Iterative Deepening A*) generica
   ---------------------------------------------------------------------
   Stessa interfaccia del dominio di astar.pl:
     iniziale/1, finale/1, applicabile/2, trasforma/3, euristica/2,
     costo/3 facoltativo (default 1).

   Uso:   ?- idastar(Azioni, Costo).
          ?- nodi_espansi(N), iterazioni_ida(K).

   Idea dell'algoritmo
   - E' una ricerca in profondita' limitata, ma il limite non e' sulla
     profondita' bensi' su f = g + h (la "soglia").
   - Prima soglia = h(s0). In ogni iterazione si visita in profondita'
     ogni nodo con f <= soglia. Un nodo con f > soglia viene tagliato e
     si ricorda il valore di f piu' piccolo tra quelli tagliati.
   - Se l'iterazione non trova il goal, la nuova soglia e' quel minimo:
     e' il piu' piccolo aumento che permette di vedere almeno un nodo in
     piu'. Con euristica ammissibile la prima soluzione trovata e'
     ottima (come A*).
   - Memoria lineare nella profondita' della soluzione (si tiene solo il
     cammino corrente), al prezzo di rigenerare piu' volte i nodi dei
     livelli superiori.
   - Il controllo dei cicli e' fatto solo sul cammino corrente
     (\+ memberchk): IDA* non ha la lista dei chiusi, quindi uno stesso
     stato raggiunto per cammini diversi viene rivisitato (problema
     serio nei labirinti, dove ci sono molti cammini equivalenti).
   - Il minimo f tagliato e' salvato con nb_setval/nb_getval: e' una
     variabile globale che sopravvive al backtracking (come assert/
     retract, ma piu' efficiente).
   - Terminazione con goal irraggiungibile: grazie al controllo dei cicli
     i cammini semplici sono finiti, quindi prima o poi un'iterazione
     non taglia piu' nulla (minimo = inf) e il predicato fallisce.
     Il numero di cammini semplici pero' e' esponenziale: in pratica
     IDA* non riesce a dimostrare l'irraggiungibilita' (vedi i test).
   ===================================================================== */

:- ensure_loaded(comune).

idastar(Azioni, Costo) :-
    azzera_contatori,
    iniziale(S0),
    euristica(S0, H0),
    ida_iterazione(S0, H0, Azioni, Costo).

% ida_iterazione(+S0, +Soglia, -Azioni, -Costo)
ida_iterazione(S0, Soglia, Azioni, Costo) :-
    nb_getval(iterazioni_ida, K), K1 is K + 1, nb_setval(iterazioni_ida, K1),
    nb_setval(prossima_soglia, inf),
    (   dfs_soglia(S0, 0, Soglia, [S0], Azioni, Costo)
    ->  true                                   % il cut di -> blocca altre soluzioni
    ;   nb_getval(prossima_soglia, Nuova),
        Nuova \== inf,                         % nessun nodo tagliato: fallimento
        ida_iterazione(S0, Nuova, Azioni, Costo)
    ).

% dfs_soglia(+S, +G, +Soglia, +Cammino, -Azioni, -Costo)
dfs_soglia(S, G, Soglia, Cammino, Azioni, Costo) :-
    euristica(S, H),
    F is G + H,
    (   F > Soglia
    ->  aggiorna_minimo(F), fail               % taglio: ricordo f e fallisco
    ;   finale(S)
    ->  Azioni = [], Costo = G,
        length(Cammino, L), nb_setval(nodi_in_memoria, L)  % solo il cammino corrente
    ;   conta_espansione,
        applicabile(Az, S),
        trasforma(Az, S, S1),
        \+ memberchk(S1, Cammino),            % niente cicli sul cammino corrente
        costo_azione(Az, S, C),
        G1 is G + C,
        Azioni = [Az|AltreAzioni],
        dfs_soglia(S1, G1, Soglia, [S1|Cammino], AltreAzioni, Costo)
    ).

aggiorna_minimo(F) :-
    nb_getval(prossima_soglia, M),
    (   ( M == inf ; F < M ) -> nb_setval(prossima_soglia, F) ; true ).
