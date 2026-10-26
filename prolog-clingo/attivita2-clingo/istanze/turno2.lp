% turno2.lp - secondo turno del torneo di esempio
% Turno 1: anna-bruno (vince anna), carla-dario (vince carla), elena BYE.
% Una vittoria vale 2 punti, come il BYE.
% Dopo il turno entrano filippo, giulia e hugo.
giocatore(anna; bruno; carla; dario; elena; filippo; giulia; hugo).
giocato(anna, bruno).
giocato(carla, dario).
bye_avuto(elena).
punti(anna, 2). punti(carla, 2). punti(elena, 2).
punti(bruno, 0). punti(dario, 0).
