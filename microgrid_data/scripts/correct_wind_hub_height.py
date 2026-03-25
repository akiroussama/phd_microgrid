"""
Correction vent 10m -> 60m (hauteur hub eolienne 60kW)

Loi de cisaillement (wind shear power law):
  v(h) = v(h_ref) * (h / h_ref) ^ alpha

avec:
  h_ref = 10m (hauteur mesure PVGIS/NASA)
  h = 60m (hauteur hub eolienne typique 60kW)
  alpha = 0.14 (terrain ouvert, reference: IEC 61400-1)

Source: IEC 61400-1:2019, Annex A (Wind shear)
Facteur: (60/10)^0.14 = 6^0.14 = 1.291

Entree: pvgis_hourly_2019_reggio.csv (colonne WS10m)
Sortie: pvgis_hourly_2019_reggio_wind60m.csv (colonne WS60m ajoutee)
"""

import csv
import os

# Parametres
H_REF = 10      # hauteur de mesure (m)
H_HUB = 60      # hauteur hub eolienne (m)
ALPHA = 0.14    # exposant cisaillement (terrain ouvert, IEC 61400-1)
FACTOR = (H_HUB / H_REF) ** ALPHA  # = 1.291

input_file = os.path.join(os.path.dirname(__file__), '..', 'downloads', 'pvgis_hourly_2019_reggio.csv')
output_file = os.path.join(os.path.dirname(__file__), '..', 'downloads', 'pvgis_hourly_2019_wind60m.csv')

print(f"Wind shear correction: {H_REF}m -> {H_HUB}m")
print(f"Alpha = {ALPHA} (open terrain, IEC 61400-1)")
print(f"Factor = ({H_HUB}/{H_REF})^{ALPHA} = {FACTOR:.3f}")
print()

# Lire le fichier PVGIS (skip header lines until "time,...")
rows_in = []
header_lines = []
data_started = False

with open(input_file, 'r') as f:
    for line in f:
        if line.startswith('time,'):
            data_started = True
            header = line.strip().split(',')
            continue
        if not data_started:
            header_lines.append(line)
            continue
        if line.strip() == '' or len(line.strip().split(',')) < 5:
            continue
        rows_in.append(line.strip().split(','))

print(f"Read {len(rows_in)} data rows")

# Trouver l'index de WS10m
ws_idx = header.index('WS10m')
print(f"WS10m column index: {ws_idx}")

# Creer la sortie avec WS60m
header_out = header + ['WS60m', 'T_cell']
rows_out = []

stats = {'ws10_sum': 0, 'ws60_sum': 0, 'ws10_max': 0, 'ws60_max': 0, 'count': 0}

for row in rows_in:
    ws10 = float(row[ws_idx])
    ws60 = ws10 * FACTOR

    # T_cell = T_amb + 0.035 * G (NOCT approximation)
    # Reference: IEC 61215, NOCT = 45C, T_cell = T_amb + (NOCT-20)/800 * G
    g_idx = header.index('G(i)')
    t_idx = header.index('T2m')
    g = float(row[g_idx])
    t_amb = float(row[t_idx])
    t_cell = t_amb + 0.03125 * g  # (45-20)/800 = 0.03125

    row_out = row + [f'{ws60:.2f}', f'{t_cell:.1f}']
    rows_out.append(row_out)

    stats['ws10_sum'] += ws10
    stats['ws60_sum'] += ws60
    stats['ws10_max'] = max(stats['ws10_max'], ws10)
    stats['ws60_max'] = max(stats['ws60_max'], ws60)
    stats['count'] += 1

# Ecrire
with open(output_file, 'w', newline='') as f:
    # Ecrire les header lines originales
    for hl in header_lines:
        f.write(hl)
    f.write(','.join(header_out) + '\n')
    for row in rows_out:
        f.write(','.join(row) + '\n')

n = stats['count']
print(f"\nWrote {n} rows to {os.path.basename(output_file)}")
print(f"\nStatistics:")
print(f"  WS10m: mean={stats['ws10_sum']/n:.2f} m/s, max={stats['ws10_max']:.2f} m/s")
print(f"  WS60m: mean={stats['ws60_sum']/n:.2f} m/s, max={stats['ws60_max']:.2f} m/s")
print(f"  Factor applied: x{FACTOR:.3f}")
print(f"  T_cell also computed (NOCT model, IEC 61215)")
