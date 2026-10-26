/* grafo_cut4.pl - dominio minimo per mostrare che il CUT 4 di
   idastar_cut.pl e' ROSSO.

        s --1--> b --3--> g        costo totale 4
        s --2--> a --1--> g        costo totale 3  (ottimo)
        s --5--> c                 vicolo cieco
   Euristica h = 0 (ammissibile). Le azioni di s sono provate
   nell'ordine b, a, c.

   Con il cut:   soglie 0, 1, 2, 3  -> trova s,a,g di costo 3 (ottimo)
   Senza il cut: dopo la prima iterazione la soglia diventa l'ULTIMO f
   tagliato (5, quello di c) invece del minimo (1). Alla soglia 5 la
   visita in profondita' prova b per primo e trova s,b,g di costo 4:
   una soluzione NON ottima.

   Esecuzione:  swipl test/cut/demo_cut4.pl   (dalla cartella attivita1-prolog)
*/
:- dynamic costo/3.
iniziale(s).
finale(g).
arco(s, b, 1).  arco(s, a, 2).  arco(s, c, 5).
arco(b, g, 3).  arco(a, g, 1).
applicabile(vai(Y), X) :- arco(X, Y, _).
trasforma(vai(Y), _, Y).
costo(vai(Y), X, C) :- arco(X, Y, C).
euristica(_, 0).
