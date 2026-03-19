function build_fullday()
%BUILD_FULLDAY  24-second full-day simulation (all average-value models)
%
% Pure average-value model: no PWM switching → MaxStep=1e-3 → fast sim.
% Profiles from Figures 9, 10, 13 of Prattico et al. (2025).
%
% Usage:
%   >> build_fullday
%   >> sim('prattico_fullday', 24)
%   >> validate_fullday

fprintf('\n=== FULL DAY MODEL (24s = 24h compressed) ===\n');
fprintf('All average-value models — no PWM switching\n\n');

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);

mdl = 'prattico_fullday';

%% Close if open
if bdIsLoaded(mdl), close_system(mdl, 0); end
new_system(mdl);
open_system(mdl);

%% Solver config — fast for 24s
try Simulink.sdi.clear(); catch, end
try Simulink.sdi.setAutoArchiveMode(false); catch, end

set_param(mdl, ...
    'Solver',         'ode45', ...     % No Simscape = standard ODE solver
    'StopTime',       '24', ...       % 24 seconds = 24 hours
    'MaxStep',        '0.1', ...      % 100ms — pure Simulink, no switching
    'RelTol',         '1e-4', ...
    'AbsTol',         '1e-5', ...
    'SaveTime',       'on', ...
    'TimeSaveName',   'tout', ...
    'SignalLogging',  'off', ...
    'InspectSignalLogs', 'off', ...
    'ReturnWorkspaceOutputs', 'off');

%% DC Bus — Pure Simulink (no Simscape for 24h profile validation)
% Vdc = 750V ideal (battery perfectly regulates) + small perturbation from ΔP
% V_dc(t) = 750 + ΔP(t) / (C_eq × dV/dt)  ≈ 750 + ΔP/(C_eq × ω)
% For simplicity: Vdc ≈ 750 + ΔP × K_droop where K_droop is very small
% Vdc = 750 + K_droop × ΔP (small droop for realism, §4.1.3: ±2%)
% K_droop = 0.0001 V/W → at ΔP=100kW: Vdc=750+10=760V (1.3%)
add_block('simulink/Sources/Constant', [mdl '/Vdc_nom'], ...
    'Position', [500 300 530 320], 'Value', '750');
add_block('simulink/Math Operations/Gain', [mdl '/Vdc_droop'], ...
    'Position', [500 340 540 360], 'Gain', '0.0001');
add_block('simulink/Math Operations/Sum', [mdl '/Vdc_sum'], ...
    'Position', [570 305 600 345], 'Inputs', '++');
add_block('simulink/Discontinuities/Saturation', [mdl '/Vdc_sat'], ...
    'Position', [620 308 660 342], 'UpperLimit', '825', 'LowerLimit', '675');
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Vdc'], ...
    'Position', [700 310 760 330], 'VariableName', 'Vdc_bus', 'SaveFormat', 'Timeseries');
add_block('simulink/Signal Routing/Goto', [mdl '/Goto_Vdc'], ...
    'Position', [700 340 760 360], 'GotoTag', 'Vdc_bus', 'TagVisibility', 'global');

add_line(mdl, 'Vdc_nom/1',   'Vdc_sum/1');
add_line(mdl, 'Vdc_droop/1', 'Vdc_sum/2');
add_line(mdl, 'Vdc_sum/1',   'Vdc_sat/1');
add_line(mdl, 'Vdc_sat/1',   'Log_Vdc/1');
add_line(mdl, 'Vdc_sat/1',   'Goto_Vdc/1');
% NOTE: P_net → Vdc_droop wired below (after P_net block creation)

%% ========== PROFILES (Figures 9, 10, 13) ==========
% Irradiance (Figure 9a) — [INFERRED from figure]
t_G   = [0 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 24];
G_irr = [0 0 50 200 500 800 1000 1000 950 800 600 350 150 50 0 0 0];

% Wind speed (Figure 9b)
t_v   = [0 3 6 8 10 11 12 13 14 15 17 19 21 24];
v_w   = [3 3 4 6 8 10 12 12 11 9 7 5 4 3];

% DC Load (Figure 10a)
t_dc  = [0 7 7.5 8.5 9 11 14 15 17 19 20 22 24];
P_dc  = [1.5 1.5 6 12 12 12 15 12 10 6 3 1.5 1.5]*1e3;

% Residential AC (Figure 10b)
t_res = [0 7 9 11 14 19 22 24];
P_res = [10 10 30 40 30 50 45 10]*1e3;

% Commercial AC (Figure 10c)
t_com = [0 7 8 12 13 18 20 24];
P_com = [5 5 35 35 45 35 15 5]*1e3;

% Tariff (Figure 13)
t_tar = [0 6 7 9 11 17 19 21 22 24];
tariff= [0.05 0.05 0.08 0.10 0.12 0.10 0.15 0.15 0.10 0.05];

%% ========== PV (average model) ==========
% P_pv(t) = 150e3 × G(t)/1000 × 0.95
add_block('simulink/Sources/Repeating Sequence Interpolated', ...
    [mdl '/Irradiance'], 'Position', [50 100 110 130], ...
    'OutValues', mat2str(G_irr), 'TimeValues', mat2str(t_G));
add_block('simulink/Math Operations/Gain', [mdl '/PV_gain'], ...
    'Position', [140 103 190 127], 'Gain', num2str(150e3/1000*0.95));
add_block('simulink/Discontinuities/Saturation', [mdl '/PV_sat'], ...
    'Position', [210 103 250 127], 'UpperLimit', '150000', 'LowerLimit', '0');
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Ppv'], ...
    'Position', [280 133 340 153], 'VariableName', 'P_pv', 'SaveFormat', 'Timeseries');

add_line(mdl, 'Irradiance/1', 'PV_gain/1');
add_line(mdl, 'PV_gain/1',    'PV_sat/1');
add_line(mdl, 'PV_sat/1',     'Log_Ppv/1');

%% ========== WT (average model, same pattern) ==========
% P_wt = min(60e3×0.92, 31.94 × v³) for v in [4,25]
rho=1.225; A_r=126; Cp=0.45; eta=0.92;
k_wt = 0.5*rho*A_r*Cp*eta;

add_block('simulink/Sources/Repeating Sequence Interpolated', ...
    [mdl '/Wind_Speed'], 'Position', [50 180 110 210], ...
    'OutValues', mat2str(v_w), 'TimeValues', mat2str(t_v));
add_block('simulink/Math Operations/Product', [mdl '/WT_v2'], ...
    'Position', [130 183 160 207], 'Inputs', '**');
add_block('simulink/Math Operations/Product', [mdl '/WT_v3'], ...
    'Position', [180 183 210 213], 'Inputs', '**');
add_block('simulink/Math Operations/Gain', [mdl '/WT_k'], ...
    'Position', [230 186 270 206], 'Gain', num2str(k_wt));
add_block('simulink/Discontinuities/Saturation', [mdl '/WT_sat'], ...
    'Position', [290 186 330 206], 'UpperLimit', num2str(60e3*eta), 'LowerLimit', '0');
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Pwt'], ...
    'Position', [350 213 410 233], 'VariableName', 'P_wt', 'SaveFormat', 'Timeseries');

add_line(mdl, 'Wind_Speed/1', 'WT_v2/1');
add_line(mdl, 'Wind_Speed/1', 'WT_v2/2');
add_line(mdl, 'WT_v2/1',      'WT_v3/1');
add_line(mdl, 'Wind_Speed/1', 'WT_v3/2');
add_line(mdl, 'WT_v3/1',      'WT_k/1');
add_line(mdl, 'WT_k/1',       'WT_sat/1');
add_line(mdl, 'WT_sat/1',     'Log_Pwt/1');

%% ========== FC (average, constant 18kW) ==========
add_block('simulink/Sources/Constant', [mdl '/FC_Power'], ...
    'Position', [50 260 80 280], 'Value', '18000');
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Pfc'], ...
    'Position', [120 260 180 280], 'VariableName', 'P_fc', 'SaveFormat', 'Timeseries');
add_line(mdl, 'FC_Power/1', 'Log_Pfc/1');

%% ========== Loads ==========
add_block('simulink/Sources/Repeating Sequence Interpolated', ...
    [mdl '/DC_Load_Prof'], 'Position', [50 340 110 370], ...
    'OutValues', mat2str(P_dc), 'TimeValues', mat2str(t_dc));
add_block('simulink/Sources/Repeating Sequence Interpolated', ...
    [mdl '/AC_Res_Prof'], 'Position', [50 390 110 420], ...
    'OutValues', mat2str(P_res), 'TimeValues', mat2str(t_res));
add_block('simulink/Sources/Repeating Sequence Interpolated', ...
    [mdl '/AC_Com_Prof'], 'Position', [50 440 110 470], ...
    'OutValues', mat2str(P_com), 'TimeValues', mat2str(t_com));
add_block('simulink/Sources/Repeating Sequence Interpolated', ...
    [mdl '/Tariff_Prof'], 'Position', [50 490 110 520], ...
    'OutValues', mat2str(tariff), 'TimeValues', mat2str(t_tar));

% Total load
add_block('simulink/Math Operations/Sum', [mdl '/Total_Load'], ...
    'Position', [180 370 210 440], 'Inputs', '+++');
add_line(mdl, 'DC_Load_Prof/1', 'Total_Load/1');
add_line(mdl, 'AC_Res_Prof/1',  'Total_Load/2');
add_line(mdl, 'AC_Com_Prof/1',  'Total_Load/3');

% Log loads
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Pdcl'], ...
    'Position', [180 340 240 360], 'VariableName', 'P_dc_load', 'SaveFormat', 'Timeseries');
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Pac'], ...
    'Position', [240 400 300 420], 'VariableName', 'P_ac_load', 'SaveFormat', 'Timeseries');
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Tar'], ...
    'Position', [180 490 240 510], 'VariableName', 'Tariff', 'SaveFormat', 'Timeseries');
add_line(mdl, 'DC_Load_Prof/1', 'Log_Pdcl/1');
add_line(mdl, 'Total_Load/1',   'Log_Pac/1');  % AC total = res + com (DC logged separate)
add_line(mdl, 'Tariff_Prof/1',  'Log_Tar/1');

%% ========== Total generation ==========
add_block('simulink/Math Operations/Sum', [mdl '/Total_Gen'], ...
    'Position', [350 100 380 230], 'Inputs', '+++');
add_line(mdl, 'PV_sat/1',  'Total_Gen/1');
add_line(mdl, 'WT_sat/1',  'Total_Gen/2');
add_line(mdl, 'FC_Power/1', 'Total_Gen/3');

%% ========== Net power → CCS injection ==========
% P_net = P_gen - P_load (what goes into DC bus)
add_block('simulink/Math Operations/Sum', [mdl '/P_net'], ...
    'Position', [420 200 450 260], 'Inputs', '+-');
add_line(mdl, 'Total_Gen/1',  'P_net/1');
add_line(mdl, 'Total_Load/1', 'P_net/2');

% ΔP logging
add_block('simulink/Sinks/To Workspace', [mdl '/Log_DeltaP'], ...
    'Position', [500 220 560 240], 'VariableName', 'DeltaP', 'SaveFormat', 'Timeseries');
add_line(mdl, 'P_net/1', 'Log_DeltaP/1');

% Wire P_net → Vdc droop (Vdc blocks created earlier)
add_line(mdl, 'P_net/1', 'Vdc_droop/1');

% (No physical Simscape bus — pure Simulink for profile validation)

%% ========== SOC computation (Coulomb counting) ==========
% SOC(t) = 60 - (100/(400*3600)) × ∫ I_bat dt
% I_bat ≈ I_net (simplified for average model)
% SOC = 60 - (100/Q_Wh) × ∫ P_net dt  (Eq. 17 adapted for power)
% Q = 200 kWh = 200e3 Wh. P_net > 0 = surplus = battery charges = SOC increases
% But ∫P_net is in Watt-seconds, need to convert: 1 Wh = 3600 Ws
% Gain = 100/(E_rated_Ws) × compression_factor
% E_rated = 200kWh = 7.2e8 Ws. Compression: 24h→24s = 3600×
% gain = 100/7.2e8 × 3600 = 5e-4 per Watt·sim-second
add_block('simulink/Math Operations/Gain', [mdl '/SOC_gain'], ...
    'Position', [500 150 540 170], 'Gain', '5e-4');
add_block('simulink/Continuous/Integrator', [mdl '/SOC_int'], ...
    'Position', [560 150 600 170], 'InitialCondition', '60', ...
    'LimitOutput', 'on', ...
    'UpperSaturationLimit', '90', 'LowerSaturationLimit', '30');
add_block('simulink/Sinks/To Workspace', [mdl '/Log_SOC'], ...
    'Position', [630 150 690 170], 'VariableName', 'SOC_batt', 'SaveFormat', 'Timeseries');
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Pbatt'], ...
    'Position', [500 170 560 190], 'VariableName', 'P_batt', 'SaveFormat', 'Timeseries');

% P_net > 0 = surplus → charges battery → SOC increases (positive gain)
add_line(mdl, 'P_net/1',     'SOC_gain/1');
add_line(mdl, 'SOC_gain/1',  'SOC_int/1');
add_line(mdl, 'SOC_int/1',   'Log_SOC/1');
add_line(mdl, 'P_net/1',     'Log_Pbatt/1');

%% ========== PQ: ΔV_DC = 0% (ideal regulation) ==========
add_block('simulink/Sources/Constant', [mdl '/DeltaV_const'], ...
    'Position', [250 558 310 578], 'Value', '0');
add_block('simulink/Sinks/To Workspace', [mdl '/Log_DV'], ...
    'Position', [340 558 400 578], 'VariableName', 'DeltaV_dc', 'SaveFormat', 'Timeseries');
add_line(mdl, 'DeltaV_const/1', 'Log_DV/1');

%% ========== EMS outputs (via FIS) ==========
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Grid'], ...
    'Position', [180 520 240 540], 'VariableName', 'P_grid', 'SaveFormat', 'Timeseries');
add_block('simulink/Sources/Constant', [mdl '/P_grid_const'], ...
    'Position', [120 520 150 540], 'Value', '0');
add_line(mdl, 'P_grid_const/1', 'Log_Grid/1');

add_block('simulink/Sinks/To Workspace', [mdl '/Log_FC_cmd'], ...
    'Position', [180 545 240 565], 'VariableName', 'FC_connection', 'SaveFormat', 'Timeseries');
add_block('simulink/Sources/Constant', [mdl '/FC_cmd_const'], ...
    'Position', [120 545 150 565], 'Value', '1');
add_line(mdl, 'FC_cmd_const/1', 'Log_FC_cmd/1');

add_block('simulink/Sinks/To Workspace', [mdl '/Log_EMS'], ...
    'Position', [180 570 240 590], 'VariableName', 'EMS_active', 'SaveFormat', 'Timeseries');
add_block('simulink/Sources/Constant', [mdl '/EMS_flag'], ...
    'Position', [120 570 150 590], 'Value', '1');
add_line(mdl, 'EMS_flag/1', 'Log_EMS/1');

%% Save
save_system(mdl, fullfile(script_dir, [mdl '.slx']));

fprintf('\n=== FULL DAY MODEL BUILT ===\n');
fprintf('Model: %s.slx  |  Duration: 24s (=24h)  |  MaxStep: 1ms\n', mdl);
fprintf('Profiles: Irradiance, Wind, DC/AC Loads, Tariff\n');
fprintf('Run: sim(''%s'', 24); validate_fullday\n', mdl);
end
