% lab3_trappola.pl
% 15x15: l'uscita (2,13) e' la piu' vicina in linea d'aria ma e' recintata;
% l'unica raggiungibile e' (15,1). L'euristica (min Manhattan) attira la ricerca nel vicolo cieco.

num_righe(15).
num_col(15).
iniziale(pos(7,7)).
finale(pos(2,13)).
finale(pos(15,1)).

occupata(pos(1,8)).
occupata(pos(2,8)).
occupata(pos(3,8)).
occupata(pos(4,8)).
occupata(pos(5,8)).
occupata(pos(5,9)).
occupata(pos(5,10)).
occupata(pos(5,11)).
occupata(pos(5,12)).
occupata(pos(5,13)).
occupata(pos(5,14)).
occupata(pos(5,15)).
occupata(pos(10,1)).
occupata(pos(10,2)).
occupata(pos(10,3)).
occupata(pos(10,4)).
occupata(pos(10,5)).
occupata(pos(10,6)).
occupata(pos(10,7)).
occupata(pos(10,8)).
occupata(pos(10,9)).
occupata(pos(10,10)).
occupata(pos(10,11)).
occupata(pos(10,12)).
