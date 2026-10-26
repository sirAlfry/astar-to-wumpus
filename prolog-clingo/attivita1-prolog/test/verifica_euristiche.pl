/* =====================================================================
   verifica_euristiche.pl  -  Dimostrazione "per enumerazione" che le
   euristiche usate sono AMMISSIBILI e CONSISTENTI
   ---------------------------------------------------------------------
   Invece di fidarsi dell'argomento a parole, si calcola la distanza VERA
   d*(s) di ogni stato dal goal con una visita in ampiezza (BFS) all'indietro
   e si controlla, stato per stato e arco per arco:

     ammissibilita':  h(s) =< d*(s)                       per ogni stato s
     consistenza:     h(s) =< c(s,s') + h(s')            per ogni arco s -> s'
                      (qui c = 1 e gli archi sono reversibili, quindi
                       equivale a |h(s) - h(s')| =< 1)
     dominanza:       h_manhattan(s) >= h_fuori_posto(s)   (solo puzzle)

   Puzzle dell'8: si visitano TUTTI i 181.440 stati risolvibili.
   Labirinti: ogni cella libera di ogni istanza di test/labirinto/.
   Le mosse sono reversibili, quindi la BFS dal goal (multi-sorgente sulle
   uscite, per il labirinto) da' esattamente la distanza dal goal.

   Esecuzione (dalla cartella attivita1-prolog, circa 1 minuto):
       swipl test/verifica_euristiche.pl
   ===================================================================== */

:- initialization(main, main).
:- use_module(library(assoc)).

main :-
    verifica_puzzle,
    forall(member(F, ['lab1_piccolo', 'lab2_grande', 'lab3_trappola',
                      'lab4_senza_uscita', 'lab5_aperto_20', 'lab6_aperto_30']),
           verifica_labirinto(F)).

% ---------------------------------------------------------------------
% BFS a livelli: Frontiera = stati a distanza D, Visti = assoc stato->dist
% ---------------------------------------------------------------------
bfs([], _, Visti, Visti) :- !.
bfs(Frontiera, D, Visti0, Visti) :-
    D1 is D + 1,
    espandi(Frontiera, D1, Visti0, Visti1, [], Prossima),
    bfs(Prossima, D1, Visti1, Visti).

espandi([], _, V, V, P, P).
espandi([S|Ss], D1, V0, V, P0, P) :-
    findall(S1, (applicabile(A, S), trasforma(A, S, S1)), Figli),
    aggiungi(Figli, D1, V0, V1, P0, P1),
    espandi(Ss, D1, V1, V, P1, P).

aggiungi([], _, V, V, P, P).
aggiungi([S|Ss], D, V0, V, P0, P) :-
    (   get_assoc(S, V0, _)
    ->  V1 = V0, P1 = P0
    ;   put_assoc(S, V0, D, V1), P1 = [S|P0]
    ),
    aggiungi(Ss, D, V1, V, P1, P).

sorgenti(Goals, Visti) :-
    empty_assoc(V0),
    foldl([G, A0, A]>>put_assoc(G, A0, 0, A), Goals, V0, Visti).

% ---------------------------------------------------------------------
% Controllo generico: su tutti gli stati raggiunti dalla BFS
% ---------------------------------------------------------------------
% controlla(+Visti, +Tutti, +Nome) stampa il riepilogo per l'euristica attiva.
% L'ammissibilita' si controlla sugli stati da cui il goal e' raggiungibile
% (Visti: per gli altri d* e' infinito e h =< d* vale banalmente); la
% consistenza su TUTTI gli stati (Tutti), anche quelli senza via d'uscita.
controlla(Visti, Tutti, Nome) :-
    assoc_to_list(Visti, Coppie),
    length(Coppie, N), length(Tutti, NT),
    aggregate_all(count, (member(S-D, Coppie), euristica(S, H), H > D), NonAmm),
    aggregate_all(count, (member(S, Tutti), applicabile(A, S), trasforma(A, S, S1),
                          euristica(S, H), euristica(S1, H1), H > 1 + H1), NonCons),
    aggregate_all(sum(H), (member(S-_, Coppie), euristica(S, H)), SommaH),
    aggregate_all(sum(D), member(_-D, Coppie), SommaD),
    (   SommaD > 0 -> Qualita is 100 * SommaH / SommaD ; Qualita = 100 ),
    esito(NonAmm, EA), esito(NonCons, EC),
    format("  ~w~t~22|~d/~d stati col goal raggiungibile   ammissibile: ~w   consistente: ~w   h medio = ~1f% di d* medio~n",
           [Nome, N, NT, EA, EC, Qualita]).

esito(0, 'SI') :- !.
esito(K, Testo) :- format(atom(Testo), "NO (~d violazioni)", [K]).

% ---------------------------------------------------------------------
% Puzzle dell'8
% ---------------------------------------------------------------------
verifica_puzzle :-
    format("~nPuzzle dell'8 (tutti gli stati risolvibili)~n"),
    consult('domini/puzzle8/puzzle8'),
    finale(G),
    sorgenti([G], V0),
    statistics(cputime, T0),
    bfs([G], 0, V0, Visti),
    statistics(cputime, T1),
    T is T1 - T0,
    assoc_to_values(Visti, Ds), max_list(Ds, Max),
    assoc_to_keys(Visti, Stati),
    format("  BFS dal goal: ~d stati in ~1f s, distanza massima ~d mosse~n",
           [181440, T, Max]),
    forall(member(E, [manhattan, fuori_posto]),
           ( imposta_euristica(E), controlla(Visti, Stati, E) )),
    % dominanza: Manhattan >= fuori posto in ogni stato
    aggregate_all(count, (member(S, Stati), h(manhattan, S, HM), h(fuori_posto, S, HF), HM < HF), Viol),
    esito(Viol, ED),
    format("  Manhattan domina fuori_posto in ogni stato: ~w~n", [ED]),
    imposta_euristica(manhattan).

% ---------------------------------------------------------------------
% Labirinti: si ricarica il dominio e l'istanza ogni volta
% ---------------------------------------------------------------------
verifica_labirinto(Nome) :-
    (   Nome == lab1_piccolo
    ->  format("~nLabirinti (euristica: Manhattan dall'uscita piu' vicina)~n"),
        unload_file('domini/puzzle8/puzzle8')   % il puzzle definisce finale/1 statico
    ;   true ),
    retractall(num_righe(_)), retractall(num_col(_)), retractall(iniziale(_)),
    retractall(finale(_)), retractall(occupata(_)),
    consult('domini/labirinto/labirinto'),
    atom_concat('test/labirinto/', Nome, F),
    load_files(F, [if(true)]),
    findall(U, finale(U), Uscite),
    sorgenti(Uscite, V0),
    bfs(Uscite, 0, V0, Visti),
    num_righe(NR), num_col(NC),
    findall(pos(R,C), (between(1, NR, R), between(1, NC, C), \+ occupata(pos(R,C))), Libere),
    controlla(Visti, Libere, Nome).
