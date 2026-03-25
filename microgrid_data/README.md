# Microgrid Public Data Research

## Objectif

En absence de retour des doctorants ayant coecrit l'article de reference de Prattico, ce dossier recense des alternatives **publiques** et **academiquement defendables** pour alimenter la these.

Le besoin n'est pas seulement de "trouver des donnees", mais de trouver des donnees qui servent concretement a:

- valider ou calibrer un modele de microgrid hybride AC/DC inspire de Prattico;
- tester l'EMS et les scenarios de gestion d'energie;
- reconstruire des profils exogenes credibles (irradiance, vent, temperature);
- fournir des benchmarks publics reproductibles quand les donnees reelles sont inaccessibles.

## Rappel du besoin Prattico

D'apres le contexte de these et le guide interne `simscape_prattico/GUIDE_CLONE_SIMSCAPE_PRATTICO.md`, la baseline Prattico cible notamment:

- PV 150 kWp;
- batterie 200 kWh;
- eolien 60 kW;
- pile a combustible 20 kW;
- charges AC et DC;
- suivi de la qualite de puissance au PCC;
- horizon de simulation journalier compresse;
- site de reference: **Reggio Calabria, Italie (juin)**.

Conclusion importante: **aucun dataset public unique ne recouvre parfaitement toute la topologie Prattico**. La strategie la plus solide pour la these est donc de combiner:

1. un dataset "microgrid reel" pour les variables electriques et l'exploitation du systeme;
2. un benchmark ouvert pour la reproductibilite;
3. une source meteorologique publique pour reconstruire PV/vent sur le site de reference;
4. si besoin, un dataset "communaute energetique" pour enrichir les profils de charge/prosumers.

## Sources retenues

### 1. Mesa Del Sol microgrid dataset

- Type: microgrid reel instrumente
- Acces: public
- Contenu utile: puissance, tension, frequence, temperature; 17 variables a resolution 10 s sur 13 mois; signaux associes a des actifs tels que batterie, PV, fuel cell, groupe, charge, echanges reseau
- Pourquoi c'est important pour la these:
  - c'est la source la plus proche de Prattico pour les **variables electriques** et la **qualite de puissance**;
  - presence d'actifs proches de la topologie Prattico, y compris la batterie et la fuel cell;
  - utile pour valider les ordres de grandeur, les regimes de fonctionnement et les variables au PCC.
- Limites:
  - la topologie exacte n'est pas celle de Prattico;
  - le dataset est volumineux et structure en fichiers mensuels;
  - il faudra faire un travail de mapping variable par variable.
- Recommandation these:
  - **priorite haute** pour la partie validation de comportement microgrid/PQ.

Voir: `sources/01_mesa_del_sol.md`

### 2. EMSx dataset

- Type: benchmark industriel public pour EMS
- Acces: public
- Contenu utile: historiques et previsions de charge et de production PV pour **70 sites industriels**, avec metadonnees associant les sites a des batteries
- Pourquoi c'est important pour la these:
  - excellent pour tester un **EMS** ou un controleur de haut niveau sous incertitude;
  - parfait pour comparer des politiques de dispatch, prevision, arbitrage et robustesse;
  - utile si la these veut montrer des tests sur un portefeuille de cas, et pas sur un seul scenario.
- Limites:
  - le focus est plus "EMS/forecasting" que "dynamique electrique";
  - pas de tension/frequence detaillees au PCC.
- Recommandation these:
  - **priorite haute** pour evaluation EMS, robustesse et generalisation multi-sites.

Voir: `sources/02_emsx.md`

### 3. SimBench

- Type: benchmark/test system ouvert
- Acces: public
- Contenu utile: grilles representatives, topologies, profils annuels load/generation/storage, cas de test reproductibles
- Pourquoi c'est important pour la these:
  - source tres defendable pour les **experiences reproductibles**;
  - utile pour tester l'impact reseau, le passage a l'echelle et des scenarios plus standards que Prattico;
  - bonne base pour comparer vos approches a la litterature.
- Limites:
  - ce n'est pas un site microgrid reel unique;
  - moins adapte a la reproduction directe de l'article Prattico que Mesa Del Sol.
- Recommandation these:
  - **priorite moyenne a haute** comme benchmark "papier these" et pour les tests systematiques.

Voir: `sources/03_simbench.md`

### 4. Energy community dataset (PV + batteries + EVs)

- Type: donnees de communaute energetique
- Acces: public
- Contenu utile: **250 foyers**, **200 PV**, **150 batteries**, **20 EV**, jeu de donnees agrege et structure
- Pourquoi c'est important pour la these:
- utile pour generer des profils residential/community plus riches que des charges artificielles;
- interessant si la these veut explorer l'effet des prosumers, de la batterie distribuee et des EVs;
  - bonne source d'enrichissement pour les scenarios multi-usagers.
- Limites:
  - pas concu d'abord pour la dynamique electrique fine au PCC;
  - moins proche de la topologie Prattico que Mesa Del Sol.
- Recommandation these:
  - **priorite moyenne** pour enrichir les profils de charge et de flexibilite.

Voir: `sources/04_energy_community.md`

### 5. NASA POWER

- Type: donnees meteorologiques et solaires officielles
- Acces: public, API officielle
- Contenu utile: irradiance, temperature, vent, pression, etc., en horaire et autres resolutions
- Pourquoi c'est important pour la these:
- permet de reconstruire un forcage exogene **coherent avec le site de Prattico**;
  - utile pour produire des profils PV/vent justifiables a Reggio Calabria;
  - excellente solution si on doit remplacer des profils "inventes" par une source officielle.
- Limites:
  - ce n'est pas un dataset de microgrid au sens strict;
  - il faut encore convertir ces signaux meteo en puissance PV/WT.
- Recommandation these:
  - **priorite haute** pour la reconstruction des profils PV/vent/temperature du site de reference.

Voir: `sources/05_nasa_power_reggio.md`

## Strategie conseillee pour la these

### Option la plus solide a court terme

Utiliser la combinaison suivante:

1. **Mesa Del Sol** pour appuyer la credibilite "microgrid reel" et les variables electriques.
2. **NASA POWER (Reggio Calabria)** pour reconstruire des entrees meteo consistantes avec Prattico.
3. **EMSx** pour montrer que l'EMS est testable sur des cas publics nombreux et varies.

Cette combinaison couvre le mieux:

- realisme microgrid;
- tracabilite publique;
- reproductibilite;
- defense academique en reunion et dans le manuscrit.

### Option "benchmark these"

Si l'objectif est de publier des experiences tres comparables et reproductibles:

1. **SimBench** pour le benchmark systematique;
2. **EMSx** pour la generalisation multi-sites;
3. **NASA POWER** pour un cas geographiquement aligne avec Prattico.

### Option "enrichissement des profils utilisateurs"

Ajouter l'**Energy community dataset** si vous voulez:

- remplacer des profils de charge trop simples;
- etudier l'effet des prosumers et des batteries distribuees;
- simuler des flexibilites residencielles/EV.

## Contenu de ce dossier

- `source_catalog.csv`: vue synthetique des sources
- `sources/`: une fiche detaillee par source retenue
- `samples/`: petits artefacts recuperes automatiquement
- `fetch_public_microgrid_data.ps1`: script pour telecharger les artefacts legers et, en option, certains fichiers publics plus lourds

## Artefacts legerement recuperables

Le script peut recuperer sans alourdir excessivement le depot:

- le `README.md` du dataset Mesa Del Sol;
- le `metadata.csv` du dataset EMSx;
- un exemple NASA POWER pour **Reggio Calabria**;
- en option, le jeu "energy community" (xlsx/docx), plus leger que les gros dumps industriels.

---

## Sources additionnelles (ajout 18 Mars 2026)

Les sources ci-dessous completent le catalogue initial avec des donnees specifiquement adaptees a Reggio Calabria et au marche italien.

### 6. PVGIS — EU Joint Research Centre

- Type: irradiance solaire satellite
- Acces: public, gratuit
- URL: https://joint-research-centre.ec.europa.eu/pvgis_en
- Outil horaire: https://joint-research-centre.ec.europa.eu/pvgis-tools/hourly-radiation_en
- TMY: https://joint-research-centre.ec.europa.eu/pvgis-tools/pvgis-typical-meteorological-year-tmy-generator_en
- Contenu: GHI, DHI, DNI, temperature, vent pour tout point geographique (base SARAH2 satellite)
- Format: CSV, JSON
- Couverture: horaire, 2005-2020
- Coordonnees Reggio Calabria: 38.11N, 15.65E
- Pourquoi c'est important:
  - source de reference EU pour l'irradiance, plus precise que NASA POWER pour l'Europe;
  - peut generer un TMY (Typical Meteorological Year) pour simulations annuelles;
  - directement exportable en CSV pour injection dans le modele Simscape.
- Recommandation these: **priorite tres haute** — remplace les profils digitalises depuis les figures.

Voir: `sources/06_pvgis.md` (a creer)

### 7. ERA5 Reanalysis — Copernicus

- Type: reanalyse meteorologique globale
- Acces: public, gratuit
- URL: https://cds.climate.copernicus.eu/datasets/reanalysis-era5-single-levels
- Contenu: vent horaire (10m, 100m), temperature, pression, radiation, global, grille ~31 km
- Format: NetCDF, GRIB
- Couverture: 1940-present, horaire
- Pourquoi c'est important:
  - meilleure source de vent horaire pour l'eolienne 60 kW;
  - resolution temporelle et spatiale superieure aux atlas statiques;
  - permet de reconstruire des profils vent realistes pour Reggio Calabria.
- Recommandation these: **priorite haute** pour le profil eolien.

### 8. Terna — Donnees de charge Italie

- Type: charge electrique reelle italienne
- Acces: public, API REST
- URL: https://dati.terna.it/en/load
- API: https://developer.terna.it/docs/read/apis_catalog
- Contenu: charge toutes les 15 min, 7 regions italiennes, depuis 2000
- Format: CSV, API REST
- Pourquoi c'est important:
  - profils de charge reels pour la Calabre / sud de l'Italie;
  - remplacement direct des profils digitalises (Figures 10b, 10c);
  - source officielle du gestionnaire de reseau italien.
- Recommandation these: **priorite haute** pour les charges AC.

### 9. GME — Marche de l'electricite italien (PUN)

- Type: prix de l'electricite day-ahead
- Acces: public
- URL: https://gme.mercatoelettrico.org/en-us/Home/Results/Electricity/MGP/Results/PUN
- Librairie Python: https://github.com/darcato/mercati-energetici (`pip install mercati-energetici`)
- Contenu: prix horaires PUN, volumes, par zone dont CALA (Calabre)
- Format: API JSON, CSV
- Pourquoi c'est important:
  - prix horaires exacts pour la zone de Calabre;
  - remplacement direct du profil tarif (Figure 13 du papier);
  - essentiel pour l'optimisation economique de l'EMS fuzzy.
- Recommandation these: **priorite haute** pour le tarif dynamique.

### 10. MathWorks — Hybrid Microgrid Model (GitHub)

- Type: modele Simulink open source
- Acces: public
- URL: https://github.com/mathworks/Modeling_a_Hybrid_Microgrid
- Contenu: microgrid hybride AC/DC avec machines tournantes, batterie, 2 fuel cells, PV, gestion DC/AC
- Format: Simulink (.slx), MATLAB
- Pourquoi c'est important:
  - architecture quasi-identique a Prattico (PV + Battery + FC + DC/AC buses);
  - peut servir de baseline pour comparer notre implementation;
  - code officiel MathWorks, donc reference solide.
- Recommandation these: **priorite moyenne** comme reference croisee.

### 11. Zenodo — Daily Energy Management Dataset

- Type: dataset EMS complet
- Acces: public
- URL: https://zenodo.org/records/15394961
- Contenu: 1 an, horaire : PV (kW), consommation (kW), prix (EUR/kWh), batterie (15 min)
- Format: CSV/Excel
- Licence: CC BY 4.0
- Pourquoi c'est important:
  - PV + consommation + prix + batterie dans un seul dataset;
  - scenarios saisonniers (3, 9, 12, 27, 50 par saison);
  - parfait pour tester l'EMS sur des cas varies.
- Recommandation these: **priorite haute** pour validation EMS multi-scenarios.

### 12. OPEM — Open PEM Fuel Cell Simulator

- Type: simulateur et donnees PEMFC
- Acces: public
- GitHub: https://github.com/ECSIM/opem
- Dataset: https://www.kaggle.com/datasets/sepandhaghighi/proton-exchange-membrane-pem-fuel-cell-dataset
- Contenu: courbes de polarisation, parametres electrochimiques, tests de performance
- Format: CSV, Python
- Pourquoi c'est important:
  - donnees de performance PEMFC pour calibrer le modele 20 kW;
  - peut remplacer les parametres [OUVERT] du papier (resistance interne, courbe V-I).
- Recommandation these: **priorite moyenne** pour enrichir le modele FC.

### 13. CALCE Battery Data

- Type: donnees de degradation batterie
- Acces: public
- URL: https://calce.umd.edu/battery-data
- Contenu: cycles charge/decharge, vieillissement calendaire, LCO/LFP/NMC
- Pourquoi c'est important:
  - modeles de degradation pour le BESS 200 kWh;
  - peut justifier les limites SOC 30-90% du papier;
  - donnees reelles pour estimer la duree de vie batterie.
- Recommandation these: **priorite basse** (enrichissement long terme).

---

## Tableau recapitulatif mis a jour

| # | Source | Type | Priorite | Composant | URL |
|---|--------|------|----------|-----------|-----|
| 1 | Mesa Del Sol | Microgrid reel | Haute | Validation PQ | Kaggle |
| 2 | EMSx | Benchmark EMS | Haute | EMS multi-sites | Public |
| 3 | SimBench | Benchmark reseau | Moyenne | Reproductibilite | Public |
| 4 | Energy Community | Prosumers | Moyenne | Profils charge | Zenodo |
| 5 | NASA POWER | Meteo | Haute | PV/vent | API |
| **6** | **PVGIS** | **Irradiance** | **Tres haute** | **PV 150 kWp** | **JRC EU** |
| **7** | **ERA5** | **Vent** | **Haute** | **WT 60 kW** | **Copernicus** |
| **8** | **Terna** | **Charge Italie** | **Haute** | **Loads AC** | **API REST** |
| **9** | **GME** | **Prix elec** | **Haute** | **Tarif EMS** | **API** |
| **10** | **MathWorks** | **Modele Simulink** | **Moyenne** | **Baseline** | **GitHub** |
| **11** | **Zenodo #15394961** | **EMS complet** | **Haute** | **Validation EMS** | **Zenodo** |
| **12** | **OPEM** | **Fuel cell** | **Moyenne** | **FC 20 kW** | **GitHub** |
| **13** | **CALCE** | **Batterie** | **Basse** | **BESS 200 kWh** | **UMD** |

---

## Candidats secondaires non integres en priorite

Pistes utiles mais non retenues comme noyau principal:

- dataset Mendeley "Prediction-Free Coordinated Dispatch of Microgrid" pour des essais de dispatch data-driven;
- datasets orientes EV/microgrid de type SOFIE si l'axe EV devient central;
- d'autres open data de charge/PV/vent comme complement, mais moins directement lies a la validation d'un microgrid hybride type Prattico.

## Decision pratique

Si Mme Fatma demande une reponse courte et defendable:

- **Source 1 a montrer**: Mesa Del Sol
- **Source 2 a montrer**: EMSx
- **Source 3 a montrer**: NASA POWER (Reggio Calabria)

Si elle demande un dossier plus "publication-ready":

- ajouter **SimBench** comme benchmark ouvert standard;
- ajouter **Energy community dataset** pour les profils utilisateurs/prosumers.
