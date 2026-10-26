/* =====================================================================
   labirinto.pl  -  Dominio "labirinto con piu' uscite"
   ---------------------------------------------------------------------
   Regole del dominio (azioni ed euristica). L'istanza (dimensioni,
   celle occupate, partenza e uscite) sta in un file separato in
   test/labirinto/, che definisce:
     num_righe(N).  num_col(M).
     iniziale(pos(R,C)).
     finale(pos(R,C)).        uno o piu' fatti: le uscite
     occupata(pos(R,C)).      i muri
   Le righe crescono verso il basso (nord = riga - 1).
   ===================================================================== */

:- dynamic num_righe/1, num_col/1, iniziale/1, finale/1, occupata/1.

% applicabile(?Az, +S): ci si puo' muovere in una cella libera della griglia
applicabile(nord, pos(R,C)) :-
    R > 1, R1 is R - 1, \+ occupata(pos(R1,C)).
applicabile(sud, pos(R,C)) :-
    num_righe(N), R < N, R1 is R + 1, \+ occupata(pos(R1,C)).
applicabile(est, pos(R,C)) :-
    num_col(M), C < M, C1 is C + 1, \+ occupata(pos(R,C1)).
applicabile(ovest, pos(R,C)) :-
    C > 1, C1 is C - 1, \+ occupata(pos(R,C1)).

% trasforma(+Az, +S, -S1)
trasforma(nord,  pos(R,C), pos(R1,C)) :- R1 is R - 1.
trasforma(sud,   pos(R,C), pos(R1,C)) :- R1 is R + 1.
trasforma(est,   pos(R,C), pos(R,C1)) :- C1 is C + 1.
trasforma(ovest, pos(R,C), pos(R,C1)) :- C1 is C - 1.

/* euristica(+S, -H): distanza di Manhattan dalla USCITA PIU' VICINA.
   - Ammissibile: con 4 mosse di costo 1 nessun cammino verso un'uscita
     e' piu' corto della sua distanza di Manhattan, e il minimo tra le
     uscite non sovrastima il costo verso l'uscita effettivamente
     raggiunta.
   - Consistente: spostandosi di una cella la distanza da ciascuna
     uscita cambia al massimo di 1, quindi anche il minimo cambia al
     massimo di 1 = costo della mossa.
   - Limite: se l'uscita piu' vicina "in linea d'aria" e' irraggiungibile
     (murata), l'euristica attira la ricerca verso di lei; resta
     ammissibile ma diventa poco informativa (vedi test labirinto3).  */
euristica(pos(R,C), H) :-
    findall(D, ( finale(pos(RF,CF)), D is abs(R-RF) + abs(C-CF) ), Ds),
    (   Ds == [] -> H = 0 ; min_list(Ds, H) ).
