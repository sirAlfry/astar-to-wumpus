;;; =====================================================================
;;;  AGENTE 2 - "LOGICO"
;;;  L'oro del Wumpus - Progetto di IA e Laboratorio 2025/26 (Micalizio)
;;; ---------------------------------------------------------------------
;;;  Strategia in una frase: ragiona come un detective (deduce dove sono
;;;  pozzi e Wumpus per eliminazione), si muove solo su celle DIMOSTRATE
;;;  sicure lungo il cammino piu' breve, dichiara i pozzi certi, prende
;;;  l'oro e torna a casa prima di finire l'energia.
;;;
;;;  Differenze rispetto all'agente 1 (base):
;;;   - inferenza globale: una cella e' sicura anche se le informazioni
;;;     arrivano da celle diverse (no-pozzo da una, no-Wumpus da un'altra)
;;;   - deduzione per eliminazione di pozzi e Wumpus certi (+25 a pozzo)
;;;   - "c'e' un solo Wumpus": deve essere adiacente a TUTTE le celle con
;;;     puzza, quindi le altre celle sono libere dal Wumpus
;;;   - pianificazione dei percorsi minimi (BFS a ondata, vedi DISTANZE)
;;;     invece del ritorno sui propri passi
;;;   - controllo dell'energia sulla distanza reale da casa
;;;
;;;  Ciclo di un passo (ogni volta che il simulatore aggiorna counter):
;;;    MAIN -> PERCEZIONE -> INFERENZA -> DISTANZE -> DECISIONE -> AZIONE
;;;
;;;  Convenzioni del simulatore (wumpus.py): x = colonna, y = riga,
;;;  up = y-1 (nord), down = y+1 (sud), left = x-1 (ovest), right = x+1.
;;;  pit-north dichiara un pozzo in (x, y-1), pit-east in (x+1, y), ecc.
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

(deffacts MAIN::iniziali
   (counter (step 0))
   (fase (nome esplora)))

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
   (focus PERCEZIONE INFERENZA DISTANZE DECISIONE AZIONE))

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
;;;  DISTANZE: campi di distanza calcolati con una BFS "a ondata"
;;;   (dist casa x y d)   = passi da (x,y) a casa, solo su celle VISITATE
;;;                         (sicuramente percorribili, nessun muro nascosto)
;;;   (dist esplora x y d)= passi da (x,y) alla cella sicura non visitata
;;;                         piu' vicina (attraversando celle sicure)
;;;  Si parte dai bersagli (d = 0) e si propaga d+1 alle vicine; la regola
;;;  "accorcia" corregge le distanze trovate prima per un giro piu' lungo,
;;;  quindi alla fine ogni d e' la distanza minima (Bellman-Ford).
;;; =====================================================================
(defmodule DISTANZE (import MAIN ?ALL))

;; si buttano i campi del passo precedente finche' c'e' il gettone
;; "ricalcola"; poi il gettone sparisce, cosi' i campi nuovi non vengono
;; cancellati appena creati (senza gettone sarebbe un ciclo infinito)
(defrule DISTANZE::azzera
   (declare (salience 100))
   (ricalcola)
   ?d <- (dist)
   =>
   (retract ?d))

(defrule DISTANZE::fine-azzeramento
   (declare (salience 90))
   ?r <- (ricalcola)
   =>
   (retract ?r))

;; le sorgenti dipendono da turno (fatto nuovo a ogni passo): altrimenti,
;; per la rifrazione, scatterebbero solo la prima volta
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

(defrule DISTANZE::propaga-casa
   (dist (tipo casa) (x ?x) (y ?y) (d ?d))
   (visitata (x ?nx) (y ?ny&:(adiacenti ?x ?y ?nx ?ny)))
   (not (dist (tipo casa) (x ?nx) (y ?ny)))
   =>
   (assert (dist (tipo casa) (x ?nx) (y ?ny) (d (+ ?d 1)))))

(defrule DISTANZE::propaga-esplora
   (dist (tipo esplora) (x ?x) (y ?y) (d ?d))
   (sicura (x ?nx) (y ?ny&:(adiacenti ?x ?y ?nx ?ny)))
   (not (dist (tipo esplora) (x ?nx) (y ?ny)))
   =>
   (assert (dist (tipo esplora) (x ?nx) (y ?ny) (d (+ ?d 1)))))

(defrule DISTANZE::accorcia
   (declare (salience 10))
   (dist (tipo ?t) (x ?x) (y ?y) (d ?d))
   ?f <- (dist (tipo ?t) (x ?nx) (y ?ny&:(adiacenti ?x ?y ?nx ?ny)) (d ?d2&:(> ?d2 (+ ?d 1))))
   =>
   (modify ?f (d (+ ?d 1))))

;;; =====================================================================
;;;  DECISIONE: sceglie UNA azione (fatto decisione).
;;;  Regole in ordine di priorita' (salience); ognuna richiede che non ci
;;;  sia gia' una decisione, quindi ne scatta al massimo una per passo.
;;;  Le regole di "cambio fase" hanno salience piu' alta e non decidono.
;;; =====================================================================
(defmodule DECISIONE (import MAIN ?ALL))

;; passo 0: il simulatore non ha ancora mandato percezioni.
;; "grab" e' l'azione innocua per eccellenza: costa 1 di energia e, se
;; l'oro fosse proprio nella cella di partenza, lo prende.
(defrule DECISIONE::primo-passo
   (turno (n ?s))
   (not (pos))
   (not (decisione))
   =>
   (assert (decisione (azione grab) (motivo "nessuna percezione ancora"))))

;; --- cambi di fase ---------------------------------------------------
(defrule DECISIONE::energia-agli-sgoccioli
   (declare (salience 200))
   ?f <- (fase (nome esplora))
   (pos (x ?x) (y ?y))
   (energia (valore ?e))
   (dist (tipo casa) (x ?x) (y ?y) (d ?dc&:(<= ?e (+ ?dc 2))))
   =>
   (modify ?f (nome ritorno))
   (printout t "  [decisione] energia " ?e ", casa a " ?dc " passi: torno" crlf))

(defrule DECISIONE::niente-da-esplorare
   (declare (salience 190))
   ?f <- (fase (nome esplora))
   (pos (x ?x) (y ?y))
   (not (dist (tipo esplora) (x ?x) (y ?y)))
   =>
   (modify ?f (nome ritorno))
   (printout t "  [decisione] nessuna cella sicura da esplorare: torno a casa" crlf))

(defrule DECISIONE::oro-in-tasca
   (declare (salience 190))
   ?f <- (fase (nome esplora))
   (oro-preso)
   =>
   (modify ?f (nome ritorno)))

;; --- azioni ----------------------------------------------------------
;; 1. dichiarare un pozzo certo adiacente (+25), se l'energia lo permette
(defrule DECISIONE::dichiara-pozzo
   (declare (salience 100))
   (turno (n ?s))
   (pos (x ?x) (y ?y))
   (pozzo (x ?px) (y ?py&:(adiacenti ?x ?y ?px ?py)))
   (not (dichiarato (x ?px) (y ?py)))
   (energia (valore ?e))
   (dist (tipo casa) (x ?x) (y ?y) (d ?dc&:(> ?e (+ ?dc 3))))
   (not (decisione))
   =>
   (assert (decisione (azione (dichiarazione ?x ?y ?px ?py))
                      (motivo "pozzo certo adiacente"))))

;; 2. prendere l'oro (con end_on_grab il gioco finisce qui)
(defrule DECISIONE::prendi-oro
   (declare (salience 90))
   (turno (n ?s))
   (pos (x ?x) (y ?y))
   (oro (x ?x) (y ?y))
   (not (oro-preso))
   (not (decisione))
   =>
   (assert (decisione (azione grab) (motivo "scintillio"))))

;; 3. a casa in fase di ritorno: uscire
(defrule DECISIONE::esci
   (declare (salience 80))
   (turno (n ?s))
   (fase (nome ritorno))
   (pos (x ?x) (y ?y))
   (casa (x ?x) (y ?y))
   (not (decisione))
   =>
   (assert (decisione (azione quit) (motivo "a casa"))))

;; 4. ritorno: un passo lungo il cammino minimo verso casa
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

;; 5. esplorazione: un passo verso la cella sicura non visitata piu' vicina
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

;; 6. paracadute: non dovrebbe mai servire, ma un passo senza azione
;;    farebbe eseguire al simulatore "right" (potenzialmente mortale)
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
