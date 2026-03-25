# 01. Mesa Del Sol microgrid dataset

## Source officielle

- Landing page: <https://zenodo.org/records/8339403>
- DOI: `10.5061/dryad.fqz612jzb`

## Ce que contient la source

Le record public reference un dataset intitule:

- `Power, voltage, frequency and temperature dataset from Mesa Del Sol microgrid`

Le record liste:

- 15 fichiers mensuels CSV;
- 1 fichier `README.md`;
- une periode allant de mai 2022 a juillet 2023.

Le `README.md` officiel telecharge localement confirme:

- resolution: **10 secondes**;
- nombre de variables: **17**;
- donnees de puissance, tension, frequence et temperature;
- presence explicite de mesures batterie, PV, fuel cell et bus AC.

## Pourquoi cette source est tres interessante pour la these

C'est la source la plus proche de vos besoins de **validation microgrid** au sens electrique:

- on y retrouve explicitement la puissance, la tension, la frequence et la temperature;
- le microgrid reference des actifs pertinents pour Prattico, notamment batterie, PV et fuel cell;
- cela permet de sortir d'une validation purement "papier -> modele" en montrant qu'on compare aussi a une source publique de terrain.

## Apport pour la these

Cette source peut nourrir:

- la justification des ordres de grandeur de variables electriques;
- la discussion sur la qualite de puissance et le comportement au PCC;
- la defense de la these face a la critique "tout est simule / aucune donnee publique reelle".

## Utilisation recommandee

Usage prioritaire:

1. identifier les variables compatibles avec vos sorties Simulink/Simscape;
2. comparer les envelopes et regimes, pas seulement les valeurs instantanees;
3. construire un mini protocole de validation sur tension/frequence/puissance.

## Limites

- topologie non identique a Prattico;
- mapping des variables a faire proprement;
- taille non negligeable du dataset si on telecharge tous les mois.

## Statut local

- fiche documentee;
- `samples/mesa_del_sol_README.md` present localement;
- telechargement leger possible via `fetch_public_microgrid_data.ps1` pour le `README.md`;
- les gros CSV mensuels restent a telecharger a la demande.
