# 02. EMSx dataset

## Source officielle

- Landing page: <https://zenodo.org/records/5510400>
- DOI: `10.5281/zenodo.5510400`

## Ce que contient la source

Le record public reference un dataset intitule:

- `The EMSx dataset: historical photovoltaic and load scenarios and forecasts for 70 industrial sites`

Le record liste notamment:

- `70` fichiers compreses par site;
- un fichier `metadata.csv`;
- un fichier `pv.csv.gz`.

## Pourquoi cette source est importante

Le coeur de l'article Prattico porte sur un **EMS fuzzy**. Pour la these, EMSx est une source tres forte parce qu'elle offre:

- des historiques de charge et de production PV;
- des previsions;
- une variabilite multi-sites;
- un contexte industriel plus realiste qu'un simple profil synthetique isole.

## Apport pour la these

Cette source peut servir a:

- tester votre logique EMS sur plusieurs sites et non sur un cas unique;
- montrer la robustesse aux erreurs de prevision;
- construire une section "benchmark public multi-scenarios".

Elle est particulierement pertinente si vous voulez relier votre travail a:

- dispatch;
- arbitrage batterie;
- robustesse;
- controle sous incertitude;
- performance generalisable.

## Utilisation recommandee

Usage prioritaire:

1. exploiter `metadata.csv` pour identifier les sites et les variables utiles;
2. choisir 3 a 5 sites representatifs pour un premier benchmark;
3. injecter vos algorithmes de decision ou de surete sur des cas publics.

## Limites

- ce n'est pas une source de dynamique electrique fine;
- pas de tension/frequence detaillees comme dans un dataset de terrain instrumente;
- volume important si l'on telecharge tout.

## Statut local

- fiche documentee;
- `metadata.csv` telechargeable automatiquement via `fetch_public_microgrid_data.ps1`;
- les gros fichiers par site sont laisses en telechargement optionnel.
