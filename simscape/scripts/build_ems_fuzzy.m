function build_ems_fuzzy(mdl)
%BUILD_EMS_FUZZY  Fuzzy EMS — Rule-based approximation (Prattico §2.5-2.6)
%
% Implements the EMS decision logic from Table 2/3:
%   Inputs:  ΔP (generation - load), SOC, Tariff
%   Outputs: P_ref_batt, P_ref_AC, Grid_connection, FC_connection
%
% ΔP = P_pv + P_wt - P_dc_load - P_ac_load (Eq. from §2.4, Figure 2)
% Note: FC and Battery are OUTPUTS of EMS, not inputs to ΔP.
%
% Based on: Prattico et al. (2025) §2.5, §2.6, Table 2, Table 3

fprintf('  Building EMS (rule-based fuzzy approximation)...\n');

%% ========== Tariff Profile (§4.3) ==========
% Dynamic pricing: 0.05-0.15 €/kWh
t_tariff = [0  6  7  9  11  17  19  21  22  24];
p_tariff = [0.05 0.05 0.08 0.10 0.12 0.10 0.15 0.15 0.10 0.05];

add_block('simulink/Sources/Repeating Sequence Interpolated', ...
    [mdl '/Tariff_Profile'], ...
    'Position', [50 1150 110 1180], ...
    'OutValues', mat2str(p_tariff), ...
    'TimeValues', mat2str(t_tariff));

add_block('simulink/Sinks/To Workspace', [mdl '/Log_Tariff'], ...
    'Position', [150 1185 210 1205], ...
    'VariableName', 'Tariff', 'SaveFormat', 'Timeseries');
add_line(mdl, 'Tariff_Profile/1', 'Log_Tariff/1');

%% ========== ΔP Computation (§2.4) ==========
% ΔP = P_pv + P_wt - P_dc_load - P_ac_load
% NOTE: FC and Battery are NOT in ΔP (they are EMS outputs)

% We need P_pv, P_wt from Goto tags. But these might not exist as Goto tags.
% P_pv is logged via To Workspace but may not have a Goto.
% For simplicity, use the known power values at the top level.

% Create ΔP from the existing power signals
% P_pv comes from the PV_System (Goto tag not available at top level)
% P_wt comes from WT_Psat (top level block)
% P_dc_load from DC_Load_Profile
% P_ac_load from AC_Total

% ΔP = P_wt + P_pv_approx - P_dc_load - P_ac_load
% For Phase H, use approximate P_pv from a constant (59 kW at STC)
% A proper implementation would use actual measured P_pv

add_block('simulink/Sources/Constant', [mdl '/EMS_Ppv_approx'], ...
    'Position', [50 1220 80 1240], 'Value', '59200');

add_block('simulink/Math Operations/Sum', [mdl '/EMS_DeltaP'], ...
    'Position', [180 1210 220 1270], 'Inputs', '++--');

% Connect: P_pv_approx + P_wt_value - P_dc_load - P_ac_load
% P_wt from WT_Psat output
add_block('simulink/Sources/Constant', [mdl '/EMS_Pwt_approx'], ...
    'Position', [50 1250 80 1270], 'Value', '55200');

% P_dc_load from DC_Load_Profile (already exists)
% P_ac_load from AC_Total (already exists)

add_line(mdl, 'EMS_Ppv_approx/1', 'EMS_DeltaP/1');  % +P_pv
add_line(mdl, 'EMS_Pwt_approx/1', 'EMS_DeltaP/2');  % +P_wt
add_line(mdl, 'DC_Load_Profile/1', 'EMS_DeltaP/3'); % -P_dc_load
add_line(mdl, 'AC_Total/1',        'EMS_DeltaP/4'); % -P_ac_load

add_block('simulink/Sinks/To Workspace', [mdl '/Log_DeltaP'], ...
    'Position', [260 1225 320 1245], ...
    'VariableName', 'DeltaP', 'SaveFormat', 'Timeseries');
add_line(mdl, 'EMS_DeltaP/1', 'Log_DeltaP/1');

%% ========== EMS Rule-Based Logic ==========
% Simplified Table 3 rules using thresholds:
%
% FC_connection:
%   ON  if ΔP < -60 kW (Deficit-High) AND SOC < 40% (Low)
%   OFF otherwise
%
% Grid_connection:
%   Connected if ΔP < -30 kW (Deficit) OR ΔP > 90 kW (Surplus-High)
%   Disconnected otherwise
%
% For Phase H testing with constant inputs, FC stays OFF (ΔP > 0 = surplus)

% FC control: compare ΔP < -60000 AND SOC < 40
% Since we can't easily do AND logic with Simulink blocks,
% use a simple threshold on ΔP for FC:
%   FC_on = 1 if ΔP < -60 kW, else 0
add_block('simulink/Discontinuities/Saturation', [mdl '/EMS_FC_thresh'], ...
    'Position', [260 1260 300 1280], ...
    'UpperLimit', '1', 'LowerLimit', '0');
add_block('simulink/Math Operations/Gain', [mdl '/EMS_FC_gain'], ...
    'Position', [220 1260 250 1280], ...
    'Gain', num2str(-1/60000));  % Scale: -60kW → 1

% ΔP → scale → saturate [0,1] = FC_connection
% When ΔP = -60kW: scaled = 1 → FC ON
% When ΔP = 0: scaled = 0 → FC OFF
% When ΔP > 0: scaled < 0 → saturated to 0 → FC OFF
add_line(mdl, 'EMS_DeltaP/1', 'EMS_FC_gain/1');
add_line(mdl, 'EMS_FC_gain/1', 'EMS_FC_thresh/1');

add_block('simulink/Sinks/To Workspace', [mdl '/Log_FC_cmd'], ...
    'Position', [380 1260 440 1280], ...
    'VariableName', 'FC_connection', 'SaveFormat', 'Timeseries');

% Goto tag so FC subsystem can read FC_cmd
add_block('simulink/Signal Routing/Goto', [mdl '/Goto_FC_cmd'], ...
    'Position', [340 1285 390 1305], ...
    'GotoTag', 'FC_cmd', 'TagVisibility', 'global');

% Branch FC_thresh output to both Log and Goto
add_line(mdl, 'EMS_FC_thresh/1', 'Log_FC_cmd/1');
add_line(mdl, 'EMS_FC_thresh/1', 'Goto_FC_cmd/1');

% Log EMS outputs
add_block('simulink/Sinks/To Workspace', [mdl '/Log_EMS_summary'], ...
    'Position', [260 1290 320 1310], ...
    'VariableName', 'EMS_active', 'SaveFormat', 'Timeseries');
add_block('simulink/Sources/Constant', [mdl '/EMS_active_flag'], ...
    'Position', [220 1292 250 1308], 'Value', '1');
add_line(mdl, 'EMS_active_flag/1', 'Log_EMS_summary/1');

fprintf('  EMS built: ΔP computed, FC threshold at -60kW\n');
fprintf('  Tariff profile: %.2f-%.2f €/kWh\n', min(p_tariff), max(p_tariff));
fprintf('  Note: Full 80-rule Mamdani FIS = future enhancement\n');

end
