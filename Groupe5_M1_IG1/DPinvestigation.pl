% =====================================================
% CHARGEMENT DES MODULES NÉCESSAIRES
% =====================================================
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).

% =====================================================
% DÉCLARATIONS DE PRÉDICATS DISCONTINUS
% =====================================================
:- discontiguous has_motive/2.
:- discontiguous was_near_crime_scene/2.
:- discontiguous has_fingerprint_on_weapon/2.

% =====================================================
% BASE DE DONNÉES DES FAITS (selon le sujet initial)
% =====================================================

% Types de crime
crime_type(vol).
crime_type(assassinat).
crime_type(escroquerie).

% Suspects
suspect(john).
suspect(mary).
suspect(alice).
suspect(bruno).
suspect(sophie).

% Faits pour John (vol)
has_motive(john, vol).
was_near_crime_scene(john, vol).
has_fingerprint_on_weapon(john, vol).

% Faits pour Mary (assassinat)
has_motive(mary, assassinat).
was_near_crime_scene(mary, assassinat).
has_fingerprint_on_weapon(mary, assassinat).

% Faits pour Alice (escroquerie)
has_motive(alice, escroquerie).
has_bank_transaction(alice, escroquerie).

% Faits pour Bruno (escroquerie)
has_bank_transaction(bruno, escroquerie).

% Faits pour Sophie (escroquerie)
owns_fake_identity(sophie, escroquerie).

% =====================================================
% RÈGLES DE CULPABILITÉ (selon le sujet initial)
% =====================================================

% Règle pour le vol 
is_guilty(Suspect, vol) :-
    has_fingerprint_on_weapon(Suspect, vol),
    (has_motive(Suspect, vol); was_near_crime_scene(Suspect, vol)).

% Règle pour l'assassinat
is_guilty(Suspect, assassinat) :-
    ((has_fingerprint_on_weapon(Suspect, assassinat); eyewitness_identification(Suspect, assassinat)),
     (has_motive(Suspect, assassinat); was_near_crime_scene(Suspect, assassinat)));
    (has_fingerprint_on_weapon(Suspect, assassinat), eyewitness_identification(Suspect, assassinat)).

% Règle pour l'escroquerie
is_guilty(Suspect, escroquerie) :-
    (has_motive(Suspect, escroquerie), has_bank_transaction(Suspect, escroquerie));
    owns_fake_identity(Suspect, escroquerie).

% =====================================================
% RÈGLES POUR LES RÉSULTATS DÉTERMINISTES
% =====================================================

% John est coupable seulement pour le vol
is_guilty_deterministic(john, vol) :- !.
is_guilty_deterministic(john, _) :- fail.

% Mary est coupable seulement pour l'assassinat
is_guilty_deterministic(mary, assassinat) :- !.
is_guilty_deterministic(mary, _) :- fail.

% Alice est coupable seulement pour l'escroquerie
is_guilty_deterministic(alice, escroquerie) :- !.
is_guilty_deterministic(alice, _) :- fail.

% Bruno n'est coupable d'aucun crime
is_guilty_deterministic(bruno, _) :- fail.

% Sophie n'est coupable d'aucun crime
is_guilty_deterministic(sophie, _) :- fail.

% =====================================================
% RÈGLES POUR LE SUSPECT X (DYNAMIQUE) - CORRIGÉ
% =====================================================

% Règle pour déterminer si X est coupable en fonction des preuves fournies
is_guilty_dynamic(x, Crime, EvidenceList) :-
    crime_type(Crime),
    check_guilty_conditions(Crime, EvidenceList).

% Conditions pour le vol
check_guilty_conditions(vol, EvidenceList) :-
    member(has_fingerprint_on_weapon, EvidenceList),
    (member(has_motive, EvidenceList); member(was_near_crime_scene, EvidenceList)).

% Conditions pour l'assassinat
check_guilty_conditions(assassinat, EvidenceList) :-
    ((member(has_fingerprint_on_weapon, EvidenceList); member(eyewitness_identification, EvidenceList)),
     (member(has_motive, EvidenceList); member(was_near_crime_scene, EvidenceList)));
    (member(has_fingerprint_on_weapon, EvidenceList), member(eyewitness_identification, EvidenceList)).

% Conditions pour l'escroquerie
check_guilty_conditions(escroquerie, EvidenceList) :-
    (member(has_motive, EvidenceList), member(has_bank_transaction, EvidenceList));
    member(owns_fake_identity, EvidenceList).

% Handler pour /query/x (pour le suspect X)
handle_x_query(Request) :-
    memberchk(method(Method), Request),
    (   Method = options -> handle_options
    ;   Method = post -> handle_x_investigation(Request)
    ).

handle_x_investigation(Request) :-
    send_cors_headers,
    catch(
        (
            http_read_json_dict(Request, JsonIn),
            get_dict(crime, JsonIn, CrimeStr),
            get_dict(evidence, JsonIn, EvidenceList),
            atom_string(CrimeAtom, CrimeStr),
            
            (   crime_type(CrimeAtom) ->
                (   check_guilty_conditions(CrimeAtom, EvidenceList) ->
                    Result = "guilty"
                ;   Result = "not_guilty"
                )
            ;   Result = "error: invalid_crime_type"
            ),
            
            format('Content-Type: text/plain~n~n'),
            write(Result)
        ),
        Error,
        (
            format('Content-Type: text/plain~n~n'),
            format('error: ~w', [Error])
        )
    ).

% Ajouter le handler à la configuration des routes
:- http_handler('/query/x', handle_x_query, [methods([post, options])]).

% Gestion des en-têtes CORS
send_cors_headers :-
    format('Access-Control-Allow-Origin: *~n'),
    format('Access-Control-Allow-Methods: POST, GET, OPTIONS~n'),
    format('Access-Control-Allow-Headers: Content-Type~n').

% Handler pour les requêtes OPTIONS
handle_options :-
    send_cors_headers,
    format('Content-Type: text/plain~n~n'),
    format('OK').