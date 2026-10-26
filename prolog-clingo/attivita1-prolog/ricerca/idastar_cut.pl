/* =====================================================================
   idastar_cut.pl  -  IDA* scritto "alla Prolog classico", con i CUT
   ---------------------------------------------------------------------
   Stesso algoritmo di idastar.pl, ma invece dell'if-then-else (->) usa
   clausole separate e cut espliciti (!). Serve a discutere il cut
   all'orale: ogni ! e' commentato con COSA taglia e COSA succederebbe
   togliendolo. Risultati identici a idastar.pl (stessi costi, nodi e
   iterazioni su tutte le istanze: test/cut/confronta_cut.py).

   Uso:  swipl esegui.pl idastar_cut puzzle8 test/puzzle8/p20.pl
         ?- [ricerca/idastar_cut, domini/puzzle8/puzzle8, 'test/puzzle8/p12'].
         ?- idastar_cut(Azioni, Costo).

   Promemoria sul cut: quando viene eseguito rende definitive tutte le
   scelte fatte dall'inizio della clausola fino al ! (sottogoal a sinistra
   e clausole alternative dello stesso predicato). Non tocca i goal alla
   sua destra. Puo' far perdere completezza, non correttezza.
   ===================================================================== */

:- ensure_loaded(comune).

idastar_cut(Azioni, Costo) :-
    azzera_contatori,
    iniziale(S0),
    euristica(S0, H0),
    iter_cut(S0, H0, Azioni, Costo).

% ---------------------------------------------------------------------
% iter_cut(+S0, +Soglia, -Azioni, -Costo): una iterazione di IDA*
% ---------------------------------------------------------------------
iter_cut(S0, Soglia, Azioni, Costo) :-
    nb_getval(iterazioni_ida, K), K1 is K + 1, nb_setval(iterazioni_ida, K1),
    nb_setval(prossima_soglia, inf),
    dfs_cut(S0, 0, Soglia, [S0], Azioni, Costo),
    !.
    % CUT 1 (rosso). Trovata la prima soluzione, elimina:
    %  - le altre soluzioni della stessa iterazione (ancora ottime);
    %  - la seconda clausola di iter_cut, cioe' le iterazioni successive.
    % Senza questo cut, chiedendo altre soluzioni (;) Prolog restituirebbe
    % prima altri piani ottimi, poi passerebbe alle soglie successive e
    % restituirebbe piani PIU' LUNGHI: l'insieme delle risposte cambia,
    % quindi il cut e' rosso. La prima risposta invece e' la stessa.
iter_cut(S0, _, Azioni, Costo) :-
    nb_getval(prossima_soglia, Nuova),
    Nuova \== inf,                   % nessun nodo tagliato: non c'e' soluzione
    iter_cut(S0, Nuova, Azioni, Costo).

% ---------------------------------------------------------------------
% dfs_cut(+S, +G, +Soglia, +Cammino, -Azioni, -Costo)
% Tre clausole, provate nell'ordine: taglio, goal, espansione.
% ---------------------------------------------------------------------
dfs_cut(S, G, Soglia, _, _, _) :-
    euristica(S, H),
    F is G + H,
    F > Soglia,
    !,
    aggiorna_minimo_cut(F),
    fail.
    % CUT 2 + fail (rosso): il nodo supera la soglia, si ricorda il suo f
    % e si fallisce SENZA provare le altre clausole.
    % Senza il cut, dopo il fail Prolog proverebbe la clausola 2: se S
    % fosse un goal restituirebbe una soluzione con f > soglia, cioe' non
    % ottima. Poi la clausola 3 espanderebbe il nodo come se la soglia
    % non esistesse. E' il classico schema "cut-fail".
dfs_cut(S, G, _, Cammino, [], G) :-
    finale(S),
    !,
    length(Cammino, L), nb_setval(nodi_in_memoria, L).
    % CUT 3 (rosso): arrivati a un goal non lo si espande.
    % Senza il cut, chiedendo altre soluzioni si espanderebbe anche il
    % goal (clausola 3), trovando cammini che passano dal goal e poi
    % ritornano a un goal: piu' lunghi, e comunque entro la soglia solo
    % se di pari costo. Non cambia la prima risposta, ma cambia le
    % successive.
dfs_cut(S, G, Soglia, Cammino, [Az|AltreAzioni], Costo) :-
    conta_espansione,
    applicabile(Az, S),
    trasforma(Az, S, S1),
    \+ memberchk(S1, Cammino),            % \+ e' a sua volta realizzato con un cut
    costo_azione(Az, S, C),
    G1 is G + C,
    dfs_cut(S1, G1, Soglia, [S1|Cammino], AltreAzioni, Costo).
    % Nessun cut qui: il backtracking su applicabile/2 E' la ricerca in
    % profondita' (prova la prossima azione quando un sottoalbero fallisce).
    % Un cut dopo applicabile/2 renderebbe IDA* incompleto: proverebbe
    % solo la prima azione applicabile di ogni stato.

% ---------------------------------------------------------------------
aggiorna_minimo_cut(F) :-
    nb_getval(prossima_soglia, M),
    M \== inf, M =< F,
    !.
aggiorna_minimo_cut(F) :-
    nb_setval(prossima_soglia, F).
    % CUT 4: SEMBRA verde ma e' ROSSO, ed e' il piu' istruttivo.
    % La prima clausola dice "il minimo attuale e' gia' <= F: non fare
    % niente", la seconda "aggiorna il minimo". Il cut sembra servire solo
    % a risparmiare un tentativo... ma guardate chi chiama questo predicato:
    % in dfs_cut, clausola 1, subito dopo c'e' FAIL. Il fail fa backtracking
    % DENTRO aggiorna_minimo_cut: senza il cut Prolog proverebbe la seconda
    % clausola e sovrascriverebbe il minimo con un F piu' grande. La soglia
    % successiva sarebbe sbagliata (cresce troppo): IDA* salterebbe
    % soglie e puo' restituire soluzioni NON ottime. Sulle nostre istanze
    % (costi unitari) il costo resta ottimo ma le iterazioni cambiano
    % (p26 con fuori posto: 19 invece di 21); con costi diversi l'errore
    % diventa visibile: test/cut/demo_cut4.pl trova costo 4 invece di 3.
