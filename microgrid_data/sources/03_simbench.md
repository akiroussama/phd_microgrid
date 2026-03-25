# 03. SimBench

## Source officielle

- Download page: <https://simbench.de/en/download/>
- Reference paper: <https://doi.org/10.3390/en13020359>

## Ce que contient la source

La page officielle SimBench presente:

- un benchmark ouvert pour l'analyse et l'exploitation des reseaux electriques;
- des jeux de donnees construits autour de **13 grilles representatives**;
- des **time series** pour charge, generation et stockage;
- une licence **Open Database License** pour les datasets.

## Pourquoi cette source compte pour la these

SimBench n'est pas un clone de Prattico, mais c'est une reference tres defendable pour la reproductibilite:

- benchmark connu dans la communaute;
- topologies et profils publics;
- cas d'etude comparables et relancables par d'autres chercheurs.

## Apport pour la these

Cette source peut servir a:

- ajouter une couche de validation standardisee au-dessus du cas Prattico;
- tester le comportement de votre controle sur des reseaux plus larges ou differents;
- preparer une publication ou une these ou la reproductibilite publique est importante.

## Utilisation recommandee

Usage prioritaire:

1. selectionner un sous-systeme basse tension ou un cas proche "microgrid-like";
2. reutiliser les profils load/generation/storage pour des campagnes de test;
3. comparer votre methode a des baselines dans un cadre ouvert.

## Limites

- benchmark reseau plutot qu'un site microgrid reel unique;
- moins adapte a la validation directe des variables Prattico que Mesa Del Sol;
- package potentiellement lourd.

## Statut local

- fiche documentee;
- pas de gros telechargement automatique par defaut;
- a utiliser comme socle de benchmark lorsqu'une campagne reproducible est necessaire.
