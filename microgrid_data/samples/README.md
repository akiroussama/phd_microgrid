# Samples

Ce dossier contient des artefacts legers deja recuperes pour rendre la recherche exploitable immediatement sans telecharger plusieurs centaines de Mo ou plusieurs Go.

## Fichiers presents

- `mesa_del_sol_README.md`
  - README officiel du dataset Mesa Del Sol
  - utile pour comprendre les variables, la resolution et la structure mensuelle

- `emsx_metadata.csv`
  - metadonnees du benchmark EMSx
  - utile pour choisir des sites et connaitre les tailles batterie/puissance

- `nasa_power_reggio_calabria_june_2025.csv`
  - exemple officiel NASA POWER pour Reggio Calabria
  - utile pour reconstruire les entrees PV/vent/temperature autour du site Prattico

## Regeneration

Pour regenarer ces fichiers:

```powershell
powershell -ExecutionPolicy Bypass -File microgrid_data\fetch_public_microgrid_data.ps1
```

Pour ajouter aussi les fichiers publics du dataset "energy community":

```powershell
powershell -ExecutionPolicy Bypass -File microgrid_data\fetch_public_microgrid_data.ps1 -IncludeEnergyCommunityFiles
```
