/* =====================================================================
   esegui.pl  -  Esegue un algoritmo su un'istanza e stampa le misure
   ---------------------------------------------------------------------
   Da riga di comando (dalla cartella attivita1-prolog):

     swipl esegui.pl <algoritmo> <dominio> <istanza> [euristica] [timeout_s]

     algoritmo : astar | idastar
     dominio   : labirinto | puzzle8
     euristica : manhattan | fuori_posto | zero   (solo puzzle8)
     timeout_s : secondi massimi (default 60)

   Esempi:
     swipl esegui.pl astar   labirinto test/labirinto/lab1_piccolo.pl
     swipl esegui.pl idastar puzzle8   test/puzzle8/p20.pl fuori_posto 120

   Stampa una riga CSV:
     algoritmo,dominio,istanza,euristica,esito,costo,nodi_espansi,
     iterazioni,nodi_in_memoria,tempo_cpu_s,azioni
   nodi_in_memoria = per A* frontiera + chiusi al termine, per IDA* la
   lunghezza del cammino corrente (la memoria e' lineare).
   esito = ok | nessuna_soluzione | timeout

   In modalita' interattiva (swipl, poi ?- [esegui].) si possono usare
   direttamente astar/2 e idastar/2 dopo aver caricato dominio e istanza,
   ad esempio:
     ?- [ricerca/astar, domini/puzzle8/puzzle8, 'test/puzzle8/p12'].
     ?- astar(Azioni, Costo), nodi_espansi(N).
   ===================================================================== */

:- initialization(main, main).

main :-
    current_prolog_flag(argv, Argv),
    (   Argv = [Alg, Dom, Ist | Resto]
    ->  true
    ;   format(user_error, "uso: swipl esegui.pl <astar|idastar> <labirinto|puzzle8> <istanza> [euristica] [timeout]~n", []),
        halt(1)
    ),
    opzioni(Resto, Heur, Timeout),
    carica(Alg, Dom, Ist),
    (   Dom == puzzle8 -> imposta_euristica(Heur) ; true ),
    Goal =.. [Alg, Azioni, Costo],
    statistics(cputime, T0),
    catch(call_with_time_limit(Timeout,
              ( call(Goal) -> Esito = ok ; Esito = nessuna_soluzione )),
          time_limit_exceeded, Esito = timeout),
    statistics(cputime, T1),
    T is T1 - T0,
    nodi_espansi(N),
    (   Esito == ok -> nodi_in_memoria(M) ; M = '' ),
    (   memberchk(Alg, [idastar, idastar_cut]) -> iterazioni_ida(K) ; K = '' ),
    (   Esito == ok -> length(Azioni, _), atomic_list_concat(Azioni, ' ', AzStr), C = Costo
    ;   AzStr = '', C = '' ),
    file_base_name(Ist, IstNome),
    (   Dom == puzzle8 -> HeurOut = Heur ; HeurOut = manhattan_min_uscite ),
    format("~w,~w,~w,~w,~w,~w,~w,~w,~w,~4f,~w~n",
           [Alg, Dom, IstNome, HeurOut, Esito, C, N, K, M, T, AzStr]).

opzioni([], manhattan, 60).
opzioni([H], H1, 60) :- atom_string(H1, H).
opzioni([H, T|_], H1, T1) :- atom_string(H1, H), atom_number(T, T1).

carica(Alg, Dom, Ist) :-
    atomic_list_concat(['ricerca/', Alg], AlgFile),
    atomic_list_concat(['domini/', Dom, '/', Dom], DomFile),
    ensure_loaded(AlgFile),
    ensure_loaded(DomFile),
    load_files(Ist, [if(true)]).
