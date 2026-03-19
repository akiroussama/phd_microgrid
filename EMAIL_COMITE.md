# Email au Comite — Mars 2026

> A copier-coller dans l'email. Adapter le lien Notion et le lien repo.

---

**Objet** : Avancement PhD — Reproduction Simscape Prattico + Direction recherche

Mesdames,

Suite a notre reunion du 18 Mars, voici un point d'avancement avec l'ensemble des livrables.

## Ce qui a ete fait (cloture retours Meeting #6)

| Demande | Statut | Livrable |
|---------|--------|----------|
| IEEE 1547 en profondeur | Fait | 6 slides detaillees (categories, ride-through, volt-var, droop) |
| Explication formules | Fait | Conformity Report (612 lignes, verification formule par formule) |
| Clone Simscape complet | Fait | 7 phases, 84/84 tests PASS, 19 scripts |
| Donnees publiques | Fait | 13 sources (PVGIS JRC, ARERA, IEC 61400-1) |
| Eolienne AC/DC | Fait | PMSG AC confirme (article section 3.2.3) |
| Contact Prattico | Fait | Email envoye le 11 Mars |

## Resultats principaux

- **Case A vs B** (reproduction Table 7) : SOC passe de 0-100% a 30-90%, DeltaV de 5.0% a 1.7%
- **FIS Mamdani** : 60 regles implementees, 7 cas Table 3 verifies
- **Simulation 24h** : profils dynamiques (irradiance, vent, charges, tarif)

## Documents partages

1. **Rapport d'avancement** (HTML, 7 sections) — dans le repo
2. **Presentation** (37 slides) — dans le repo
3. **Conformity Report** — verification formule par formule
4. **Donnees publiques** — 13 fichiers CSV avec sources
5. **Code Simscape** — 19 scripts MATLAB reproductibles
6. **Proposition de recherche** — Direction AutoResearch (a valider)

## Liens

- **Repo code + rapport** : [LIEN GIT A INSERER]
- **Workspace Notion** : [LIEN NOTION A INSERER]

## Decision attendue

Nous proposons la direction **AutoResearch** : decouverte autonome d'EMS optimaux via un agent IA qui explore l'espace des parametres. Le pipeline est operationnel. Votre validation est necessaire avant de lancer les premieres experiences.

Merci pour votre retour.

Respectueusement,
Oussama Akir
