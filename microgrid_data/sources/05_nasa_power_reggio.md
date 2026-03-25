# 05. NASA POWER pour Reggio Calabria

## Source officielle

- Documentation API horaire: <https://power.larc.nasa.gov/docs/services/api/temporal/hourly/>
- Page principale: <https://power.larc.nasa.gov/>

## Ce que contient la source

La documentation officielle NASA POWER indique que l'API horaire renvoie des donnees "analysis-ready" pour:

- l'irradiance solaire;
- les variables meteorologiques;
- des formats tels que CSV, JSON, NetCDF et autres;
- une disponibilite horaire de 2001 a proche temps reel.

Dans ce dossier, un exemple a ete prepare pour **Reggio Calabria** afin d'aligner les donnees publiques avec le site de reference de Prattico.

## Pourquoi cette source est critique pour la these

Si les auteurs Prattico ne fournissent pas leurs profils d'entree, le point le plus defendable est:

- de partir d'une source meteorologique officielle;
- de regenerer des profils PV/vent/temperature coherents avec la localisation du papier;
- de documenter clairement la chaine de transformation vers les puissances.

## Apport pour la these

Cette source permet:

- de remplacer des profils "inventes" par une base officielle;
- de justifier les scenarios journaliers ou saisonniers;
- de rendre la reconstruction du cas Prattico plus tracable.

## Utilisation recommandee

Usage prioritaire:

1. recuperer irradiance, temperature et vitesse de vent sur Reggio Calabria;
2. reconstruire les puissances PV/WT selon vos modeles;
3. documenter les hypotheses de conversion.

## Limites

- ce n'est pas un dataset microgrid complet;
- il faut faire le passage meteo -> puissance;
- la resolution horaire peut etre insuffisante pour certains transitoires rapides.

## Statut local

- fiche documentee;
- un echantillon CSV est telechargeable automatiquement pour Reggio Calabria via `fetch_public_microgrid_data.ps1`.
