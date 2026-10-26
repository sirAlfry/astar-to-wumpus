% =====================================================================
% torneo.lp  -  Calendario del prossimo turno di un torneo della Lega
%               Pokemon (stile "sistema svizzero")
% ---------------------------------------------------------------------
% INPUT (in un file di istanza separato, vedi istanze/):
%   giocatore(P).          i partecipanti del turno (anche i nuovi entrati)
%   giocato(P1,P2).        incontri gia' disputati (ordine indifferente)
%   bye_avuto(P).          chi ha gia' avuto il BYE in un turno precedente
%   punti(P,N).            classifica attuale (chi manca ha 0 punti)
%
% OUTPUT:
%   incontro(P1,P2)        con P1 < P2 (ordine alfabetico), uno per coppia
%   bye(P)                 chi riposa in questo turno (solo se dispari)
%
% Schema classico GENERATE - DEFINE - TEST - OPTIMIZE:
%   generate : regole di scelta che propongono incontri e BYE
%   define   : predicati ausiliari (impegnato/1, stesso_punteggio/2, ...)
%   test     : vincoli di integrita' che eliminano gli answer set non validi
%   optimize : #maximize / #minimize con priorita' per scegliere il migliore
%
% Esecuzione:  clingo torneo.lp istanze/turno1.lp
%              clingo torneo.lp istanze/turno2.lp --opt-mode=optN 0
%              (la seconda forma elenca tutti gli abbinamenti ottimi)
% =====================================================================

% Nelle istanze iniziali alcuni predicati possono mancare del tutto:
% #defined evita gli avvisi "atom does not occur in any rule head".
#defined giocato/2.
#defined bye_avuto/1.
#defined punti/2.

% ------------------------------------------------------------- DEFINE
% Chi non compare in classifica (es. un nuovo giocatore) ha 0 punti.
ha_punti(P) :- punti(P,_).
pt(P,N) :- punti(P,N), giocatore(P).
pt(P,0) :- giocatore(P), not ha_punti(P).

% giocato/2 e' simmetrico: chi ha affrontato chi, in entrambe le direzioni.
gia_affrontati(P,Q) :- giocato(P,Q).
gia_affrontati(P,Q) :- giocato(Q,P).

% Il numero di partecipanti e' dispari?
num_giocatori(N) :- N = #count{ P : giocatore(P) }.
dispari :- num_giocatori(N), N \ 2 = 1.

% ----------------------------------------------------------- GENERATE
% Se i partecipanti sono dispari, esattamente uno riposa, scelto tra chi
% non ha ancora avuto il BYE  (vincolo "BYE al massimo una volta").
1 { bye(P) : giocatore(P), not bye_avuto(P) } 1 :- dispari.

% Si propone un sottoinsieme qualsiasi di incontri tra coppie che non si
% sono ancora affrontate (vincolo "al massimo una volta nel torneo").
% P < Q evita di generare due volte la stessa coppia (a,b) e (b,a).
{ incontro(P,Q) : giocatore(P), giocatore(Q), P < Q, not gia_affrontati(P,Q) }.

% --------------------------------------------------------------- TEST
% Ogni giocatore e' impegnato in ESATTAMENTE una cosa: un incontro o il BYE.
impegnato(P) :- incontro(P,_).
impegnato(P) :- incontro(_,P).
impegnato(P) :- bye(P).
% (a) almeno una: nessuno resta senza avversario e senza BYE
:- giocatore(P), not impegnato(P).
% (b) al piu' una: nessuno gioca due incontri, o gioca e riposa insieme
:- giocatore(P), 2 { incontro(P,Q) : giocatore(Q) ; incontro(Q,P) : giocatore(Q) ; bye(P) }.

% ----------------------------------------------------------- OPTIMIZE
% Incontri "misti": tra giocatori con punteggio diverso.
misto(P,Q) :- incontro(P,Q), pt(P,NP), pt(Q,NQ), NP != NQ.

% Priorita' 3 (la piu' importante, e' il requisito principale):
% massimizzare gli incontri tra giocatori con lo stesso punteggio.
% Il numero di incontri e' fisso (n/2 arrotondato per difetto), quindi
% equivale a MINIMIZZARE gli incontri misti. La forma "minimize" e' molto
% piu' efficiente: con #maximize il solver, per dimostrare l'ottimo, deve
% provare che non esistono n/2+1 coppie a pari punteggio, un ragionamento
% "a piccionaia" che i solver CDCL fanno male (con 32 giocatori non
% terminava in minuti); con #minimize l'ottimo 0 si dimostra subito.
#minimize { 1@3,P,Q : misto(P,Q) }.

% Priorita' 2: tra gli incontri "misti" (inevitabili quando un gruppo di
% pari punteggio e' dispari) preferire avversari con punteggio vicino:
% si minimizza la somma delle differenze di punteggio.
#minimize { D@2,P,Q : incontro(P,Q), pt(P,NP), pt(Q,NQ), D = |NP-NQ| }.

% Priorita' 1: come nel sistema svizzero, il BYE va preferibilmente a chi
% e' piu' in basso in classifica (si minimizzano i suoi punti).
#minimize { N@1,P : bye(P), pt(P,N) }.

#show incontro/2.
#show bye/1.
