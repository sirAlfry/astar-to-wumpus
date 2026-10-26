/* =====================================================================
   puzzle8.pl  -  Dominio "puzzle dell'8"
   ---------------------------------------------------------------------
   Stato: lista di 9 elementi letta per righe, v = casella vuota.
       [1,2,3,          1 2 3
        4,5,6,    =     4 5 6
        7,8,v]          7 8 _      <- configurazione obiettivo
   Azioni: si muove la casella VUOTA (su, giu, sinistra, destra);
   equivale a far scorrere nella direzione opposta la tessera vicina.
   L'istanza (file in test/puzzle8) definisce solo iniziale/1.

   Euristica selezionabile con il fatto euristica_puzzle/1:
     manhattan     somma delle distanze di Manhattan delle tessere
     fuori_posto   numero di tessere non al loro posto
     zero          h = 0 (A* degenera in ricerca a costo uniforme)
   Default: manhattan.  Esempio:  ?- imposta_euristica(fuori_posto).
   ===================================================================== */

:- dynamic iniziale/1, euristica_puzzle/1.
euristica_puzzle(manhattan).

imposta_euristica(E) :-
    retractall(euristica_puzzle(_)), assertz(euristica_puzzle(E)).

finale([1,2,3,4,5,6,7,8,v]).

% Posizione obiettivo di ogni tessera: indice 0..8 nella lista
pos_obiettivo(1,0). pos_obiettivo(2,1). pos_obiettivo(3,2).
pos_obiettivo(4,3). pos_obiettivo(5,4). pos_obiettivo(6,5).
pos_obiettivo(7,6). pos_obiettivo(8,7).

% applicabile(?Az, +S): dipende solo da dove si trova la casella vuota
applicabile(Az, S) :-
    nth0(I, S, v), !,
    mossa_possibile(Az, I).

mossa_possibile(su,       I) :- I >= 3.          % non in prima riga
mossa_possibile(giu,      I) :- I =< 5.          % non in ultima riga
mossa_possibile(sinistra, I) :- I mod 3 =\= 0.   % non in prima colonna
mossa_possibile(destra,   I) :- I mod 3 =\= 2.   % non in ultima colonna

spostamento(su, -3). spostamento(giu, 3).
spostamento(sinistra, -1). spostamento(destra, 1).

% trasforma(+Az, +S, -S1): scambia la vuota con la tessera adiacente
trasforma(Az, S, S1) :-
    nth0(I, S, v), !,
    spostamento(Az, D),
    J is I + D,
    nth0(J, S, Tessera),
    scambia(S, I, J, Tessera, S1).

% scambia(+Lista, +I, +J, +Tessera, -Nuova): in I va Tessera, in J va v
scambia(S, I, J, Tessera, S1) :-
    scambia_(S, 0, I, J, Tessera, S1).
scambia_([], _, _, _, _, []).
scambia_([X|Xs], K, I, J, T, [Y|Ys]) :-
    (   K =:= I -> Y = T
    ;   K =:= J -> Y = v
    ;   Y = X ),
    K1 is K + 1,
    scambia_(Xs, K1, I, J, T, Ys).

% ---------------------------------------------------------------------
% Euristiche (entrambe ammissibili e consistenti)
% ---------------------------------------------------------------------
euristica(S, H) :-
    euristica_puzzle(E), !,
    h(E, S, H).

h(zero, _, 0).
h(fuori_posto, S, H) :-          % ogni tessera fuori posto richiede >= 1 mossa
    fuori_posto(S, 0, 0, H).
h(manhattan, S, H) :-            % ogni tessera richiede >= distanza mosse
    manhattan(S, 0, 0, H).

fuori_posto([], _, H, H).
fuori_posto([T|Ts], K, Acc, H) :-
    (   T \== v, \+ pos_obiettivo(T, K) -> Acc1 is Acc + 1 ; Acc1 = Acc ),
    K1 is K + 1,
    fuori_posto(Ts, K1, Acc1, H).

manhattan([], _, H, H).
manhattan([T|Ts], K, Acc, H) :-
    (   T == v
    ->  Acc1 = Acc
    ;   pos_obiettivo(T, G),
        D is abs(K // 3 - G // 3) + abs(K mod 3 - G mod 3),
        Acc1 is Acc + D
    ),
    K1 is K + 1,
    manhattan(Ts, K1, Acc1, H).

% ---------------------------------------------------------------------
% Risolvibilita': un'istanza e' risolvibile se e solo se il numero di
% inversioni (coppie di tessere in ordine sbagliato, vuota esclusa) e'
% pari. Ogni mossa cambia le inversioni di 0 o 2, quindi la parita' e'
% un invariante. Meta' delle 9!/... configurazioni e' irrisolvibile.
% ---------------------------------------------------------------------
risolvibile(S) :-
    exclude(==(v), S, Tessere),
    inversioni(Tessere, 0, N),
    N mod 2 =:= 0.

inversioni([], N, N).
inversioni([X|Xs], Acc, N) :-
    include([Y]>>(Y < X), Xs, Minori),
    length(Minori, K),
    Acc1 is Acc + K,
    inversioni(Xs, Acc1, N).

% Stampa leggibile di uno stato
stampa([]).
stampa([A,B,C|R]) :-
    format("  ~w ~w ~w~n", [A,B,C]),
    stampa(R).
