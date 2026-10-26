/* =====================================================================
   astar.pl  -  Ricerca A* generica (indipendente dal dominio)
   ---------------------------------------------------------------------
   Il dominio deve definire (interfaccia classica della ricerca negli stati):
     iniziale(S)            stato iniziale
     finale(S)              stato obiettivo (puo' esserci piu' di un fatto)
     applicabile(Az, S)     l'azione Az si puo' eseguire in S
     trasforma(Az, S, S1)   eseguire Az in S porta in S1
     euristica(S, H)        stima ammissibile del costo da S a un goal
   Facoltativo:
     costo(Az, S, C)        costo dell'azione (se manca vale 1)

   Uso:   ?- astar(Azioni, Costo).
   Dopo la ricerca:  ?- nodi_espansi(N).

   Idea dell'algoritmo
   - Frontiera (open list) = coda di priorita' ordinata per f = g + h.
     Usiamo library(heaps) di SWI-Prolog: inserimento ed estrazione del
     minimo in O(log n) invece di O(n) di una lista ordinata.
   - Insieme dei chiusi = assoc (albero AVL) da stato a g migliore: test
     di appartenenza in O(log n) invece di member/2 in O(n).
   - Si estrae il nodo con f minima; se e' gia' stato chiuso lo si scarta
     ("cancellazione pigra": nella coda possono restare copie vecchie di
     uno stesso stato con g peggiore); se e' un goal si termina; altrimenti
     lo si chiude e si inseriscono in frontiera i figli non ancora chiusi.
   - Con euristica CONSISTENTE (h(s) <= c(s,a,s') + h(s')) la prima volta
     che uno stato viene estratto ha gia' il g ottimo: non serve mai
     riaprire un nodo chiuso. Le euristiche usate (Manhattan, tessere
     fuori posto) sono consistenti, quindi A* restituisce la soluzione
     ottima.
   - A parita' di f si preferisce il nodo con h minore (piu' vicino al
     goal): la priorita' e' la coppia F-H, confrontata con l'ordine
     standard dei termini.
   ===================================================================== */

:- use_module(library(heaps)).
:- use_module(library(assoc)).
:- ensure_loaded(comune).

% ---------------------------------------------------------------------
% astar(-Azioni, -Costo)
% ---------------------------------------------------------------------
astar(Azioni, Costo) :-
    azzera_contatori,
    iniziale(S0),
    euristica(S0, H0),
    singleton_heap(Open0, H0-H0, nodo(S0, 0, [])),
    empty_assoc(Chiusi0),
    astar_loop(Open0, Chiusi0, AzioniRev, Costo),
    reverse(AzioniRev, Azioni).

% astar_loop(+Open, +Chiusi, -AzioniInvertite, -Costo)
% (quando la frontiera e' vuota get_from_heap fallisce e quindi fallisce
%  anche astar_loop)
% Se la frontiera e' vuota il predicato fallisce: nessun goal
% raggiungibile (A* lo dimostra in tempo finito perche' lo spazio e'
% finito e ogni stato viene espanso al massimo una volta).
astar_loop(Open, Chiusi, AzioniRev, Costo) :-
    get_from_heap(Open, _Prio, nodo(S, G, Cammino), Open1),
    (   get_assoc(S, Chiusi, _)                  % gia' chiuso: copia vecchia
    ->  astar_loop(Open1, Chiusi, AzioniRev, Costo)
    ;   finale(S)                                % goal: soluzione ottima
    ->  AzioniRev = Cammino, Costo = G,
        heap_size(Open1, InCoda), nodi_espansi(E),   % stati tenuti in memoria:
        Mem is InCoda + E, nb_setval(nodi_in_memoria, Mem)   % frontiera + chiusi
    ;   conta_espansione,
        put_assoc(S, Chiusi, G, Chiusi1),
        findall(Az-S1, (applicabile(Az, S), trasforma(Az, S, S1)), Figli),
        aggiungi_figli(Figli, S, G, Cammino, Chiusi1, Open1, Open2),
        astar_loop(Open2, Chiusi1, AzioniRev, Costo)
    ).

% Inserisce in frontiera ogni figlio non ancora chiuso, con f = g + h.
aggiungi_figli([], _, _, _, _, Open, Open).
aggiungi_figli([Az-S1|Altri], S, G, Cammino, Chiusi, Open0, Open) :-
    (   get_assoc(S1, Chiusi, _)
    ->  Open1 = Open0
    ;   costo_azione(Az, S, C),
        G1 is G + C,
        euristica(S1, H1),
        F1 is G1 + H1,
        add_to_heap(Open0, F1-H1, nodo(S1, G1, [Az|Cammino]), Open1)
    ),
    aggiungi_figli(Altri, S, G, Cammino, Chiusi, Open1, Open).
