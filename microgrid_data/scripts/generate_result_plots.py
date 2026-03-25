"""
Generate PhD-quality result plots from 24h simulation data.
Creates publication-ready figures for the presentation.

Outputs:
  - fig_vdc_24h.png       : DC bus voltage over 24h
  - fig_soc_24h.png       : Battery SOC over 24h
  - fig_power_balance.png : Generation vs Load power balance
  - fig_deltap_24h.png    : Power imbalance + EMS decisions
  - fig_all_results.png   : Combined 2x3 panel (main figure)
"""

import csv
import os
import sys

# Check if matplotlib is available
try:
    import matplotlib
    matplotlib.use('Agg')  # Non-interactive backend
    import matplotlib.pyplot as plt
    import matplotlib.ticker as ticker
    HAS_MPL = True
except ImportError:
    HAS_MPL = False
    print("matplotlib not available. Install with: pip install matplotlib")
    print("Generating ASCII summary instead.")

data_dir = os.path.join(os.path.dirname(__file__), '..', 'downloads')
output_dir = os.path.join(os.path.dirname(__file__), '..', 'plots')
os.makedirs(output_dir, exist_ok=True)

# Load simulation results
csv_file = os.path.join(data_dir, 'sim_results_24h.csv')
if not os.path.exists(csv_file):
    print(f"ERROR: {csv_file} not found. Run the MATLAB simulation first.")
    sys.exit(1)

print(f"Loading {csv_file}...")
t, vdc, ppv, pwt, pfc, soc, dp, pdcl, pac, tar = [], [], [], [], [], [], [], [], [], []

with open(csv_file, 'r') as f:
    reader = csv.reader(f)
    for row in reader:
        if len(row) >= 10 and row[0] != 'time_h':
            try:
                t.append(float(row[0]))
                vdc.append(float(row[1]))
                ppv.append(float(row[2]))
                pwt.append(float(row[3]))
                pfc.append(float(row[4]))
                soc.append(float(row[5]))
                dp.append(float(row[6]))
                pdcl.append(float(row[7]))
                pac.append(float(row[8]))
                tar.append(float(row[9]))
            except ValueError:
                continue

print(f"Loaded {len(t)} data points")

# Convert simulation time (s) to hours for x-axis
hours = [ti for ti in t]  # 1s = 1h in compressed time

if not HAS_MPL:
    # ASCII summary
    print(f"\n=== 24h SIMULATION RESULTS ===")
    print(f"Vdc: mean={sum(vdc)/len(vdc):.1f}V, min={min(vdc):.1f}V, max={max(vdc):.1f}V")
    print(f"SOC: start={soc[0]:.1f}%, min={min(soc):.1f}%, max={max(soc):.1f}%, end={soc[-1]:.1f}%")
    print(f"PV:  peak={max(ppv):.1f}kW at h={hours[ppv.index(max(ppv))]:.0f}")
    print(f"WT:  peak={max(pwt):.1f}kW")
    print(f"FC:  constant={pfc[0]:.1f}kW")
    print(f"Load DC:  peak={max(pdcl):.1f}kW")
    print(f"Load AC:  peak={max(pac):.1f}kW")
    print(f"DeltaP: min={min(dp):.1f}kW, max={max(dp):.1f}kW")
    sys.exit(0)

# === PUBLICATION-QUALITY STYLE ===
plt.rcParams.update({
    'font.family': 'serif',
    'font.size': 10,
    'axes.labelsize': 11,
    'axes.titlesize': 12,
    'legend.fontsize': 9,
    'xtick.labelsize': 9,
    'ytick.labelsize': 9,
    'figure.dpi': 150,
    'savefig.dpi': 300,
    'savefig.bbox': 'tight',
    'axes.grid': True,
    'grid.alpha': 0.3,
})

# === FIGURE 1: Combined 2x3 panel ===
fig, axes = plt.subplots(3, 2, figsize=(14, 10))
fig.suptitle('Microgrid Prattico - Simulation 24h (Reggio Calabria, Juin)', fontsize=14, fontweight='bold')

# Panel 1: Vdc
ax = axes[0, 0]
ax.plot(hours, vdc, 'b-', linewidth=1.5)
ax.axhline(y=750, color='k', linestyle='--', alpha=0.5, label='Nominal 750V')
ax.axhline(y=712.5, color='r', linestyle='--', alpha=0.3, label='+/-5%')
ax.axhline(y=787.5, color='r', linestyle='--', alpha=0.3)
ax.set_ylabel('Tension [V]')
ax.set_title('(a) Tension DC Bus')
ax.legend(loc='upper right', fontsize=8)
ax.set_xlim(0, 24)

# Panel 2: SOC
ax = axes[0, 1]
ax.plot(hours, soc, 'g-', linewidth=1.5)
ax.axhline(y=30, color='r', linestyle='--', alpha=0.5, label='SOC min (EMS)')
ax.axhline(y=90, color='r', linestyle='--', alpha=0.5, label='SOC max (EMS)')
ax.fill_between(hours, 30, 90, alpha=0.05, color='green')
ax.set_ylabel('SOC [%]')
ax.set_title('(b) Etat de charge batterie')
ax.legend(loc='upper right', fontsize=8)
ax.set_xlim(0, 24)

# Panel 3: Generation
ax = axes[1, 0]
ax.plot(hours, ppv, color='#f59e0b', linewidth=1.5, label='PV')
ax.plot(hours, pwt, color='#06b6d4', linewidth=1.5, label='WT')
ax.plot(hours, pfc, color='#8b5cf6', linewidth=1.5, label='FC')
p_gen = [ppv[i] + pwt[i] + pfc[i] for i in range(len(t))]
ax.plot(hours, p_gen, 'k-', linewidth=0.8, alpha=0.5, label='Total gen.')
ax.set_ylabel('Puissance [kW]')
ax.set_title('(c) Production renouvelable')
ax.legend(loc='upper left', fontsize=8)
ax.set_xlim(0, 24)

# Panel 4: Loads
ax = axes[1, 1]
ax.plot(hours, pdcl, color='#ef4444', linewidth=1.5, label='DC Load')
ax.plot(hours, pac, color='#ec4899', linewidth=1.5, label='AC Loads')
p_load = [pdcl[i] + pac[i] for i in range(len(t))]
ax.plot(hours, p_load, 'k-', linewidth=0.8, alpha=0.5, label='Total load')
ax.set_ylabel('Puissance [kW]')
ax.set_title('(d) Demande de charge')
ax.legend(loc='upper left', fontsize=8)
ax.set_xlim(0, 24)

# Panel 5: DeltaP
ax = axes[2, 0]
ax.fill_between(hours, dp, 0, where=[d > 0 for d in dp], color='green', alpha=0.3, label='Surplus')
ax.fill_between(hours, dp, 0, where=[d < 0 for d in dp], color='red', alpha=0.3, label='Deficit')
ax.plot(hours, dp, 'b-', linewidth=1)
ax.axhline(y=0, color='k', linewidth=0.5)
ax.set_ylabel('DeltaP [kW]')
ax.set_xlabel('Heure [h]')
ax.set_title('(e) Desequilibre de puissance (gen - load)')
ax.legend(loc='upper left', fontsize=8)
ax.set_xlim(0, 24)

# Panel 6: Tariff
ax = axes[2, 1]
ax.step(hours, tar, 'k-', linewidth=1.5, where='post')
ax.fill_between(hours, tar, alpha=0.2, step='post', color='orange')
ax.set_ylabel('Prix [EUR/kWh]')
ax.set_xlabel('Heure [h]')
ax.set_title('(f) Tarif dynamique electricite')
ax.set_xlim(0, 24)
ax.set_ylim(0, 0.18)

plt.tight_layout()
output_file = os.path.join(output_dir, 'fig_all_results_24h.png')
plt.savefig(output_file)
print(f"Saved: {output_file}")

# === FIGURE 2: Power balance comparison ===
fig2, ax2 = plt.subplots(figsize=(12, 5))
ax2.plot(hours, p_gen, 'b-', linewidth=1.5, label='Generation (PV+WT+FC)')
ax2.plot(hours, p_load, 'r-', linewidth=1.5, label='Load (DC+AC)')
ax2.fill_between(hours, p_gen, p_load, where=[g > l for g, l in zip(p_gen, p_load)],
                  color='green', alpha=0.2, label='Surplus -> charge batterie')
ax2.fill_between(hours, p_gen, p_load, where=[g < l for g, l in zip(p_gen, p_load)],
                  color='red', alpha=0.2, label='Deficit -> decharge batterie')
ax2.set_xlabel('Heure [h]')
ax2.set_ylabel('Puissance [kW]')
ax2.set_title('Bilan de puissance - Microgrid Prattico (24h, Reggio Calabria, Juin)')
ax2.legend(loc='upper left')
ax2.set_xlim(0, 24)
ax2.axhline(y=0, color='k', linewidth=0.5)

output_file2 = os.path.join(output_dir, 'fig_power_balance_24h.png')
plt.savefig(output_file2)
print(f"Saved: {output_file2}")

print(f"\n=== ALL PLOTS GENERATED ===")
print(f"Output directory: {output_dir}")
