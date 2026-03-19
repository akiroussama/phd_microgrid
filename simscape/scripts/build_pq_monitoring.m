function build_pq_monitoring(mdl)
%BUILD_PQ_MONITORING  Power Quality indicators (Prattico §2.2, Table 1)
%
% Measurable with current average-value model:
%   1. ΔV_DC = (V_dc - V_nom) / V_nom × 100  (Eq. 1 adapted for DC)
%   2. Power balance: P_gen - P_load - P_losses
%   3. DC bus ripple (if present)
%
% Future (requires AC bus): THD_V, TDD, Δf, PF
%
% Based on: Prattico et al. (2025) §2.2, Table 1, §4.8

fprintf('  Building PQ monitoring...\n');

%% ========== ΔV_DC computation ==========
% ΔV = (V_dc - 750) / 750 × 100 [%]
add_block('simulink/Signal Routing/From', [mdl '/PQ_From_Vdc'], ...
    'Position', [50 1050 90 1070], 'GotoTag', 'Vdc_bus');

add_block('simulink/Math Operations/Sum', [mdl '/PQ_Vdc_err'], ...
    'Position', [120 1045 150 1075], 'Inputs', '+-');
add_block('simulink/Sources/Constant', [mdl '/PQ_Vnom'], ...
    'Position', [70 1080 100 1100], 'Value', '750');

add_block('simulink/Math Operations/Gain', [mdl '/PQ_DeltaV_pct'], ...
    'Position', [180 1048 230 1072], 'Gain', num2str(100/750));

add_block('simulink/Sinks/To Workspace', [mdl '/Log_DeltaV'], ...
    'Position', [260 1050 320 1070], ...
    'VariableName', 'DeltaV_dc', 'SaveFormat', 'Timeseries');

% Wire
add_line(mdl, 'PQ_From_Vdc/1', 'PQ_Vdc_err/1');
add_line(mdl, 'PQ_Vnom/1',     'PQ_Vdc_err/2');
add_line(mdl, 'PQ_Vdc_err/1',  'PQ_DeltaV_pct/1');
add_line(mdl, 'PQ_DeltaV_pct/1', 'Log_DeltaV/1');

%% ========== Power Balance ==========
% P_gen = P_pv + P_wt + P_fc
% P_load = P_dc_load + P_ac_load
% P_balance = P_gen - P_load (should be absorbed by battery + losses)

% Collect generation signals via From tags
add_block('simulink/Signal Routing/From', [mdl '/PQ_From_Ppv'], ...
    'Position', [50 1120 90 1140], 'GotoTag', 'P_pv_signal');
% Note: P_pv might not have a Goto tag. Use the existing logged data.
% For power balance, we'll compute it in validate_phase_g from workspace variables.

fprintf('  PQ monitoring built: DeltaV_dc logged\n');
fprintf('  Note: THD_V, TDD, Δf require AC bus (future Phase F.2)\n');

end
