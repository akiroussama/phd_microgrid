# Reproduction Simscape — Prattico et al. (2025)

> Microgrid EMS avec Fuzzy Inference System — Reproduction et extension
> Candidat : Oussama AKIR | Sup'Com, Universite de Carthage
> Article : Prattico et al. (2025) Energies MDPI 18(22) 5985

## Structure

| Dossier | Contenu |
|---------|---------|
| simscape/scripts/ | 19 scripts MATLAB — construction incrementale du modele Simscape |
| data/downloads/ | 13 sources de donnees publiques (PVGIS, ARERA, profils) |
| data/plots/ | 5 graphiques de resultats (300 DPI) |
| docs/ | Presentation (37 slides), Conformity Report, IO Standards, Research Proposal |
| autoresearch/ | Pipeline agent IA pour decouverte autonome d'EMS |
| results/ | Resultats Case A vs B (CSV) |

## Resultats cles

- **84/84 tests PASS** sur 7 phases de construction incrementale
- **Case A vs B** : SOC 0-100% a 30-90%, DeltaV 5.0% a 1.7%
- **FIS Mamdani** : 60 regles, 7 cas Table 3 verifies
- **13 sources publiques** telecharges (PVGIS JRC, ARERA, IEC 61400-1)

## Prerequis

- MATLAB R2025b + Simscape Electrical
- Python 3.10+ (pour autoresearch)

## Usage

```matlab
cd simscape/scripts
build_phase_h          % Construit le modele complet
sim('prattico_simscape_phase_b', 0.5)
validate_phase_h       % 18/18 tests
```

---
*Reference : Prattico et al. (2025) DOI 10.3390/en18225985*
