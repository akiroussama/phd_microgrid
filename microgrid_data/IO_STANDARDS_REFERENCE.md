# Reference Technique — Inputs / Outputs / Standards par Composant

> Modele : Prattico et al. (2025) Energies MDPI 18(22) 5985
> Implementation : `simscape_opus_46`
> Date : 18 Mars 2026

---

## 1. PV System (150 kWp)

### Inputs

| Signal | Symbole | Unite | Plage | Source | Standard |
|--------|---------|-------|-------|--------|----------|
| Irradiance globale horizontale | G | W/m2 | 0 - 1100 | PVGIS JRC (SARAH3) | IEC 61724-1:2017 (monitoring) |
| Temperature ambiante | T_amb | C | -10 - 45 | PVGIS / NASA POWER | IEC 61215-1:2021 (qualification) |
| Temperature cellule | T_cell | C | -10 - 75 | T_amb + (NOCT-20)/800 * G | IEC 61215-2:2021 (NOCT method) |

### Outputs

| Signal | Symbole | Unite | Plage | Equation papier |
|--------|---------|-------|-------|----------------|
| Courant PV | I_pv | A | 0 - 170 | Eq. 8 (single-diode) |
| Tension PV | V_pv | V | 0 - 520 | Eq. 8 |
| Puissance PV | P_pv | W | 0 - 151800 | Eq. 9 : P = V * I |
| Tension boost sortie | V_out | V | 700 - 800 | Eq. 18 : V_out = V_in/(1-D) |
| Duty cycle MPPT | D | - | 0.05 - 0.99 | P&O algorithm |

### Equations

**Eq. 8** — Modele single-diode (IEC 61853-1) :
```
I_pv = I_ph - I_0 * (exp(q*(V + I*Rs)/(n*k*T)) - 1) - (V + I*Rs) / R_sh
```

**Eq. 9** — Puissance :
```
P_pv = V_pv * I_pv
```

**Eq. 18a** — Boost converter :
```
V_out = V_in / (1 - D)
```

### Parametres

| Parametre | Valeur | Source | Tag |
|-----------|--------|--------|-----|
| Puissance nominale | 150 kWp | Papier S3.1 | EXPLICITE |
| Nombre de modules | ~270 x 550W | Papier S3.1 | EXPLICITE |
| Cellules serie | 864 (12 modules x 72 cells) | Inference | INFERENCE |
| Strings parallele | 23 | Inference | INFERENCE |
| V_oc par cellule | 0.5 - 0.6 V | Papier Table 5 | EXPLICITE |
| I_sc densite | 30 - 40 mA/cm2 | Papier Table 5 | EXPLICITE |
| STC | 1000 W/m2, 25 C | Papier S3.2.1 | EXPLICITE |
| NOCT | 45 C | IEC 61215 standard | INFERENCE |
| Rs, Rsh, I_0, n | Defaults bloc Simscape | Non specifie papier | OUVERT |

### Standards applicables

| Standard | Titre | Ce qu'il couvre | Notre conformite |
|----------|-------|-----------------|-----------------|
| IEC 61215-1:2021 | PV module design qualification | Tests qualification, parametres electriques | Parametres STC utilises |
| IEC 61215-2:2021 | PV module design qualification — test procedures | NOCT, coefficients temperature | NOCT applique pour T_cell |
| IEC 61724-1:2017 | PV system performance monitoring | Metriques performance, PR, Yf | Non implemente (futur) |
| IEC 61853-1:2011 | PV module performance testing | Matrices I-V multi-conditions | Modele single-diode conforme |
| IEEE 1547-2018 | DER interconnection | Ride-through, reactive power | Applicable via VSC au PCC |

---

## 2. Battery System (200 kWh / 100 kW)

### Inputs

| Signal | Symbole | Unite | Plage | Source | Standard |
|--------|---------|-------|-------|--------|----------|
| Tension bus DC | V_dc | V | 700 - 800 | Mesure capteur | - |
| Consigne tension | V_dc_ref | V | 750 | PI controller | - |
| Courant batterie | I_bat | A | -200 - +200 | Bidirectionnel | IEC 62619:2022 (limites) |

### Outputs

| Signal | Symbole | Unite | Plage | Equation papier |
|--------|---------|-------|-------|----------------|
| SOC | SOC | % | 0 - 100 (EMS: 30-90) | Eq. 17 (Coulomb counting) |
| Tension terminale | V_bat | V | 400 - 576 | V_oc(SOC) - I*R_0 |
| Puissance batterie | P_bat | W | -100000 - +100000 | P = V * I |
| Duty cycle | D | - | 0.05 - 0.45 | PI output |

### Equations

**Eq. 17** — SOC (Coulomb counting) :
```
SOC(t) = SOC(0) - (1/Q_N) * integrale(I_bat dt)
```

**Eq. 18** — Convertisseur bidirectionnel :
```
Boost (decharge) : V_out = V_in / (1-D)
Buck  (charge)   : V_out = D * V_in
```

**Modele Rint** :
```
V_bat = V_OC(SOC) - I_bat * R_0
```

### Parametres

| Parametre | Valeur | Source | Tag |
|-----------|--------|--------|-----|
| Capacite energetique | 200 kWh | Papier S3.1, Table 5 | EXPLICITE |
| Puissance nominale | 100 kW | Papier Table 5 | EXPLICITE |
| Chimie | Li-ion (LiFePO4) | Papier S3.2.4 | EXPLICITE |
| SOC limites EMS | 30% - 90% | Papier S2.5 p.682 | EXPLICITE |
| SOC limites physiques | 10% - 100% | Papier Table 5 | EXPLICITE |
| DoD max | 80% | Papier Table 5 | EXPLICITE |
| Rendement aller-retour | 85-90% | Papier S4.5 p.1688 | EXPLICITE |
| V_nom pack | 512 V | Inference (128 cells x 4V) | INFERENCE |
| Capacite Ah | 400 Ah | Inference (200kWh/512V) | INFERENCE |
| R_0 | 0.04 Ohm | Non specifie papier | OUVERT |
| V_OC(SOC) | Voir battery_ocv_soc_lfp.csv | CALCE + Baronti 2013 | INFERENCE |

### Standards applicables

| Standard | Titre | Ce qu'il couvre | Notre conformite |
|----------|-------|-----------------|-----------------|
| IEC 62619:2022 | Li-ion batteries for industrial — safety | Limites courant, temperature, protection | SOC limits implementes |
| IEC 62620:2014 | Li-ion batteries — performance | Cycles, capacite, endurance | Non teste (futur) |
| IEEE 2030.2.1-2019 | Guide for DESS (storage) | Design, integration, operation | Architecture conforme |
| UL 1973 | Batteries for stationary applications | Safety testing | Non applicable (simulation) |

---

## 3. Wind Turbine (60 kW)

### Inputs

| Signal | Symbole | Unite | Plage | Source | Standard |
|--------|---------|-------|-------|--------|----------|
| Vitesse vent (hub) | v | m/s | 0 - 25 | ERA5 ou PVGIS + correction cisaillement | IEC 61400-1:2019 |
| Densite air | rho | kg/m3 | 1.225 | Standard ISA | IEC 61400-12-1:2017 |
| Angle de pale | beta | deg | 0 (fixe) | Non controle | - |

### Outputs

| Signal | Symbole | Unite | Plage | Equation papier |
|--------|---------|-------|-------|----------------|
| Puissance aerodynamique | P_wind | W | 0 - 60000 | Eq. 10 |
| Couple mecanique | T_m | Nm | 0 - variable | Eq. 11 |
| Courant injecte DC | I_wt | A | 0 - 80 | Average model: I = P/V_dc |

### Equations

**Eq. 10** — Puissance aerodynamique (Betz) :
```
P_wind = 0.5 * rho * A * v^3 * Cp(lambda, beta)
```

**Eq. 11** — Dynamique rotor :
```
J * d(omega)/dt = T_m - T_e - B * omega
```

**Correction cisaillement** (IEC 61400-1, Annex A) :
```
v(h) = v(h_ref) * (h / h_ref)^alpha
alpha = 0.14 (terrain ouvert)
```

### Parametres

| Parametre | Valeur | Source | Tag |
|-----------|--------|--------|-----|
| Puissance nominale | 60 kW | Papier S3.1, Table 5 | EXPLICITE |
| V cut-in | 3-4 m/s | Papier S3.1, Table 5 | EXPLICITE |
| V rated | 12 m/s | Papier S3.1, Table 5 | EXPLICITE |
| V cut-out | 25 m/s | Papier S3.1, Table 5 | EXPLICITE |
| Cp max | 0.4 - 0.5 | Papier Table 5 | EXPLICITE |
| Generateur | PMSM | Papier S3.2.2 | EXPLICITE |
| Filtre DC rectifieur | C=1uF, R=100 Ohm | Papier S3.2.2 | EXPLICITE |
| Rayon rotor | 6.3 m | Calcule depuis P_nom | INFERENCE |
| Surface balayee | 126 m2 | pi * R^2 | INFERENCE |
| Alpha cisaillement | 0.14 | IEC 61400-1 terrain ouvert | INFERENCE |
| Hauteur hub | 60 m | Typique 60kW | INFERENCE |
| J, B (inertie, damping) | Non specifie | Papier S3.2.2 | OUVERT |

### Standards applicables

| Standard | Titre | Ce qu'il couvre | Notre conformite |
|----------|-------|-----------------|-----------------|
| IEC 61400-1:2019 | WT design requirements | Classes vent, cisaillement, charges | Alpha=0.14 applique |
| IEC 61400-12-1:2017 | WT power performance testing | Courbe puissance, Cp, AEP | Cp=0.45 utilise |
| IEC 61400-21-1:2019 | WT grid connection — PQ | Harmoniques, flicker, ride-through | Non applicable (average model) |
| IEEE 1547-2018 | DER interconnection | Ride-through WT | Via VSC au PCC |

---

## 4. Fuel Cell PEMFC (20 kW)

### Inputs

| Signal | Symbole | Unite | Plage | Source | Standard |
|--------|---------|-------|-------|--------|----------|
| Signal activation EMS | FC_connection | - | {0, 1} | EMS fuzzy | - |
| Pression H2 | p_H2 | atm | 1 - 3 | Non specifie | IEC 62282-3-100 |
| Pression O2 | p_O2 | atm | 0.21 (air) | Standard | IEC 62282-3-100 |
| Temperature stack | T | K | 333 (60C) | Typique PEMFC | IEC 62282-3-100 |

### Outputs

| Signal | Symbole | Unite | Plage | Equation papier |
|--------|---------|-------|-------|----------------|
| Tension stack | V_FC | V | 24 - 50 | Eq. 16 |
| Courant stack | I_FC | A | 0 - 417 | Determine par charge |
| Puissance nette | P_FC | W | 0 - 20000 | P = V * I |
| Courant injecte DC | I_fc_dc | A | 0 - 27 | Average model: I = P/V_dc |

### Equations

**Eq. 12** — Anode :
```
H2 -> 2H+ + 2e-
```

**Eq. 13** — Cathode :
```
0.5*O2 + 2H+ + 2e- -> H2O
```

**Eq. 14** — Reaction globale :
```
H2 + 0.5*O2 -> H2O + energie
```

**Eq. 15** — Tension Nernst (OCV) :
```
E = E_0 + (R*T)/(2*F) * ln(p_H2 * p_O2^0.5 / p_H2O)
```

**Eq. 16** — Tension terminale :
```
V_FC = N * (E - V_act - V_ohm - V_conc)
```

### Parametres

| Parametre | Valeur | Source | Tag |
|-----------|--------|--------|-----|
| Puissance nominale | 20 kW | Papier S3.1, Table 5 | EXPLICITE |
| Tension stack | 48-50 V | Papier S3.2.3 | EXPLICITE |
| Type | PEMFC | Papier S3.2.3 | EXPLICITE |
| Resistance serie | 10^-3 Ohm | Papier S3.2.3 (stabilite) | EXPLICITE |
| Nombre de cellules | ~50 | Inference (50V / 1V/cell) | INFERENCE |
| E_0 (potentiel standard) | 1.23 V | Thermodynamique | REFERENCE |
| R (constante gaz) | 8.314 J/(mol*K) | Physique | REFERENCE |
| F (Faraday) | 96485 C/mol | Physique | REFERENCE |
| Ramp-rate limits | Non specifie | Papier S3.2.3 mentionne | OUVERT |
| Warm-up time | Non specifie | Papier S3.2.3 mentionne | OUVERT |
| Courbe V-I | Voir pemfc_polarization_20kw.csv | OPEM + inference | INFERENCE |

### Standards applicables

| Standard | Titre | Ce qu'il couvre | Notre conformite |
|----------|-------|-----------------|-----------------|
| IEC 62282-3-100:2019 | FC power systems — stationary | Safety, performance, installation | Parametres conformes |
| IEC 62282-3-200:2015 | FC power systems — performance | Tests performance, rendement | Courbe V-I disponible |
| ISO 14687:2019 | Qualite hydrogene | Purete H2 pour PEMFC | Non applicable (simulation) |

---

## 5. DC Bus (750 V)

### Inputs/Outputs (noeud central)

| Signal | Direction | Symbole | Unite | Plage |
|--------|-----------|---------|-------|-------|
| Courant PV | Entrant | I_pv | A | 0 - 200 |
| Courant batterie | Bidirectionnel | I_bat | A | -200 - +200 |
| Courant WT | Entrant | I_wt | A | 0 - 80 |
| Courant FC | Entrant | I_fc | A | 0 - 27 |
| Courant DC load | Sortant | I_dc_load | A | 0 - 20 |
| Courant VSC | Sortant | I_vsc | A | 0 - 200 |
| Tension bus | Mesure | V_dc | V | 675 - 825 |
| DeltaV | Calcule | DeltaV_dc | % | -10 - +10 |

### Equation de conservation (Eq. 5 adaptee) :

```
C * dV_dc/dt = I_pv + I_wt + I_fc + I_bat - I_dc_load - I_vsc - V_dc/R_par
```

### Parametres

| Parametre | Valeur | Source | Tag |
|-----------|--------|--------|-----|
| Tension nominale | 750 V | Papier S3.1 | EXPLICITE |
| Capacite bus | 4.7 mF | Inference (typique 150kW) | INFERENCE |
| Resistance parasite | 10 kOhm | Stabilite numerique | INFERENCE |
| Tension initiale | 750 V | = nominale | INFERENCE |

### Standards applicables

| Standard | Titre | Ce qu'il couvre | Notre conformite |
|----------|-------|-----------------|-----------------|
| IEC 61000-2-2:2024 | Compatibility levels — LV | Limites tension, harmoniques | DeltaV < +/-10% |
| EN 50160:2010 | Voltage characteristics — public | Qualite tension distribution | DeltaV_dc mesure |
| IEEE 1547-2018 S5.2 | Voltage regulation | DER voltage limits | +/-5% en regime permanent |

---

## 6. Charges

### 6.1 DC Load (15 kW)

| Signal | Direction | Unite | Plage | Standard |
|--------|-----------|-------|-------|----------|
| Profil puissance | Input | kW | 1.5 - 15 | - |
| Resistance variable | Calcule | Ohm | 37.5 - 375k | R = V^2/P |
| Courant | Sortant du bus | A | 2 - 20 | - |

### 6.2 AC Residential (50 kW, PF=1)

| Signal | Direction | Unite | Plage | Standard |
|--------|-----------|-------|-------|----------|
| Puissance active | Input | kW | 10 - 50 | EN 50160 |
| Puissance reactive | Input | kvar | ~0 | PF = 1.0 |
| Tension | AC bus | V | 230 V phase | IEC 61000-3-2 |
| Profil | Timeseries | kW | 24h | Figure 10b |

### 6.3 AC Commercial (45 kW, PF=0.9)

| Signal | Direction | Unite | Plage | Standard |
|--------|-----------|-------|-------|----------|
| Puissance active | Input | kW | 5 - 45 | EN 50160 |
| Puissance reactive | Input | kvar | 2.4 - 21.8 | Q = P*tan(acos(0.9)) |
| Facteur de puissance | Parametre | - | 0.9 | IEC 61000-3-2 (>0.95 requis) |
| Tension | AC bus | V | 400 V L-L | EN 50160 |
| Profil | Timeseries | kW | 24h | Figure 10c |

### Standards charges

| Standard | Titre | Ce qu'il couvre |
|----------|-------|-----------------|
| IEC 61000-3-2:2018 | Harmonic current emissions | Limites harmoniques equipements |
| IEC 61000-3-12:2011 | Harmonic currents >16A | Equipements industriels |
| EN 50160:2010 | Voltage characteristics | Qualite tension au point de livraison |

---

## 7. VSC / PCC (150 kVA)

### Inputs

| Signal | Symbole | Unite | Plage | Source | Standard |
|--------|---------|-------|-------|--------|----------|
| Tension DC bus | V_dc | V | 675 - 825 | Mesure | - |
| Consigne P | P_ref_AC | kW | 0 - 150 | EMS | IEEE 1547 |
| Consigne Q | Q_ref | kvar | -Q_max - +Q_max | EMS | IEEE 1547 S5.3 |
| Grid connection cmd | Grid_conn | {0,1} | - | EMS | IEEE 1547 S4.10 |
| Tension grid | V_grid | V | 400 V L-L | Grid source | EN 50549 |
| Frequence grid | f_grid | Hz | 49.8 - 50.2 | PLL | ENTSO-E |

### Outputs

| Signal | Symbole | Unite | Plage | Equation papier |
|--------|---------|-------|-------|----------------|
| Puissance active | P | W | -150k - +150k | Eq. 6 |
| Puissance reactive | Q | var | -Q_max - +Q_max | Eq. 7 |
| Courant DC | I_vsc | A | -200 - +200 | I = P/V_dc |
| THD_V | THD_V | % | 0 - 8 | Eq. 3 |
| TDD | TDD | % | 0 - 8 | Eq. 4 |

### Equations

**Eq. 6** — Puissance active (repere dq) :
```
P = (3/2) * (v_d * i_d + v_q * i_q)
```

**Eq. 7** — Puissance reactive :
```
Q = (3/2) * (v_q * i_d - v_d * i_q)
```

### Parametres

| Parametre | Valeur | Source | Tag |
|-----------|--------|--------|-----|
| Puissance apparente | 150 kVA | Papier S3.1 | EXPLICITE |
| Tension AC | 400 V L-L, 50 Hz | Papier S2.2 | EXPLICITE |
| Tension DC | 750 V | Papier S3.1 | EXPLICITE |
| Filtre LC | L, C non specifies | Papier S3.2.5 mentionne | OUVERT |
| Mode connecte | Grid-following (PLL) | Papier S3.3 | EXPLICITE |
| Mode ilote | Grid-forming (V/f) | Papier S3.3 | EXPLICITE |
| Duty cycle max | 0.99 | Papier S2.5 p.714 | EXPLICITE |
| PWM | Sinusoidal PWM, dq frame | Papier S3.2.5 | EXPLICITE |
| PI gains | Non specifies | Papier S3.2.5 | OUVERT |

### Standards applicables

| Standard | Titre | Ce qu'il couvre | Notre conformite |
|----------|-------|-----------------|-----------------|
| IEEE 1547-2018 | DER interconnection | Ride-through, reactive power, islanding | Cat II justifiee |
| IEEE 1547.1-2020 | Conformance test procedures | Tests de certification DER | Non teste |
| EN 50549-1:2019 | DER connection LV (EU 50Hz) | Equivalent EU de IEEE 1547 | Applicable (Italie) |
| EN 50549-2:2019 | DER connection MV (EU 50Hz) | DER > 1 MW | Non applicable |
| IEC 62898-1:2017 | Microgrids — guidelines | Planning, design, operation | Architecture conforme |
| IEC 62898-2:2018 | Microgrids — operation | Grid-connected/islanded modes | Modes implementes |

---

## 8. EMS Fuzzy (Superviseur)

### Inputs

| Signal | Symbole | Unite | Plage | Source | Standard |
|--------|---------|-------|-------|--------|----------|
| Desequilibre puissance | DeltaP | kW | -150 - +150 | Calcule | - |
| Etat de charge | SOC | % | 30 - 90 | Batterie | IEC 62619 |
| Tarif electricite | Tariff | EUR/kWh | 0.05 - 0.15 | GME/ARERA | - |

### Outputs

| Signal | Symbole | Unite | Plage | Type |
|--------|---------|-------|-------|------|
| Consigne batterie | P_ref_batt | kW | -100 - +100 | Continu (Mamdani) |
| Consigne AC | P_ref_AC | kW | 0 - 150 | Continu (Mamdani) |
| Connexion reseau | Grid_conn | {0, 1} | - | Binaire (seuil 0.5) |
| Activation FC | FC_conn | {0, 1} | - | Binaire (seuil 0.5) |

### Equation cle

**DeltaP** (S2.4, Figure 2) :
```
DeltaP = P_PV + P_WT - (P_DC_load + P_AC_res + P_AC_com)
```
Note : FC et Battery sont EXCLUS de DeltaP (ce sont les sorties de l'EMS, pas les entrees).

### Parametres FIS

| Parametre | Valeur | Source | Tag |
|-----------|--------|--------|-----|
| Type | Mamdani | Papier S2.5 | EXPLICITE |
| Inference | Max-min | Papier S2.5 p.702 | EXPLICITE |
| Defuzzification | Centroide | Papier S2.5 p.703 | EXPLICITE |
| MFs | Triangulaires | Papier S2.5 p.670 | EXPLICITE |
| Regles | ~80 (5x4x3=60 dans notre impl.) | Papier S2.6 | EXPLICITE |
| C-rate batterie | +/- 5 kW max | Papier S2.5 p.707 | EXPLICITE |
| Temps inference | 5-10 us/step | Papier S2.9 p.428 | EXPLICITE |

### Standards applicables

| Standard | Titre | Ce qu'il couvre |
|----------|-------|-----------------|
| IEEE 2030.7-2017 | Microgrid controller specification | Fonctions EMS, modes operation |
| IEEE 2030.8-2018 | Microgrid controller testing | Procedures de test |
| IEC 62898-1:2017 | Microgrids planning/design | Architecture EMS |

---

## 9. Power Quality Monitoring

### Indicateurs mesures

| Indicateur | Symbole | Equation | Seuil | Standard | Notre etat |
|-----------|---------|----------|-------|----------|-----------|
| Deviation tension | DeltaV | Eq. 1 : (V-Vnom)/Vnom*100 | +/-10% | IEC 61000-2-2 | Mesure (DC) |
| Deviation frequence | Deltaf | Eq. 2 : f - f_nom | +/-0.2 Hz | ENTSO-E | Non mesurable (pas de bus AC) |
| THD tension | THD_V | Eq. 3 : sqrt(sum V_h^2)/V_1 | 5% | IEC 61000-3-2, IEEE 519 | Non mesurable |
| Distortion demande | TDD | Eq. 4 : sqrt(sum I_h^2)/I_L | 5-8% | IEEE 519 | Non mesurable |
| Facteur puissance | PF | P/sqrt(P^2+Q^2) | >0.95 | IEC 61000-3-2 | Non mesurable |
| Continuite | sags/swells | - | IEEE 1159 | IEEE 1159 | Non mesurable |

### Parametres FFT (S2.2)

| Parametre | Valeur | Source | Tag |
|-----------|--------|--------|-----|
| Taux echantillonnage | 10 kHz | Papier S2.2 p.557 | EXPLICITE |
| Filtre anti-aliasing | Butterworth 4eme ordre, fc=2.5 kHz | Papier S2.2 p.558 | EXPLICITE |
| Fenetre | Hanning, 200 ms (10 cycles) | Papier S2.2 p.560 | EXPLICITE |
| Overlap | 50% | Papier S2.2 p.561 | EXPLICITE |
| Echantillons/fenetre | 5000 (papier) vs 2000 (calcule) | Papier S2.2 p.560 | INCOHERENCE |

### Standards PQ

| Standard | Titre | Ce qu'il couvre |
|----------|-------|-----------------|
| IEC 61000-4-7:2002+A1:2008 | Harmonics measurement | Methode FFT, fenetrage |
| IEC 61000-4-30:2015 | PQ measurement methods | Classe A/S, agregation |
| IEEE 519-2022 | Harmonic control | Limites THD, TDD |
| IEEE 1159-2019 | PQ monitoring | Sags, swells, transients |
| EN 50160:2010 | Voltage characteristics | Limites tension, frequence |
| ENTSO-E Continental Europe | Frequency quality | +/-0.2 Hz normal operation |

---

## 10. Tableau recapitulatif — Donnees disponibles vs requises

| Composant | Donnees disponibles | Format | Donnees manquantes |
|-----------|-------------------|--------|-------------------|
| PV | PVGIS horaire 2019 + TMY (G, T, WS) | CSV 8760 lignes | Courbe I-V module specifique |
| Batterie | OCV(SOC) LFP 21 points | CSV | Courbe R_0(SOC, T) |
| WT | Vent 60m corrige (IEC 61400-1) | CSV 8760 lignes | Courbe Cp(lambda, beta) |
| FC | Courbe polarisation V-I 17 points | CSV | Dynamique transitoire |
| Charges | 3 profils calibres 30 jours x 24h | CSV 720 lignes | Mesures reelles Terna |
| Tarif | ARERA F1/F2/F3 30 jours x 24h | CSV 720 lignes | Prix spot GME reels |
| PQ | - | - | Signaux AC 3-phase au PCC |

---

## 11. Carte des standards par couche

```
COUCHE PHYSIQUE (composants)
  PV:      IEC 61215, IEC 61853, IEC 61724
  Battery: IEC 62619, IEC 62620, IEEE 2030.2.1
  WT:      IEC 61400-1, IEC 61400-12-1, IEC 61400-21-1
  FC:      IEC 62282-3-100, IEC 62282-3-200, ISO 14687

COUCHE CONVERSION (convertisseurs)
  DC/DC:   Eq. 18 (boost/buck)
  VSC:     IEEE 1547-2018, EN 50549-1:2019

COUCHE RESEAU (PCC)
  PQ:      IEC 61000-4-7, IEEE 519-2022, IEEE 1159-2019, EN 50160
  Grid:    ENTSO-E, EN 50549

COUCHE SUPERVISION (EMS)
  EMS:     IEEE 2030.7-2017, IEEE 2030.8-2018, IEC 62898-1/2

COUCHE SECURITE (CBF — futur PhD)
  Safety:  IEEE 1547-2018 Cat II (ride-through, reactive)
  CBF:     Anticipation proactive des violations IEEE 1547
```
