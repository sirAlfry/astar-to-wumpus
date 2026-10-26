/* demo_cut4.pl - confronta idastar_cut con e senza il CUT 4.
   Esecuzione (dalla cartella attivita1-prolog):  swipl test/cut/demo_cut4.pl
*/
:- initialization(main, main).

main :-
    consult('ricerca/idastar_cut'),
    consult('test/cut/grafo_cut4'),
    idastar_cut(A1, C1), iterazioni_ida(K1),
    format("CON il cut 4:   azioni ~w  costo ~w  (~w iterazioni)~n", [A1, C1, K1]),
    % stessa cosa togliendo il cut: si ridefinisce aggiorna_minimo_cut/1
    abolish(aggiorna_minimo_cut/1),
    assertz((aggiorna_minimo_cut(F) :- nb_getval(prossima_soglia, M), M \== inf, M =< F)),
    assertz((aggiorna_minimo_cut(F) :- nb_setval(prossima_soglia, F))),
    idastar_cut(A2, C2), iterazioni_ida(K2),
    format("SENZA il cut 4: azioni ~w  costo ~w  (~w iterazioni)  <- non ottimo!~n", [A2, C2, K2]).
