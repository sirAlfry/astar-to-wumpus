% lab4_senza_uscita.pl
% 8x8 diviso in due da un muro: entrambe le uscite sono dall'altra parte.
% A* deve dimostrare che non c'e' soluzione; IDA* esplora tutti i cammini semplici.

num_righe(8).
num_col(8).
iniziale(pos(2,2)).
finale(pos(8,1)).
finale(pos(8,8)).

occupata(pos(4,1)).
occupata(pos(4,2)).
occupata(pos(4,3)).
occupata(pos(4,4)).
occupata(pos(4,5)).
occupata(pos(4,6)).
occupata(pos(4,7)).
occupata(pos(4,8)).
