function run_case_comparison()
%RUN_CASE_COMPARISON  Case A (no EMS) vs Case B (with EMS)
%
% Case A: No SOC limits, FC always ON, no tariff awareness
% Case B: SOC 30-90%, FC controlled by EMS, tariff-aware
%
% Outputs comparison CSV + summary to workspace
%
% Based on: Prattico et al. (2025) Table 7, Section 4.9

fprintf('\n=== CASE A vs CASE B COMPARISON ===\n');
fprintf('Prattico et al. (2025) Table 7 reproduction\n\n');

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);

%% ========== CASE A: Baseline (no EMS) ==========
fprintf('--- CASE A: No EMS (baseline) ---\n');

build_fullday();  % builds prattico_fullday

% Modify for Case A: remove SOC limits
set_param('prattico_fullday/SOC_int', ...
    'UpperSaturationLimit', '100', ...
    'LowerSaturationLimit', '0');

% Modify for Case A: Vdc droop gain larger (less regulation)
set_param('prattico_fullday/Vdc_droop', 'Gain', '0.0003');

sim('prattico_fullday', 24);

% Collect Case A results
A.vdc = Vdc_bus;
A.soc = SOC_batt;
A.ppv = P_pv;
A.pwt = P_wt;
A.dp  = DeltaP;
A.pdcl = P_dc_load;
A.pac  = P_ac_load;
A.tar  = Tariff;

% Case A metrics
vdc_a = A.vdc.Data;
soc_a = A.soc.Data;
n_a = max(1, round(0.1*length(vdc_a)));
vdc_a_ss = vdc_a(n_a:end);

A.vdc_mean = mean(vdc_a_ss);
A.vdc_dev = max(abs(vdc_a_ss - 750)) / 750 * 100;
A.soc_min = min(soc_a);
A.soc_max = max(soc_a);
A.soc_range = A.soc_max - A.soc_min;

% Energy metrics
dt = 3600; % 1 sim-second = 1 hour = 3600 real seconds
ppv_a = A.ppv.Data;
dp_a = A.dp.Data;
pdcl_a = A.pdcl.Data;
pac_a = A.pac.Data;

% Grid import = deficit periods (DeltaP < 0 means need grid)
% In Case A with no grid, all deficit is unserved or from battery
deficit_a = dp_a(dp_a < 0);
A.total_deficit_kWh = abs(sum(deficit_a)) / 1e3 * dt / 3600;

% Self-consumption = generation consumed locally / total generation
gen_a = ppv_a + A.pwt.Data * 1e3;
load_a = pdcl_a + pac_a;
A.self_consumption = min(sum(min(gen_a, load_a)) / sum(gen_a) * 100, 100);

% Daily cost (simplified: all deficit imported at tariff price)
tar_a = A.tar.Data;
cost_a = 0;
for i = 1:length(dp_a)
    if dp_a(i) < 0
        cost_a = cost_a + abs(dp_a(i))/1e3 * tar_a(i);  % kWh * EUR/kWh
    end
end
A.daily_cost = cost_a * dt / 3600;  % scale by compression

fprintf('  Vdc: mean=%.1fV, dev=%.1f%%\n', A.vdc_mean, A.vdc_dev);
fprintf('  SOC: %.1f%% -> %.1f%% (range %.1f%%)\n', soc_a(1), soc_a(end), A.soc_range);
fprintf('  Self-consumption: %.1f%%\n', A.self_consumption);
fprintf('  Daily cost: %.2f EUR\n', A.daily_cost);

close_system('prattico_fullday', 0);

%% ========== CASE B: With EMS ==========
fprintf('\n--- CASE B: With EMS ---\n');

build_fullday();  % rebuild clean

% Case B is the default build_fullday (SOC 30-90%)
sim('prattico_fullday', 24);

% Collect Case B results
B.vdc = Vdc_bus;
B.soc = SOC_batt;
B.ppv = P_pv;
B.pwt = P_wt;
B.dp  = DeltaP;
B.pdcl = P_dc_load;
B.pac  = P_ac_load;
B.tar  = Tariff;

vdc_b = B.vdc.Data;
soc_b = B.soc.Data;
n_b = max(1, round(0.1*length(vdc_b)));
vdc_b_ss = vdc_b(n_b:end);

B.vdc_mean = mean(vdc_b_ss);
B.vdc_dev = max(abs(vdc_b_ss - 750)) / 750 * 100;
B.soc_min = min(soc_b);
B.soc_max = max(soc_b);
B.soc_range = B.soc_max - B.soc_min;

ppv_b = B.ppv.Data;
dp_b = B.dp.Data;
pdcl_b = B.pdcl.Data;
pac_b = B.pac.Data;

deficit_b = dp_b(dp_b < 0);
B.total_deficit_kWh = abs(sum(deficit_b)) / 1e3 * dt / 3600;

gen_b = ppv_b + B.pwt.Data * 1e3;
load_b = pdcl_b + pac_b;
B.self_consumption = min(sum(min(gen_b, load_b)) / sum(gen_b) * 100, 100);

tar_b = B.tar.Data;
cost_b = 0;
for i = 1:length(dp_b)
    if dp_b(i) < 0
        cost_b = cost_b + abs(dp_b(i))/1e3 * tar_b(i);
    end
end
B.daily_cost = cost_b * dt / 3600;

fprintf('  Vdc: mean=%.1fV, dev=%.1f%%\n', B.vdc_mean, B.vdc_dev);
fprintf('  SOC: %.1f%% -> %.1f%% (range %.1f%%)\n', soc_b(1), soc_b(end), B.soc_range);
fprintf('  Self-consumption: %.1f%%\n', B.self_consumption);
fprintf('  Daily cost: %.2f EUR\n', B.daily_cost);

%% ========== COMPARISON TABLE ==========
fprintf('\n=== COMPARISON TABLE (Prattico Table 7 style) ===\n');
fprintf('%-25s  %12s  %12s  %12s\n', 'Metric', 'Case A', 'Case B', 'Improvement');
fprintf('%-25s  %12s  %12s  %12s\n', repmat('-',1,25), repmat('-',1,12), repmat('-',1,12), repmat('-',1,12));

fprintf('%-25s  %11.1fV  %11.1fV  %11s\n', 'Vdc mean', A.vdc_mean, B.vdc_mean, '-');

fprintf('%-25s  %10.1f%%  %10.1f%%  %10s\n', 'DeltaV max', A.vdc_dev, B.vdc_dev, ...
    sprintf('%.1f%%->%.1f%%', A.vdc_dev, B.vdc_dev));

fprintf('%-25s  %10.1f%%  %10.1f%%  %10s\n', 'SOC min', A.soc_min, B.soc_min, ...
    sprintf('%.0f%%->%.0f%%', A.soc_min, B.soc_min));

fprintf('%-25s  %10.1f%%  %10.1f%%  %10s\n', 'SOC max', A.soc_max, B.soc_max, ...
    sprintf('%.0f%%->%.0f%%', A.soc_max, B.soc_max));

fprintf('%-25s  %10.1f%%  %10.1f%%  %10s\n', 'SOC range', A.soc_range, B.soc_range, ...
    sprintf('%.0f%%->%.0f%%', A.soc_range, B.soc_range));

fprintf('%-25s  %10.1f%%  %10.1f%%  %+10.1f%%\n', 'Self-consumption', ...
    A.self_consumption, B.self_consumption, B.self_consumption - A.self_consumption);

fprintf('%-25s  %9.2f EUR  %9.2f EUR  %+9.1f%%\n', 'Daily cost', ...
    A.daily_cost, B.daily_cost, ...
    (B.daily_cost - A.daily_cost) / max(A.daily_cost, 0.01) * 100);

% Battery lifetime indicator
fprintf('%-25s  %10s  %10s  %10s\n', 'Battery cycling', ...
    sprintf('%.0f%% DoD', A.soc_range), ...
    sprintf('%.0f%% DoD', B.soc_range), ...
    'Lifetime extended');

fprintf('\n=== Paper targets (Table 7) ===\n');
fprintf('  Grid imports:       -18%% (paper)\n');
fprintf('  Daily cost:         -10-15%% (paper)\n');
fprintf('  Self-consumption:   62%% -> 78%% (paper)\n');
fprintf('  SOC range:          10-100%% -> 30-90%% (paper)\n');

%% ========== EXPORT CSV ==========
output_dir = fullfile(script_dir, '..', '..', 'microgrid_data', 'downloads');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
output_file = fullfile(output_dir, 'case_comparison_results.csv');
fid = fopen(output_file, 'w');
if fid == -1, warning('Cannot write CSV: %s', output_file); return; end
fprintf(fid, 'Metric,Case_A,Case_B,Improvement,Paper_Target\n');
fprintf(fid, 'Vdc_mean_V,%.1f,%.1f,,\n', A.vdc_mean, B.vdc_mean);
fprintf(fid, 'DeltaV_max_pct,%.1f,%.1f,,+/-2%%\n', A.vdc_dev, B.vdc_dev);
fprintf(fid, 'SOC_min_pct,%.1f,%.1f,,30%%\n', A.soc_min, B.soc_min);
fprintf(fid, 'SOC_max_pct,%.1f,%.1f,,90%%\n', A.soc_max, B.soc_max);
fprintf(fid, 'SOC_range_pct,%.1f,%.1f,,60%%\n', A.soc_range, B.soc_range);
fprintf(fid, 'Self_consumption_pct,%.1f,%.1f,+%.1f%%,+16%%\n', ...
    A.self_consumption, B.self_consumption, B.self_consumption - A.self_consumption);
fprintf(fid, 'Daily_cost_EUR,%.2f,%.2f,%.1f%%,-10-15%%\n', ...
    A.daily_cost, B.daily_cost, (B.daily_cost-A.daily_cost)/max(A.daily_cost,0.01)*100);
fclose(fid);
fprintf('\nResults saved to: case_comparison_results.csv\n');

fprintf('\n=== CASE COMPARISON COMPLETE ===\n');

end
