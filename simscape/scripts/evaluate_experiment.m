function score = evaluate_experiment()
%EVALUATE_EXPERIMENT  Compute EMS performance metrics from simulation output.
%
%   score = evaluate_experiment()
%
%   Expects these Timeseries in the base workspace (produced by build_fullday):
%     Vdc_bus, SOC_batt, P_pv, P_wt, P_fc, P_dc_load, P_ac_load, Tariff
%
%   Metrics:
%     DeltaV_max          - max |Vdc - 750| as % of 750V
%     SOC_in_range_pct    - % of time SOC in [30, 90]
%     daily_cost_eur      - estimated daily electricity cost (ARERA tariffs)
%     self_consumption_pct- % of generated power consumed locally
%     safety_violations   - count: Vdc outside ±5% OR SOC<10% OR SOC>95%
%
%   Score = -10*DeltaV_max + 5*SOC_in_range_pct - 2*daily_cost_eur
%           + 3*self_consumption_pct - 1000*safety_violations
%
%   Saves results to: autoresearch/logs/last_result.csv

try
    %% ---- Pull variables from base workspace ----
    Vdc  = evalin('base', 'Vdc_bus');
    SOC  = evalin('base', 'SOC_batt');
    Ppv  = evalin('base', 'P_pv');
    Pwt  = evalin('base', 'P_wt');
    Pfc  = evalin('base', 'P_fc');
    Pdcl = evalin('base', 'P_dc_load');
    Pac  = evalin('base', 'P_ac_load');
    Tar  = evalin('base', 'Tariff');

    %% ---- 1. DeltaV_max (%) ----
    vdc_data = Vdc.Data(:);
    DeltaV_max = max(abs(vdc_data - 750)) / 750 * 100;

    %% ---- 2. SOC_in_range_pct (%) ----
    soc_data = SOC.Data(:);
    SOC_min = 30;  SOC_max = 90;
    in_range = (soc_data >= SOC_min) & (soc_data <= SOC_max);
    SOC_in_range_pct = sum(in_range) / numel(soc_data) * 100;

    %% ---- 3. daily_cost_eur ----
    % Simulation is 24s representing 24h. Each sim-second = 1 hour.
    % Grid import cost = integral of max(0, P_load - P_gen) * tariff over time
    % Power is in Watts, tariff is EUR/kWh, time step ~ dt in sim-seconds (=hours).
    t = Vdc.Time(:);
    dt = diff(t);  % time steps in sim-seconds (each = 1 hour)

    % Total generation and load at each time step
    P_gen  = Ppv.Data(:) + Pwt.Data(:) + Pfc.Data(:);
    P_load = Pdcl.Data(:) + Pac.Data(:);
    P_deficit = max(0, P_load - P_gen);  % power imported from grid (W)

    % Resample tariff to match Vdc time vector length
    tar_data = Tar.Data(:);
    if numel(tar_data) ~= numel(t)
        tar_data = interp1(Tar.Time(:), tar_data, t, 'previous', 'extrap');
    end

    % Cost = sum of (P_deficit_kW * tariff * dt_hours)
    % Since 1 sim-second = 1 hour, dt is already in hours
    n = min(numel(dt), numel(P_deficit)-1);
    cost_per_step = (P_deficit(1:n) / 1e3) .* tar_data(1:n) .* dt(1:n);
    daily_cost_eur = sum(cost_per_step);

    %% ---- 4. self_consumption_pct (%) ----
    % Self-consumption = energy consumed locally / energy generated
    P_self = min(P_gen, P_load);  % locally consumed = min(gen, load)
    E_gen  = sum(P_gen(1:n) .* dt(1:n));
    E_self = sum(P_self(1:n) .* dt(1:n));
    if E_gen > 0
        self_consumption_pct = E_self / E_gen * 100;
    else
        self_consumption_pct = 0;
    end

    %% ---- 5. safety_violations ----
    % Vdc outside ±5% of 750V (i.e., outside [712.5, 787.5])
    v_violations = sum(vdc_data < 712.5 | vdc_data > 787.5);
    % SOC below 10% or above 95%
    soc_violations = sum(soc_data < 10 | soc_data > 95);
    safety_violations = v_violations + soc_violations;

    %% ---- Weighted score ----
    score = -10 * DeltaV_max ...
            + 5 * SOC_in_range_pct ...
            - 2 * daily_cost_eur ...
            + 3 * self_consumption_pct ...
            - 1000 * safety_violations;

    %% ---- Save CSV ----
    script_dir = fileparts(mfilename('fullpath'));
    csv_dir = fullfile(script_dir, '..', '..', 'autoresearch', 'logs');
    if ~exist(csv_dir, 'dir'), mkdir(csv_dir); end
    csv_path = fullfile(csv_dir, 'last_result.csv');

    fid = fopen(csv_path, 'w');
    fprintf(fid, 'DeltaV_max,SOC_in_range_pct,daily_cost_eur,self_consumption_pct,safety_violations,score\n');
    fprintf(fid, '%.4f,%.4f,%.4f,%.4f,%d,%.4f\n', ...
        DeltaV_max, SOC_in_range_pct, daily_cost_eur, self_consumption_pct, safety_violations, score);
    fclose(fid);

    %% ---- Print to stdout ----
    fprintf('\n=== EVALUATE_EXPERIMENT RESULTS ===\n');
    fprintf('DeltaV_max:          %.4f %%\n', DeltaV_max);
    fprintf('SOC_in_range_pct:    %.4f %%\n', SOC_in_range_pct);
    fprintf('daily_cost_eur:      %.4f EUR\n', daily_cost_eur);
    fprintf('self_consumption_pct:%.4f %%\n', self_consumption_pct);
    fprintf('safety_violations:   %d\n', safety_violations);
    fprintf('SCORE: %.4f\n', score);
    fprintf('Saved to: %s\n', csv_path);

catch ME
    fprintf('[ERROR] evaluate_experiment failed: %s\n', ME.message);
    fprintf('SCORE: -Inf\n');
    score = -Inf;
end

end
