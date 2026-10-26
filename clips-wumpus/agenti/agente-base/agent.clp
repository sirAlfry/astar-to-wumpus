;;; =====================================================================
;;;  AGENTE 1 - "PRUDENTE" (base)
;;;  L'oro del Wumpus - Progetto di IA e Laboratorio 2025/26 (Micalizio)
;;; ---------------------------------------------------------------------
;;;  Strategia in una frase: esplora in profondita' solo le celle che
;;;  sono sicure per una ragione LOCALE (vicine di una cella in cui non
;;;  ha sentito ne' brezza ne' puzza), torna indietro sui propri passi
;;;  quando non sa dove andare, prende l'oro appena lo vede e rientra a
;;;  casa ripercorrendo a ritroso il cammino fatto.
;;;
;;;  Cosa NON sa fare (e' il termine di paragone per gli agenti 2 e 3):
;;;   - non combina informazioni di celle diverse
;;;   - non deduce dove sono pozzi e Wumpus (quindi non li dichiara)
;;;   - non pianifica cammini minimi: torna indietro come Pollicino
;;;
;;;  Ciclo di un passo:  MAIN -> PERCEZIONE -> DECISIONE -> AZIONE
;;;  Convenzioni del simulatore: up = y-1, down = y+1, left = x-1, right = x+1
;;; =====================================================================

;;; =====================================================================
;;;  MAIN
;;; =====================================================================
(defmodule MAIN (export ?ALL))

(deftemplate percept
   (slot x) (slot y) (slot steps)
   (slot breeze) (slot stench) (slot glitter) (slot energy))
(deftemplate counter (slot step))
(deftemplate action (slot move))

(deftemplate pos       (slot x) (slot y))
(deftemplate casa      (slot x) (slot y))
(deftemplate energia   (slot valore))
(deftemplate fase      (slot nome))                 ; esplora | ritorno
(deftemplate turno     (slot n))
(deftemplate visitata  (slot x) (slot y))
(deftemplate sicura    (slot x) (slot y))
(deftemplate muro      (slot x) (slot y))
(deftemplate oro       (slot x) (slot y))
(deftemplate oro-preso)
;; cammino da casa alla posizione attuale, come lista piatta x1 y1 x2 y2 ...
;; (e' la "pila" della visita in profondita': si torna indietro togliendo
;;  l'ultima cella)
(deftemplate pila      (multislot celle))
(deftemplate ultima-mossa (slot dir) (slot tipo) (slot x) (slot y))  ; tipo: avanti | indietro | altro
(deftemplate decisione (slot azione) (slot tipo (default altro)) (slot motivo))
(deftemplate turno-avviato (slot n))

(deffacts MAIN::iniziali
   (counter (step 0))
   (fase (nome esplora))
   (pila))

(deffunction MAIN::adiacenti (?x1 ?y1 ?x2 ?y2)
   (= (+ (abs (- ?x1 ?x2)) (abs (- ?y1 ?y2))) 1))

(deffunction MAIN::direzione (?x1 ?y1 ?x2 ?y2)
   (if (> ?x2 ?x1) then (return right))
   (if (< ?x2 ?x1) then (return left))
   (if (> ?y2 ?y1) then (return down))
   (return up))

(deffunction MAIN::dx (?d) (if (eq ?d right) then 1 else (if (eq ?d left) then -1 else 0)))
(deffunction MAIN::dy (?d) (if (eq ?d down)  then 1 else (if (eq ?d up)   then -1 else 0)))

(defrule MAIN::avvia-passo
   (counter (step ?s))
   (not (turno-avviato (n ?s)))
   =>
   (assert (turno-avviato (n ?s)))
   (assert (turno (n ?s)))
   (focus PERCEZIONE DECISIONE AZIONE))

;;; =====================================================================
;;;  PERCEZIONE
;;; =====================================================================
(defmodule PERCEZIONE (import MAIN ?ALL))

(defrule PERCEZIONE::pulisci-turno
   (declare (salience 30))
   (turno (n ?s))
   ?t <- (turno (n ?v&:(< ?v ?s)))
   =>
   (retract ?t))

(defrule PERCEZIONE::pulisci-percept-vecchi
   (declare (salience 30))
   (counter (step ?s))
   ?p <- (percept (steps ?v&:(< ?v ?s)))
   =>
   (retract ?p))

(defrule PERCEZIONE::ricorda-casa
   (declare (salience 25))
   (not (casa))
   (percept (x ?x) (y ?y))
   =>
   (assert (casa (x ?x) (y ?y))))

;; urto contro un muro: posizione invariata dopo un movimento
(defrule PERCEZIONE::urto
   (declare (salience 20))
   (counter (step ?s))
   (percept (steps ?s) (x ?x) (y ?y))
   ?u <- (ultima-mossa (dir ?d&up|down|left|right) (x ?x) (y ?y))
   =>
   (retract ?u)
   (assert (muro (x (+ ?x (dx ?d))) (y (+ ?y (dy ?d))))))

;; mi sono spostato in avanti: la cella da cui vengo va in cima alla pila
(defrule PERCEZIONE::avanti
   (declare (salience 20))
   ?u <- (ultima-mossa (tipo avanti) (x ?ux) (y ?uy))
   (counter (step ?s))
   (percept (steps ?s) (x ?x) (y ?y&:(or (<> ?x ?ux) (<> ?y ?uy))))
   ?p <- (pila (celle $?c))
   =>
   (retract ?u)
   (modify ?p (celle $?c ?ux ?uy)))

;; sono tornato indietro: tolgo l'ultima cella dalla pila
(defrule PERCEZIONE::indietro
   (declare (salience 20))
   ?u <- (ultima-mossa (tipo indietro) (x ?ux) (y ?uy))
   (counter (step ?s))
   (percept (steps ?s) (x ?x) (y ?y&:(or (<> ?x ?ux) (<> ?y ?uy))))
   ?p <- (pila (celle $?c ?px ?py))
   =>
   (retract ?u)
   (modify ?p (celle $?c)))

(defrule PERCEZIONE::mossa-consumata
   (declare (salience 10))
   ?u <- (ultima-mossa)
   =>
   (retract ?u))

(defrule PERCEZIONE::aggiorna-stato
   (declare (salience 15))
   (counter (step ?s))
   (percept (steps ?s) (x ?x) (y ?y) (breeze ?b) (stench ?st) (glitter ?g) (energy ?e))
   =>
   (do-for-all-facts ((?p pos)) TRUE (retract ?p))
   (do-for-all-facts ((?en energia)) TRUE (retract ?en))
   (assert (pos (x ?x) (y ?y)))
   (assert (energia (valore ?e)))
   (assert (visitata (x ?x) (y ?y)))
   (assert (sicura (x ?x) (y ?y)))
   (if (eq ?g TRUE) then (assert (oro (x ?x) (y ?y))))
   ;; UNICA regola di sicurezza dell'agente base: se qui non sento ne'
   ;; brezza ne' puzza, le quattro celle vicine sono sicure
   (if (and (eq ?b FALSE) (eq ?st FALSE)) then
      (assert (sicura (x (+ ?x 1)) (y ?y)))
      (assert (sicura (x ?x) (y (+ ?y 1))))
      (if (> ?x 0) then (assert (sicura (x (- ?x 1)) (y ?y))))
      (if (> ?y 0) then (assert (sicura (x ?x) (y (- ?y 1)))))))

;;; =====================================================================
;;;  DECISIONE
;;; =====================================================================
(defmodule DECISIONE (import MAIN ?ALL))

(defrule DECISIONE::primo-passo
   (turno (n ?s))
   (not (pos))
   (not (decisione))
   =>
   (assert (decisione (azione grab) (motivo "nessuna percezione ancora"))))

;; energia: la pila e' lunga quanto il cammino di ritorno (2 numeri per cella)
(defrule DECISIONE::energia-agli-sgoccioli
   (declare (salience 200))
   ?f <- (fase (nome esplora))
   (energia (valore ?e))
   (pila (celle $?c&:(<= ?e (+ (div (length$ $?c) 2) 2))))
   =>
   (modify ?f (nome ritorno)))

(defrule DECISIONE::oro-in-tasca
   (declare (salience 190))
   ?f <- (fase (nome esplora))
   (oro-preso)
   =>
   (modify ?f (nome ritorno)))

(defrule DECISIONE::prendi-oro
   (declare (salience 100))
   (turno (n ?s))
   (pos (x ?x) (y ?y))
   (oro (x ?x) (y ?y))
   (not (oro-preso))
   (not (decisione))
   =>
   (assert (decisione (azione grab) (motivo "scintillio"))))

(defrule DECISIONE::esci
   (declare (salience 90))
   (turno (n ?s))
   (pos (x ?x) (y ?y))
   (casa (x ?x) (y ?y))
   (pila (celle))
   (or (fase (nome ritorno))
       (not (and (sicura (x ?nx) (y ?ny&:(adiacenti ?x ?y ?nx ?ny)))
                 (not (visitata (x ?nx) (y ?ny)))
                 (not (muro (x ?nx) (y ?ny))))))
   (not (decisione))
   =>
   (assert (decisione (azione quit) (motivo "a casa, niente altro da fare"))))

;; esplorazione in profondita': una vicina sicura mai visitata
(defrule DECISIONE::avanti
   (declare (salience 60))
   (turno (n ?s))
   (fase (nome esplora))
   (pos (x ?x) (y ?y))
   (sicura (x ?nx) (y ?ny&:(adiacenti ?x ?y ?nx ?ny)))
   (not (visitata (x ?nx) (y ?ny)))
   (not (muro (x ?nx) (y ?ny)))
   (not (decisione))
   =>
   (assert (decisione (azione (direzione ?x ?y ?nx ?ny)) (tipo avanti) (motivo "esplorazione"))))

;; nessuna vicina nuova (o fase di ritorno): un passo indietro sulla pila
(defrule DECISIONE::indietro
   (declare (salience 50))
   (turno (n ?s))
   (pos (x ?x) (y ?y))
   (pila (celle $? ?px ?py))
   (not (decisione))
   =>
   (assert (decisione (azione (direzione ?x ?y ?px ?py)) (tipo indietro) (motivo "torno indietro"))))

(defrule DECISIONE::paracadute
   (declare (salience -100))
   (turno (n ?s))
   (not (decisione))
   =>
   (assert (decisione (azione grab) (motivo "nessuna regola applicabile"))))

;;; =====================================================================
;;;  AZIONE
;;; =====================================================================
(defmodule AZIONE (import MAIN ?ALL))

(defrule AZIONE::esegui
   ?d <- (decisione (azione ?a) (tipo ?t) (motivo ?m))
   (turno (n ?s))
   =>
   (retract ?d)
   (assert (action (move ?a)))
   (printout t "passo " ?s ": " ?a "   (" ?m ")" crlf)
   (do-for-fact ((?p pos)) TRUE
      (assert (ultima-mossa (dir ?a) (tipo ?t) (x ?p:x) (y ?p:y)))
      (if (and (eq ?a grab) (any-factp ((?o oro)) (and (= ?o:x ?p:x) (= ?o:y ?p:y)))) then
         (assert (oro-preso)))))
