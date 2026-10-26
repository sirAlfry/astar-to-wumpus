;;; =====================================================================
;;;  AGENTE 3 - "STRATEGA" (logica + certainty factors)
;;;  L'oro del Wumpus - Progetto di IA e Laboratorio 2025/26 (Micalizio)
;;; ---------------------------------------------------------------------
;;;  Strategia in una frase: tutto quello che sa fare l'agente 2, piu'
;;;  un modulo CERTEZZA che stima con i certainty factors (CF) quanto e'
;;;  probabile un pozzo o il Wumpus nelle celle incerte, e una strategia
;;;  che sfrutta come e' fatto il punteggio.
;;;
;;;  Cosa aggiunge rispetto all'agente 2:
;;;   1. CF per pozzi e Wumpus (combinazione MYCIN: cf = a + b(1-a)).
;;;      Una brezza con k candidati da' 1/k di evidenza a ciascuno; una
;;;      brezza gia' "spiegata" da un pozzo certo da' solo un piccolo CF
;;;      a priori (potrebbe esserci un secondo pozzo, ma e' improbabile).
;;;   2. Dichiara anche pozzi non certi ma con CF >= soglia-dichiarazione.
;;;   3. L'oro NON si prende subito: con end_on_grab il gioco finisce al
;;;      grab, quindi prima conviene finire l'esplorazione sicura e
;;;      dichiarare i pozzi (+25 ciascuno), tenendo sempre l'energia per
;;;      tornare all'oro (ed eventualmente da li' a casa).
;;;   4. Va apposta nelle celle adiacenti ai pozzi da dichiarare.
;;;   5. Rischio calcolato: se non ha trovato l'oro e non ci sono piu'
;;;      celle sicure, entra nella cella incerta meno pericolosa, ma solo
;;;      se il suo pericolo stimato e' <= soglia-rischio.
;;;  Le due soglie sono parametri (fatti "parametro" in MAIN), scelti con
;;;  gli esperimenti su mappe casuali (vedi risultati/).
;;;
;;;  Ciclo di un passo:
;;;   MAIN -> PERCEZIONE -> INFERENZA -> CERTEZZA -> DISTANZE -> DECISIONE -> AZIONE
;;; =====================================================================

;;; =====================================================================
;;;  MAIN: template condivisi, funzioni di servizio, avvio del passo
;;; =====================================================================
(defmodule MAIN (export ?ALL))

;; --- interfaccia con il simulatore (non modificare i nomi) -----------
(deftemplate percept
   (slot x) (slot y) (slot steps)
   (slot breeze) (slot stench) (slot glitter) (slot energy))
(deftemplate counter (slot step))
(deftemplate action (slot move))

;; --- conoscenza dell'agente ------------------------------------------
(deftemplate pos        (slot x) (slot y))            ; posizione attuale (unico fatto)
(deftemplate casa       (slot x) (slot y))            ; cella di partenza = uscita
(deftemplate energia    (slot valore))                ; energia residua (unico fatto)
(deftemplate fase       (slot nome))                  ; esplora | ritorno (unico fatto)
(deftemplate turno      (slot n))                     ; passo corrente, rinnova le attivazioni
(deftemplate visitata   (slot x) (slot y))
(deftemplate oss        (slot x) (slot y) (slot breeze) (slot stench))  ; cosa ho sentito in (x,y)
(deftemplate cella      (slot x) (slot y))            ; cella che so esistere come vicina di una visitata
(deftemplate muro       (slot x) (slot y))            ; muro o fuori dalla mappa (scoperto urtando)
(deftemplate no-pozzo   (slot x) (slot y))
(deftemplate no-wumpus  (slot x) (slot y))
(deftemplate sicura     (slot x) (slot y))            ; ne' pozzo ne' Wumpus (dimostrato)
(deftemplate pozzo      (slot x) (slot y))            ; pozzo certo
(deftemplate wumpus     (slot x) (slot y))            ; Wumpus certo
(deftemplate cand       (slot tipo) (slot bx) (slot by) (slot x) (slot y))
   ;; (cand pozzo bx by x y): la brezza sentita in (bx,by) PUO' venire da (x,y)
(deftemplate dichiarato (slot x) (slot y))            ; pozzo gia' dichiarato al simulatore
(deftemplate oro        (slot x) (slot y))            ; dove ho visto lo scintillio
(deftemplate oro-preso)
(deftemplate ultima-mossa (slot dir) (slot x) (slot y)) ; per riconoscere gli urti
(deftemplate dist       (slot tipo) (slot x) (slot y) (slot d))  ; campi di distanza (BFS)
(deftemplate decisione  (slot azione) (slot motivo))  ; output di DECISIONE (al piu' uno)
(deftemplate ricalcola)                               ; gettone: rifare i campi di distanza
(deftemplate ricalcola-cf)                            ; gettone: rifare i certainty factors
(deftemplate cf         (slot tipo) (slot x) (slot y) (slot valore))   ; CF di pozzo/wumpus in (x,y)
(deftemplate contributo (slot tipo) (slot bx) (slot by) (slot x) (slot y))  ; evidenza gia' contata
(deftemplate bersaglio-rischio (slot x) (slot y) (slot pericolo))       ; cella incerta migliore
(deftemplate parametro  (slot nome) (slot valore))
(deftemplate riserva    (slot valore))                ; energia da tenere da parte (calcolata in DISTANZE)

(deffacts MAIN::iniziali
   (counter (step 0))
   (fase (nome esplora))                      ; esplora | prendi-oro | ritorno
   ;; parametri della strategia
   (parametro (nome soglia-dichiarazione) (valore 0.75))  ; dichiaro un pozzo se CF >= 0.75
   (parametro (nome soglia-rischio) (valore 0.3))         ; rischio una cella se pericolo <= 0.3
   (parametro (nome cf-a-priori) (valore 0.2)))           ; evidenza di una brezza gia' spiegata

;; --- funzioni di servizio --------------------------------------------
(deffunction MAIN::adiacenti (?x1 ?y1 ?x2 ?y2)
   (= (+ (abs (- ?x1 ?x2)) (abs (- ?y1 ?y2))) 1))

;; direzione di movimento da (x1,y1) alla cella adiacente (x2,y2)
(deffunction MAIN::direzione (?x1 ?y1 ?x2 ?y2)
   (if (> ?x2 ?x1) then (return right))
   (if (< ?x2 ?x1) then (return left))
   (if (> ?y2 ?y1) then (return down))
   (return up))

;; azione per dichiarare un pozzo nella cella adiacente (x2,y2)
(deffunction MAIN::dichiarazione (?x1 ?y1 ?x2 ?y2)
   (if (> ?x2 ?x1) then (return pit-east))
   (if (< ?x2 ?x1) then (return pit-west))
   (if (> ?y2 ?y1) then (return pit-south))
   (return pit-north))

;; combinazione di due evidenze positive (MYCIN)
(deffunction MAIN::combina (?a ?b) (+ ?a (* ?b (- 1 ?a))))

(deffunction MAIN::param (?nome)
   (do-for-fact ((?p parametro)) (eq ?p:nome ?nome) (return ?p:valore))
   (return 0))

;; cella raggiunta muovendosi in direzione ?d da (x,y)
(deffunction MAIN::dx (?d) (if (eq ?d right) then 1 else (if (eq ?d left) then -1 else 0)))
(deffunction MAIN::dy (?d) (if (eq ?d down)  then 1 else (if (eq ?d up)   then -1 else 0)))

;; --- avvio del passo -------------------------------------------------
;; Il simulatore modifica counter a ogni passo: e' un fatto nuovo, quindi
;; la regola si riattiva (la rifrazione vale solo per gli stessi fatti).
;; Il fatto turno-avviato impedisce di avviare due volte lo stesso passo.
(deftemplate turno-avviato (slot n))
(defrule MAIN::avvia-passo
   (counter (step ?s))
   (not (turno-avviato (n ?s)))
   =>
   (assert (turno-avviato (n ?s)))
   (assert (turno (n ?s)))
   (assert (ricalcola))
   (assert (ricalcola-cf))
   (focus PERCEZIONE INFERENZA CERTEZZA DISTANZE DECISIONE AZIONE))

;;; =====================================================================
;;;  PERCEZIONE: aggiorna la conoscenza a partire dall'ultimo percept
;;; =====================================================================
(defmodule PERCEZIONE (import MAIN ?ALL))

;; i turni vecchi non servono piu'
(defrule PERCEZIONE::pulisci-turno
   (declare (salience 30))
   (turno (n ?s))
   ?t <- (turno (n ?v&:(< ?v ?s)))
   =>
   (retract ?t))

;; il simulatore lascia in memoria i percept vecchi: li buttiamo
(defrule PERCEZIONE::pulisci-percept-vecchi
   (declare (salience 30))
   (counter (step ?s))
   ?p <- (percept (steps ?v&:(< ?v ?s)))
   =>
   (retract ?p))

;; urto: avevo chiesto un movimento ma sono rimasto dove ero -> muro
(defrule PERCEZIONE::urto
   (declare (salience 20))
   (counter (step ?s))
   (percept (steps ?s) (x ?x) (y ?y))
   ?u <- (ultima-mossa (dir ?d&up|down|left|right) (x ?x) (y ?y))
   =>
   (retract ?u)
   (bind ?mx (+ ?x (dx ?d)))
   (bind ?my (+ ?y (dy ?d)))
   (assert (muro (x ?mx) (y ?my)))
   (printout t "  [percezione] urto: muro in (" ?mx "," ?my ")" crlf))

(defrule PERCEZIONE::mossa-consumata
   (declare (salience 10))
   ?u <- (ultima-mossa)
   =>
   (retract ?u))

;; primo percept: la cella di partenza e' casa
(defrule PERCEZIONE::ricorda-casa
   (declare (salience 25))
   (not (casa))
   (percept (x ?x) (y ?y))
   =>
   (assert (casa (x ?x) (y ?y))))

(defrule PERCEZIONE::aggiorna-stato
   (declare (salience 15))
   (counter (step ?s))
   (percept (steps ?s) (x ?x) (y ?y) (breeze ?b) (stench ?st) (glitter ?g) (energy ?e))
   =>
   (do-for-all-facts ((?p pos)) TRUE (retract ?p))
   (do-for-all-facts ((?en energia)) TRUE (retract ?en))
   (assert (pos (x ?x) (y ?y)))
   (assert (energia (valore ?e)))
   ;; sono vivo in (x,y): la cella non e' ne' pozzo ne' Wumpus
   (assert (visitata (x ?x) (y ?y)))
   (assert (oss (x ?x) (y ?y) (breeze ?b) (stench ?st)))
   (assert (no-pozzo (x ?x) (y ?y)))
   (assert (no-wumpus (x ?x) (y ?y)))
   (if (eq ?g TRUE) then (assert (oro (x ?x) (y ?y)))))

;;; =====================================================================
;;;  INFERENZA: deduzioni logiche sulla mappa
;;;  Le saliance ordinano le fasi: prima si generano celle e candidati,
;;;  poi si eliminano i candidati esclusi, infine si traggono conclusioni.
;;; =====================================================================
(defmodule INFERENZA (import MAIN ?ALL))

;; le 4 vicine di una cella visitata esistono "come ipotesi"
;; (coordinate negative = fuori mappa, non le generiamo)
(defrule INFERENZA::genera-vicine
   (declare (salience 50))
   (visitata (x ?x) (y ?y))
   =>
   (assert (cella (x (+ ?x 1)) (y ?y)))
   (assert (cella (x ?x) (y (+ ?y 1))))
   (if (> ?x 0) then (assert (cella (x (- ?x 1)) (y ?y))))
   (if (> ?y 0) then (assert (cella (x ?x) (y (- ?y 1))))))

;; niente brezza in (x,y) => nessuna vicina e' un pozzo
(defrule INFERENZA::niente-brezza
   (declare (salience 40))
   (oss (x ?x) (y ?y) (breeze FALSE))
   (cella (x ?cx) (y ?cy&:(adiacenti ?x ?y ?cx ?cy)))
   =>
   (assert (no-pozzo (x ?cx) (y ?cy))))

;; niente puzza in (x,y) => nessuna vicina e' il Wumpus
(defrule INFERENZA::niente-puzza
   (declare (salience 40))
   (oss (x ?x) (y ?y) (stench FALSE))
   (cella (x ?cx) (y ?cy&:(adiacenti ?x ?y ?cx ?cy)))
   =>
   (assert (no-wumpus (x ?cx) (y ?cy))))

;; i muri non sono ne' pozzi ne' Wumpus (nel simulatore non si sovrappongono)
(defrule INFERENZA::muro-innocuo
   (declare (salience 40))
   (muro (x ?x) (y ?y))
   =>
   (assert (no-pozzo (x ?x) (y ?y)))
   (assert (no-wumpus (x ?x) (y ?y))))

;; un pozzo non puo' essere il Wumpus e viceversa
(defrule INFERENZA::pozzo-non-wumpus
   (declare (salience 40))
   (pozzo (x ?x) (y ?y))
   =>
   (assert (no-wumpus (x ?x) (y ?y))))
(defrule INFERENZA::wumpus-non-pozzo
   (declare (salience 40))
   (wumpus (x ?x) (y ?y))
   =>
   (assert (no-pozzo (x ?x) (y ?y))))

;; c'e' un solo Wumpus: trovato lui, tutte le altre celle ne sono libere
(defrule INFERENZA::wumpus-unico
   (declare (salience 40))
   (wumpus (x ?wx) (y ?wy))
   (cella (x ?x) (y ?y&:(or (<> ?x ?wx) (<> ?y ?wy))))
   =>
   (assert (no-wumpus (x ?x) (y ?y))))

;; ... e deve essere adiacente a TUTTE le celle in cui ho sentito puzza
(defrule INFERENZA::wumpus-vicino-a-ogni-puzza
   (declare (salience 40))
   (oss (x ?px) (y ?py) (stench TRUE))
   (cella (x ?x) (y ?y&:(not (adiacenti ?px ?py ?x ?y))))
   (oss (x ?qx) (y ?qy&:(adiacenti ?qx ?qy ?x ?y)) (stench TRUE))  ; e' candidata altrove
   =>
   (assert (no-wumpus (x ?x) (y ?y))))

;; --- candidati -------------------------------------------------------
(defrule INFERENZA::candidato-pozzo
   (declare (salience 30))
   (oss (x ?bx) (y ?by) (breeze TRUE))
   (cella (x ?x) (y ?y&:(adiacenti ?bx ?by ?x ?y)))
   (not (no-pozzo (x ?x) (y ?y)))
   =>
   (assert (cand (tipo pozzo) (bx ?bx) (by ?by) (x ?x) (y ?y))))

(defrule INFERENZA::candidato-wumpus
   (declare (salience 30))
   (oss (x ?bx) (y ?by) (stench TRUE))
   (cella (x ?x) (y ?y&:(adiacenti ?bx ?by ?x ?y)))
   (not (no-wumpus (x ?x) (y ?y)))
   =>
   (assert (cand (tipo wumpus) (bx ?bx) (by ?by) (x ?x) (y ?y))))

(defrule INFERENZA::scarta-candidato-pozzo
   (declare (salience 35))
   ?c <- (cand (tipo pozzo) (x ?x) (y ?y))
   (no-pozzo (x ?x) (y ?y))
   =>
   (retract ?c))

(defrule INFERENZA::scarta-candidato-wumpus
   (declare (salience 35))
   ?c <- (cand (tipo wumpus) (x ?x) (y ?y))
   (no-wumpus (x ?x) (y ?y))
   =>
   (retract ?c))

;; --- conclusioni (salience bassa: candidati gia' aggiornati) -----------
;; eliminazione: la brezza di (bx,by) ha un solo candidato rimasto
(defrule INFERENZA::pozzo-per-eliminazione
   (declare (salience 10))
   (cand (tipo pozzo) (bx ?bx) (by ?by) (x ?x) (y ?y))
   (not (cand (tipo pozzo) (bx ?bx) (by ?by) (x ?x2&~?x)))
   (not (cand (tipo pozzo) (bx ?bx) (by ?by) (y ?y2&~?y)))
   (not (pozzo (x ?x) (y ?y)))
   =>
   (assert (pozzo (x ?x) (y ?y)))
   (printout t "  [inferenza] pozzo certo in (" ?x "," ?y ")" crlf))

(defrule INFERENZA::wumpus-per-eliminazione
   (declare (salience 10))
   (cand (tipo wumpus) (bx ?bx) (by ?by) (x ?x) (y ?y))
   (not (cand (tipo wumpus) (bx ?bx) (by ?by) (x ?x2&~?x)))
   (not (cand (tipo wumpus) (bx ?bx) (by ?by) (y ?y2&~?y)))
   (not (wumpus))
   =>
   (assert (wumpus (x ?x) (y ?y)))
   (printout t "  [inferenza] Wumpus in (" ?x "," ?y ")" crlf))

;; sicura = dimostrato che non c'e' ne' pozzo ne' Wumpus
(defrule INFERENZA::cella-sicura
   (declare (salience 20))
   (no-pozzo (x ?x) (y ?y))
   (no-wumpus (x ?x) (y ?y))
   (not (muro (x ?x) (y ?y)))
   =>
   (assert (sicura (x ?x) (y ?y))))

(defrule INFERENZA::muro-non-sicuro
   (declare (salience 45))
   (muro (x ?x) (y ?y))
   ?s <- (sicura (x ?x) (y ?y))
   =>
   (retract ?s))

;;; =====================================================================
;;;  CERTEZZA: certainty factors per le celle incerte
;;;   (cf pozzo x y v)  quanto credo che in (x,y) ci sia un pozzo (0..1)
;;;   (cf wumpus x y v) idem per il Wumpus
;;;  Si ricalcolano da zero a ogni passo, perche' i candidati cambiano.
;;;  Ogni candidato (cand t bx by x y) porta un'evidenza e:
;;;     e = 1/k  se la percezione in (bx,by) ha k candidati e non e' gia'
;;;              spiegata da un pozzo certo;
;;;     e = cf-a-priori  se e' gia' spiegata (potrebbe esserci un secondo
;;;              pozzo vicino, ma e' poco probabile).
;;;  Le evidenze di celle diverse si combinano con la regola MYCIN; un
;;;  pozzo/Wumpus certo ha CF 1, una cella esclusa non ha CF (= 0).
;;; =====================================================================
(defmodule CERTEZZA (import MAIN ?ALL))

(defrule CERTEZZA::azzera
   (declare (salience 100))
   (ricalcola-cf)
   (or ?f <- (cf) ?f <- (contributo) ?f <- (bersaglio-rischio))
   =>
   (retract ?f))

(defrule CERTEZZA::fine-azzeramento
   (declare (salience 90))
   ?r <- (ricalcola-cf)
   =>
   (retract ?r))

(defrule CERTEZZA::certo-pozzo
   (declare (salience 50))
   (turno (n ?s))
   (pozzo (x ?x) (y ?y))
   (not (cf (tipo pozzo) (x ?x) (y ?y)))
   =>
   (assert (cf (tipo pozzo) (x ?x) (y ?y) (valore 1.0))))

(defrule CERTEZZA::certo-wumpus
   (declare (salience 50))
   (turno (n ?s))
   (wumpus (x ?x) (y ?y))
   (not (cf (tipo wumpus) (x ?x) (y ?y)))
   =>
   (assert (cf (tipo wumpus) (x ?x) (y ?y) (valore 1.0))))

(defrule CERTEZZA::evidenza
   (declare (salience 40))
   (turno (n ?s))
   (cand (tipo ?t) (bx ?bx) (by ?by) (x ?x) (y ?y))
   (not (contributo (tipo ?t) (bx ?bx) (by ?by) (x ?x) (y ?y)))
   (not (pozzo (x ?x) (y ?y)))
   (not (wumpus (x ?x) (y ?y)))
   =>
   (assert (contributo (tipo ?t) (bx ?bx) (by ?by) (x ?x) (y ?y)))
   (bind ?k (length$ (find-all-facts ((?c cand))
              (and (eq ?c:tipo ?t) (= ?c:bx ?bx) (= ?c:by ?by)))))
   ;; la percezione in (bx,by) e' gia' spiegata da un pozzo certo vicino?
   (bind ?spiegata (and (eq ?t pozzo)
                        (any-factp ((?p pozzo)) (adiacenti ?bx ?by ?p:x ?p:y))))
   (bind ?e (if ?spiegata then (param cf-a-priori) else (/ 1.0 ?k)))
   (bind ?trovato FALSE)
   (do-for-fact ((?f cf)) (and (eq ?f:tipo ?t) (= ?f:x ?x) (= ?f:y ?y))
      (modify ?f (valore (combina ?f:valore ?e)))
      (bind ?trovato TRUE))
   (if (not ?trovato) then
      (assert (cf (tipo ?t) (x ?x) (y ?y) (valore ?e)))))

;; pericolo di una cella = probabilita' (stimata) di morirci entrando
(deffunction CERTEZZA::pericolo (?x ?y)
   (bind ?p 0) (bind ?w 0)
   (do-for-fact ((?f cf)) (and (eq ?f:tipo pozzo) (= ?f:x ?x) (= ?f:y ?y)) (bind ?p ?f:valore))
   (do-for-fact ((?f cf)) (and (eq ?f:tipo wumpus) (= ?f:x ?x) (= ?f:y ?y)) (bind ?w ?f:valore))
   (combina ?p ?w))

;; quante celle nuove potrei scoprire entrando in (x,y): vicine non
;; visitate e non muri (serve a scegliere tra celle ugualmente pericolose:
;; meglio quella che apre piu' territorio)
(deffunction CERTEZZA::guadagno (?x ?y)
   (bind ?g 0)
   (foreach ?v (create$ 1 2 3 4)
      (bind ?nx (+ ?x (nth$ ?v (create$ 1 -1 0 0))))
      (bind ?ny (+ ?y (nth$ ?v (create$ 0 0 1 -1))))
      (if (and (>= ?nx 0) (>= ?ny 0)
               (not (any-factp ((?f visitata)) (and (= ?f:x ?nx) (= ?f:y ?ny))))
               (not (any-factp ((?f muro)) (and (= ?f:x ?nx) (= ?f:y ?ny)))))
         then (bind ?g (+ ?g 1))))
   ?g)

;; tra le celle incerte di frontiera (vicine di una visitata, non sicure,
;; non muri, non pericoli certi) si tiene quella con pericolo minimo;
;; a parita' di pericolo quella con guadagno informativo maggiore
(defrule CERTEZZA::candidata-rischio
   (declare (salience 10))
   (turno (n ?s))
   (visitata (x ?vx) (y ?vy))
   (cella (x ?x) (y ?y&:(adiacenti ?vx ?vy ?x ?y)))
   (not (visitata (x ?x) (y ?y)))
   (not (sicura (x ?x) (y ?y)))
   (not (muro (x ?x) (y ?y)))
   (not (pozzo (x ?x) (y ?y)))
   (not (wumpus (x ?x) (y ?y)))
   =>
   (bind ?p (pericolo ?x ?y))
   (bind ?g (guadagno ?x ?y))
   (bind ?migliore TRUE)
   (do-for-fact ((?b bersaglio-rischio)) TRUE
      (if (or (< ?b:pericolo ?p)
              (and (= ?b:pericolo ?p) (>= (guadagno ?b:x ?b:y) ?g)))
         then (bind ?migliore FALSE)
         else (retract ?b)))
   (if ?migliore then (assert (bersaglio-rischio (x ?x) (y ?y) (pericolo ?p)))))

;;; =====================================================================
;;;  DISTANZE: campi di distanza (BFS a ondata, come nell'agente 2)
;;;   casa     : verso la cella di partenza            (su celle visitate)
;;;   esplora  : verso la cella sicura non visitata piu' vicina (su sicure)
;;;   oro      : verso l'oro gia' visto                 (su celle visitate)
;;;   dichiara : verso una cella visitata vicina a un pozzo da dichiarare
;;;   rischio  : verso una cella visitata vicina al bersaglio-rischio
;;; =====================================================================
(defmodule DISTANZE (import MAIN ?ALL))

(defrule DISTANZE::azzera
   (declare (salience 100))
   (ricalcola)
   (or ?d <- (dist) ?d <- (riserva))
   =>
   (retract ?d))

(defrule DISTANZE::fine-azzeramento
   (declare (salience 90))
   ?r <- (ricalcola)
   =>
   (retract ?r))

(defrule DISTANZE::sorgente-casa
   (declare (salience 50))
   (turno (n ?s))
   (casa (x ?x) (y ?y))
   =>
   (assert (dist (tipo casa) (x ?x) (y ?y) (d 0))))

(defrule DISTANZE::sorgenti-esplora
   (declare (salience 50))
   (turno (n ?s))
   (sicura (x ?x) (y ?y))
   (not (visitata (x ?x) (y ?y)))
   =>
   (assert (dist (tipo esplora) (x ?x) (y ?y) (d 0))))

(defrule DISTANZE::sorgente-oro
   (declare (salience 50))
   (turno (n ?s))
   (oro (x ?x) (y ?y))
   (not (oro-preso))
   =>
   (assert (dist (tipo oro) (x ?x) (y ?y) (d 0))))

(defrule DISTANZE::sorgenti-dichiara
   (declare (salience 50))
   (turno (n ?s))
   (cf (tipo pozzo) (x ?px) (y ?py) (valore ?v&:(>= ?v (param soglia-dichiarazione))))
   (not (dichiarato (x ?px) (y ?py)))
   (visitata (x ?x) (y ?y&:(adiacenti ?x ?y ?px ?py)))
   =>
   (assert (dist (tipo dichiara) (x ?x) (y ?y) (d 0))))

(defrule DISTANZE::sorgenti-rischio
   (declare (salience 50))
   (turno (n ?s))
   (bersaglio-rischio (x ?bx) (y ?by) (pericolo ?p&:(<= ?p (param soglia-rischio))))
   (visitata (x ?x) (y ?y&:(adiacenti ?x ?y ?bx ?by)))
   =>
   (assert (dist (tipo rischio) (x ?x) (y ?y) (d 0))))

;; tutti i campi tranne "esplora" si propagano solo su celle visitate
(defrule DISTANZE::propaga-visitate
   (dist (tipo ?t&~esplora) (x ?x) (y ?y) (d ?d))
   (visitata (x ?nx) (y ?ny&:(adiacenti ?x ?y ?nx ?ny)))
   (not (dist (tipo ?t) (x ?nx) (y ?ny)))
   =>
   (assert (dist (tipo ?t) (x ?nx) (y ?ny) (d (+ ?d 1)))))

(defrule DISTANZE::propaga-esplora
   (dist (tipo esplora) (x ?x) (y ?y) (d ?d))
   (sicura (x ?nx) (y ?ny&:(adiacenti ?x ?y ?nx ?ny)))
   (not (dist (tipo esplora) (x ?nx) (y ?ny)))
   =>
   (assert (dist (tipo esplora) (x ?nx) (y ?ny) (d (+ ?d 1)))))

;; energia che devo conservare: per tornare all'oro e poi a casa se
;; l'oro e' noto, altrimenti per tornare a casa
(deffunction DISTANZE::calcola-riserva (?x ?y)
   (bind ?dc 0) (bind ?do -1) (bind ?doc 0)
   (do-for-fact ((?d dist)) (and (eq ?d:tipo casa) (= ?d:x ?x) (= ?d:y ?y)) (bind ?dc ?d:d))
   (do-for-fact ((?d dist)) (and (eq ?d:tipo oro) (= ?d:x ?x) (= ?d:y ?y)) (bind ?do ?d:d))
   (if (>= ?do 0) then
      (do-for-fact ((?o oro) (?d dist))
         (and (eq ?d:tipo casa) (= ?d:x ?o:x) (= ?d:y ?o:y)) (bind ?doc ?d:d))
      (return (+ ?do ?doc))
    else (return ?dc)))

;; ATTENZIONE: va calcolata come FATTO alla fine del modulo (salience
;; negativa = dopo che tutte le distanze si sono stabilizzate). Se la si
;; chiamasse dentro un pattern di DECISIONE, CLIPS la valuterebbe nel
;; momento del matching (quando arriva il fatto energia, in PERCEZIONE),
;; cioe' PRIMA che le distanze del passo esistano: errore trovato in test.
(defrule DISTANZE::riserva
   (declare (salience -10))
   (turno (n ?s))
   (pos (x ?x) (y ?y))
   (not (riserva))
   =>
   (assert (riserva (valore (calcola-riserva ?x ?y)))))

(defrule DISTANZE::accorcia
   (declare (salience 10))
   (dist (tipo ?t) (x ?x) (y ?y) (d ?d))
   ?f <- (dist (tipo ?t) (x ?nx) (y ?ny&:(adiacenti ?x ?y ?nx ?ny)) (d ?d2&:(> ?d2 (+ ?d 1))))
   =>
   (modify ?f (d (+ ?d 1))))

;;; =====================================================================
;;;  DECISIONE (agente 3)
;;;  Fasi:  esplora -> (prendi-oro) -> ritorno
;;;  Ordine delle priorita' per le azioni (salience):
;;;   100 dichiarare un pozzo adiacente con CF alto
;;;    90 prendere l'oro se non resta altro di utile (o in fase prendi-oro)
;;;    80 uscire se a casa in fase ritorno
;;;    75 andare verso l'oro (fase prendi-oro)
;;;    70 andare verso casa (fase ritorno)
;;;    60 esplorare celle sicure
;;;    55 andare a dichiarare pozzi lontani
;;;    50 rischio calcolato (solo se l'oro non e' ancora stato visto)
;;; =====================================================================
(defmodule DECISIONE (import MAIN ?ALL))

(defrule DECISIONE::primo-passo
   (turno (n ?s))
   (not (pos))
   (not (decisione))
   =>
   (assert (decisione (azione grab) (motivo "nessuna percezione ancora"))))

;; --- cambi di fase ---------------------------------------------------
(defrule DECISIONE::oro-in-tasca
   (declare (salience 210))
   ?f <- (fase (nome ~ritorno))
   (oro-preso)
   =>
   (modify ?f (nome ritorno)))

(defrule DECISIONE::energia-per-l-oro
   (declare (salience 200))
   ?f <- (fase (nome esplora))
   (oro (x ?ox) (y ?oy))
   (not (oro-preso))
   (riserva (valore ?r))
   (energia (valore ?e&:(<= ?e (+ ?r 4))))
   =>
   (modify ?f (nome prendi-oro))
   (printout t "  [decisione] energia " ?e ": vado a prendere l'oro" crlf))

(defrule DECISIONE::energia-per-casa
   (declare (salience 200))
   ?f <- (fase (nome esplora))
   (not (oro))
   (riserva (valore ?r))
   (energia (valore ?e&:(<= ?e (+ ?r 2))))
   =>
   (modify ?f (nome ritorno))
   (printout t "  [decisione] energia " ?e ": torno a casa" crlf))

;; nulla di sicuro da esplorare ne' pozzi da dichiarare:
;; con l'oro noto si va a prenderlo, altrimenti (se non c'e' un rischio
;; accettabile) si torna a casa
(defrule DECISIONE::niente-da-fare-con-oro
   (declare (salience 190))
   ?f <- (fase (nome esplora))
   (oro) (not (oro-preso))
   (pos (x ?x) (y ?y))
   (not (dist (tipo esplora) (x ?x) (y ?y)))
   (not (dist (tipo dichiara) (x ?x) (y ?y)))
   =>
   (modify ?f (nome prendi-oro))
   (printout t "  [decisione] esplorazione finita: vado a prendere l'oro" crlf))

(defrule DECISIONE::niente-da-fare-senza-oro
   (declare (salience 190))
   ?f <- (fase (nome esplora))
   (not (oro))
   (pos (x ?x) (y ?y))
   (not (dist (tipo esplora) (x ?x) (y ?y)))
   (not (dist (tipo dichiara) (x ?x) (y ?y)))
   (not (dist (tipo rischio) (x ?x) (y ?y)))
   =>
   (modify ?f (nome ritorno))
   (printout t "  [decisione] niente di sicuro ne' di accettabile: torno a casa" crlf))

;; --- azioni ----------------------------------------------------------
(defrule DECISIONE::dichiara-pozzo
   (declare (salience 100))
   (turno (n ?s))
   (fase (nome ~ritorno))
   (pos (x ?x) (y ?y))
   (cf (tipo pozzo) (x ?px) (y ?py&:(adiacenti ?x ?y ?px ?py))
       (valore ?v&:(>= ?v (param soglia-dichiarazione))))
   (not (dichiarato (x ?px) (y ?py)))
   (riserva (valore ?r))
   (energia (valore ?e&:(> ?e (+ ?r 4))))
   (not (decisione))
   =>
   (assert (decisione (azione (dichiarazione ?x ?y ?px ?py))
                      (motivo (str-cat "pozzo con CF " ?v)))))

(defrule DECISIONE::prendi-oro
   (declare (salience 90))
   (turno (n ?s))
   (fase (nome prendi-oro))
   (pos (x ?x) (y ?y))
   (oro (x ?x) (y ?y))
   (not (oro-preso))
   (not (decisione))
   =>
   (assert (decisione (azione grab) (motivo "oro (esplorazione conclusa)"))))

(defrule DECISIONE::esci
   (declare (salience 80))
   (turno (n ?s))
   (fase (nome ritorno))
   (pos (x ?x) (y ?y))
   (casa (x ?x) (y ?y))
   (not (decisione))
   =>
   (assert (decisione (azione quit) (motivo "a casa"))))

(defrule DECISIONE::verso-oro
   (declare (salience 75))
   (turno (n ?s))
   (fase (nome prendi-oro))
   (pos (x ?x) (y ?y))
   (dist (tipo oro) (x ?x) (y ?y) (d ?d&:(> ?d 0)))
   (dist (tipo oro) (x ?nx) (y ?ny&:(adiacenti ?x ?y ?nx ?ny)) (d =(- ?d 1)))
   (not (decisione))
   =>
   (assert (decisione (azione (direzione ?x ?y ?nx ?ny)) (motivo "verso l'oro"))))

(defrule DECISIONE::verso-casa
   (declare (salience 70))
   (turno (n ?s))
   (fase (nome ritorno))
   (pos (x ?x) (y ?y))
   (dist (tipo casa) (x ?x) (y ?y) (d ?d&:(> ?d 0)))
   (dist (tipo casa) (x ?nx) (y ?ny&:(adiacenti ?x ?y ?nx ?ny)) (d =(- ?d 1)))
   (not (decisione))
   =>
   (assert (decisione (azione (direzione ?x ?y ?nx ?ny)) (motivo "ritorno a casa"))))

(defrule DECISIONE::esplora
   (declare (salience 60))
   (turno (n ?s))
   (fase (nome esplora))
   (pos (x ?x) (y ?y))
   (dist (tipo esplora) (x ?x) (y ?y) (d ?d&:(> ?d 0)))
   (dist (tipo esplora) (x ?nx) (y ?ny&:(adiacenti ?x ?y ?nx ?ny)) (d =(- ?d 1)))
   (not (decisione))
   =>
   (assert (decisione (azione (direzione ?x ?y ?nx ?ny)) (motivo "esplorazione"))))

(defrule DECISIONE::verso-dichiarazione
   (declare (salience 55))
   (turno (n ?s))
   (fase (nome esplora))
   (pos (x ?x) (y ?y))
   (not (dist (tipo esplora) (x ?x) (y ?y)))
   (dist (tipo dichiara) (x ?x) (y ?y) (d ?d&:(> ?d 0)))
   (dist (tipo dichiara) (x ?nx) (y ?ny&:(adiacenti ?x ?y ?nx ?ny)) (d =(- ?d 1)))
   (not (decisione))
   =>
   (assert (decisione (azione (direzione ?x ?y ?nx ?ny)) (motivo "vado a dichiarare un pozzo"))))

;; rischio calcolato: solo senza oro noto e senza alternative sicure
(defrule DECISIONE::verso-rischio
   (declare (salience 50))
   (turno (n ?s))
   (fase (nome esplora))
   (not (oro))
   (pos (x ?x) (y ?y))
   (not (dist (tipo esplora) (x ?x) (y ?y)))
   (not (dist (tipo dichiara) (x ?x) (y ?y)))
   (dist (tipo rischio) (x ?x) (y ?y) (d ?d&:(> ?d 0)))
   (dist (tipo rischio) (x ?nx) (y ?ny&:(adiacenti ?x ?y ?nx ?ny)) (d =(- ?d 1)))
   (not (decisione))
   =>
   (assert (decisione (azione (direzione ?x ?y ?nx ?ny)) (motivo "verso la cella meno pericolosa"))))

(defrule DECISIONE::entra-a-rischio
   (declare (salience 50))
   (turno (n ?s))
   (fase (nome esplora))
   (not (oro))
   (pos (x ?x) (y ?y))
   (not (dist (tipo esplora) (x ?x) (y ?y)))
   (not (dist (tipo dichiara) (x ?x) (y ?y)))
   (dist (tipo rischio) (x ?x) (y ?y) (d 0))
   (bersaglio-rischio (x ?bx) (y ?by&:(adiacenti ?x ?y ?bx ?by)) (pericolo ?p))
   (riserva (valore ?r))
   (energia (valore ?e&:(> ?e (+ ?r 10))))
   (not (decisione))
   =>
   (assert (decisione (azione (direzione ?x ?y ?bx ?by))
                      (motivo (str-cat "RISCHIO calcolato, pericolo stimato " ?p)))))

(defrule DECISIONE::paracadute
   (declare (salience -100))
   (turno (n ?s))
   (not (decisione))
   =>
   (assert (decisione (azione grab) (motivo "nessuna regola applicabile"))))

;;; =====================================================================
;;;  AZIONE: traduce la decisione nell'UNICO fatto action del passo
;;; =====================================================================
(defmodule AZIONE (import MAIN ?ALL))

(defrule AZIONE::esegui
   ?d <- (decisione (azione ?a) (motivo ?m))
   (turno (n ?s))
   =>
   (retract ?d)
   (assert (action (move ?a)))
   (printout t "passo " ?s ": " ?a "   (" ?m ")" crlf)
   ;; memoria dell'azione, per capire al passo dopo se ho urtato un muro
   (do-for-fact ((?p pos)) TRUE
      (assert (ultima-mossa (dir ?a) (x ?p:x) (y ?p:y)))
      (if (member$ ?a (create$ pit-north pit-south pit-west pit-east)) then
         (bind ?px (+ ?p:x (if (eq ?a pit-east) then 1 else (if (eq ?a pit-west) then -1 else 0))))
         (bind ?py (+ ?p:y (if (eq ?a pit-south) then 1 else (if (eq ?a pit-north) then -1 else 0))))
         (assert (dichiarato (x ?px) (y ?py))))
      (if (and (eq ?a grab) (any-factp ((?o oro)) (and (= ?o:x ?p:x) (= ?o:y ?p:y)))) then
         (assert (oro-preso)))))
