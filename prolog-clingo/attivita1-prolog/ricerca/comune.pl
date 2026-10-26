/* =====================================================================
   comune.pl  -  Predicati di servizio condivisi da astar.pl e idastar.pl
   ===================================================================== */

:- dynamic costo/3.          % se il dominio non lo definisce, ogni azione costa 1

% costo_azione(+Az, +S, -C): costo dell'azione Az nello stato S.
costo_azione(Az, S, C) :-
    (   costo(Az, S, C0) -> C = C0 ; C = 1 ).

% Contatore dei nodi espansi: variabile globale non backtrackabile.
azzera_contatori :-
    nb_setval(nodi_espansi, 0),
    nb_setval(iterazioni_ida, 0),
    nb_setval(nodi_in_memoria, 0).

conta_espansione :-
    nb_getval(nodi_espansi, N), N1 is N + 1, nb_setval(nodi_espansi, N1).

nodi_espansi(N) :- nb_getval(nodi_espansi, N).
iterazioni_ida(K) :- nb_getval(iterazioni_ida, K).
nodi_in_memoria(M) :- nb_getval(nodi_in_memoria, M).
