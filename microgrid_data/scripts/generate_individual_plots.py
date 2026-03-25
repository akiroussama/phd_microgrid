"""Generate 3 individual high-quality plots for dedicated slides."""

import csv, os, sys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

data_dir = os.path.join(os.path.dirname(__file__), '..', 'downloads')
output_dir = os.path.join(os.path.dirname(__file__), '..', 'plots')

csv_file = os.path.join(data_dir, 'sim_results_24h.csv')
t, vdc, ppv, pwt, pfc, soc, dp, pdcl, pac, tar = [],[],[],[],[],[],[],[],[],[]

with open(csv_file, 'r') as f:
    for row in csv.reader(f):
        if len(row) >= 10 and row[0] != 'time_h':
            try:
                t.append(float(row[0])); vdc.append(float(row[1]))
                ppv.append(float(row[2])); pwt.append(float(row[3]))
                pfc.append(float(row[4])); soc.append(float(row[5]))
                dp.append(float(row[6])); pdcl.append(float(row[7]))
                pac.append(float(row[8])); tar.append(float(row[9]))
            except: continue

plt.rcParams.update({
    'font.family': 'serif', 'font.size': 13,
    'axes.labelsize': 14, 'axes.titlesize': 16,
    'legend.fontsize': 11, 'figure.dpi': 150, 'savefig.dpi': 300,
    'savefig.bbox': 'tight', 'axes.grid': True, 'grid.alpha': 0.3,
})

hours = [f'{int(h)}h' for h in range(0, 25, 3)]
xticks = list(range(0, 25, 3))

# === PLOT 1: SOC Battery ===
fig, ax = plt.subplots(figsize=(14, 6))
ax.plot(t, soc, color='#10b981', linewidth=2.5, label='SOC batterie')
ax.axhline(y=90, color='#ef4444', linestyle='--', linewidth=1.5, label='SOC max EMS (90%)')
ax.axhline(y=30, color='#ef4444', linestyle='--', linewidth=1.5, label='SOC min EMS (30%)')
ax.axhline(y=60, color='#94a3b8', linestyle=':', linewidth=1, label='SOC initial (60%)')
ax.fill_between(t, 30, 90, alpha=0.06, color='green')

ax.annotate('Charge\n(surplus PV)', xy=(10, 85), fontsize=12, ha='center',
            color='#10b981', fontweight='bold')
ax.annotate('Décharge\n(déficit soir)', xy=(20, 40), fontsize=12, ha='center',
            color='#ef4444', fontweight='bold')
ax.annotate('SOC atteint\nle plafond 90%', xy=(12, 90), xytext=(14, 95),
            fontsize=10, arrowprops=dict(arrowstyle='->', color='#ef4444'),
            color='#ef4444')
ax.annotate('SOC atteint\nle plancher 30%', xy=(22, 30), xytext=(19, 22),
            fontsize=10, arrowprops=dict(arrowstyle='->', color='#ef4444'),
            color='#ef4444')

ax.set_xlabel('Heure de la journée')
ax.set_ylabel('État de charge (%)')
ax.set_title('Cycle journalier de la batterie (200 kWh) — Reggio Calabria, juin')
ax.set_xlim(0, 24); ax.set_ylim(15, 100)
ax.set_xticks(xticks); ax.set_xticklabels(hours)
ax.legend(loc='center right')
plt.savefig(os.path.join(output_dir, 'fig_soc_detailed.png'))
print("Saved: fig_soc_detailed.png")

# === PLOT 2: Power Balance ===
fig, ax = plt.subplots(figsize=(14, 6))
p_gen = [ppv[i] + pwt[i] + pfc[i] for i in range(len(t))]
p_load = [pdcl[i] + pac[i] for i in range(len(t))]

ax.plot(t, p_gen, color='#2563eb', linewidth=2.5, label='Génération (PV + WT + FC)')
ax.plot(t, p_load, color='#ef4444', linewidth=2.5, label='Charge (DC + AC)')
ax.fill_between(t, p_gen, p_load,
    where=[g > l for g, l in zip(p_gen, p_load)],
    color='#10b981', alpha=0.25, label='Surplus → batterie charge')
ax.fill_between(t, p_gen, p_load,
    where=[g < l for g, l in zip(p_gen, p_load)],
    color='#ef4444', alpha=0.25, label='Déficit → batterie décharge')
ax.axhline(y=0, color='k', linewidth=0.5)

ax.annotate('PV domine\n(surplus)', xy=(10, 160), fontsize=12,
            ha='center', color='#10b981', fontweight='bold')
ax.annotate('Charges dominent\n(déficit)', xy=(20, 80), fontsize=12,
            ha='center', color='#ef4444', fontweight='bold')
ax.annotate('Point de\ncroisement', xy=(15.5, 100), xytext=(17, 140),
            fontsize=10, arrowprops=dict(arrowstyle='->', color='k'),
            fontweight='bold')

ax.set_xlabel('Heure de la journée')
ax.set_ylabel('Puissance (kW)')
ax.set_title('Bilan de puissance — Génération vs Charge (24h)')
ax.set_xlim(0, 24); ax.set_ylim(-10, 220)
ax.set_xticks(xticks); ax.set_xticklabels(hours)
ax.legend(loc='upper left')
plt.savefig(os.path.join(output_dir, 'fig_power_balance_detailed.png'))
print("Saved: fig_power_balance_detailed.png")

# === PLOT 3: Case A vs B (SOC comparison) ===
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6), sharey=True)

# Case A: simulate SOC without limits (0-100%)
soc_a = [60.0]
gain = 5e-4
for i in range(1, len(t)):
    dt_sim = t[i] - t[i-1]
    delta = dp[i] * 1e3 * gain * dt_sim
    soc_a.append(max(0, min(100, soc_a[-1] + delta)))

ax1.plot(t, soc_a, color='#ef4444', linewidth=2.5)
ax1.axhline(y=100, color='k', linestyle='--', linewidth=1, alpha=0.3)
ax1.axhline(y=0, color='k', linestyle='--', linewidth=1, alpha=0.3)
ax1.fill_between(t, 0, 100, alpha=0.04, color='red')
ax1.set_title('Case A — Sans EMS', fontsize=14, fontweight='bold', color='#ef4444')
ax1.set_xlabel('Heure')
ax1.set_ylabel('SOC (%)')
ax1.set_xlim(0, 24); ax1.set_ylim(-5, 105)
ax1.set_xticks(xticks); ax1.set_xticklabels(hours)
ax1.annotate('SOC atteint 100%\n(surcharge)', xy=(12, 100), xytext=(8, 85),
            fontsize=10, arrowprops=dict(arrowstyle='->', color='#ef4444'),
            color='#ef4444', fontweight='bold')
ax1.annotate('SOC tombe à 0%\n(décharge profonde)', xy=(23, 0), xytext=(18, 15),
            fontsize=10, arrowprops=dict(arrowstyle='->', color='#ef4444'),
            color='#ef4444', fontweight='bold')

ax2.plot(t, soc, color='#10b981', linewidth=2.5)
ax2.axhline(y=90, color='#ef4444', linestyle='--', linewidth=1.5, label='Limites EMS')
ax2.axhline(y=30, color='#ef4444', linestyle='--', linewidth=1.5)
ax2.fill_between(t, 30, 90, alpha=0.06, color='green')
ax2.set_title('Case B — Avec EMS', fontsize=14, fontweight='bold', color='#10b981')
ax2.set_xlabel('Heure')
ax2.set_xlim(0, 24)
ax2.set_xticks(xticks); ax2.set_xticklabels(hours)
ax2.annotate('SOC plafonné\nà 90%', xy=(12, 90), xytext=(14, 75),
            fontsize=10, arrowprops=dict(arrowstyle='->', color='#10b981'),
            color='#10b981', fontweight='bold')
ax2.annotate('SOC protégé\nà 30%', xy=(22, 30), xytext=(18, 45),
            fontsize=10, arrowprops=dict(arrowstyle='->', color='#10b981'),
            color='#10b981', fontweight='bold')
ax2.legend(loc='center right')

fig.suptitle('Comparaison Case A vs Case B — Impact de l\'EMS sur la batterie',
             fontsize=15, fontweight='bold')
plt.tight_layout()
plt.savefig(os.path.join(output_dir, 'fig_case_ab_detailed.png'))
print("Saved: fig_case_ab_detailed.png")

print("\n=== 3 DETAILED PLOTS GENERATED ===")
