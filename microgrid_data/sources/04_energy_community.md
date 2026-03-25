# 04. Energy community dataset

## Source officielle

- Landing page: <https://zenodo.org/records/11351017>
- DOI: `10.5281/zenodo.11351017`

## Ce que contient la source

Le record public reference:

- `A complete energy community dataset with photovoltaic generation, battery energy storage systems and electric vehicles (v1.5)`

Le descriptif public indique notamment:

- `250 households`;
- `200 PV systems`;
- `150 batteries`;
- `20 electric vehicles`.

Le record contient:

- un fichier `EC_EV_dataset (fixed error).xlsx`;
- un document `General description.docx`.

## Pourquoi cette source peut aider la these

Cette source est utile si vous voulez depasser des charges simplifiees et approcher une logique de **communaute energetique**:

- diversite de comportements utilisateurs;
- presence explicite de PV, batteries et EV;
- bon support pour des scenarios multi-acteurs.

## Apport pour la these

Elle peut servir a:

- enrichir les profils de charge et de production;
- tester la sensibilite a l'heterogeneite des prosumers;
- construire des scenarios secondaires plus riches autour du noyau Prattico.

## Utilisation recommandee

Usage prioritaire:

1. utiliser ce dataset comme source de profils agreges/residentiels;
2. comparer vos profils actuels a des profils plus realistes;
3. introduire un sous-chapitre sur la generalisation vers une communaute energetique.

## Limites

- moins axe sur la dynamique electrique au PCC;
- plus pertinent pour la flexibilite et les profils que pour la PQ;
- pas un jumeau direct de Prattico.

## Statut local

- fiche documentee;
- telechargement optionnel des fichiers publics via `fetch_public_microgrid_data.ps1 -IncludeEnergyCommunityFiles`.
