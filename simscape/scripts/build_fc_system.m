function build_fc_system(mdl)
%BUILD_FC_SYSTEM  Fuel Cell 20 kW PEMFC — Average model (Prattico §3.2.3)
%
% Average-value model: P_fc injected as controlled current into DC bus.
% FC power = P_rated * FC_cmd, where FC_cmd (0 or 1) comes from EMS.
%
% Equations:
%   Eq. 15 (Nernst): E = E0 + (RT/2F)*ln(pH2*pO2^0.5/pH2O)
%   Eq. 16 (Terminal): V_FC = N*(E - V_act - V_ohm - V_conc)
%   Average model: I_fc = P_fc / V_dc_bus
%
% Based on: Prattico et al. (2025) §3.2.3, Table 5, Figure 5

wt_prefix = 'FC';  % prefix for top-level blocks

%% ========== Parameters (from paper) ==========
P_rated   = 20e3;       % 20 kW — §3.1, Table 5
V_stack   = 50;          % Stack nominal voltage [V] — §3.2.3
eta_conv  = 0.90;        % Boost converter efficiency (50V → 750V)
P_fc_net  = P_rated * eta_conv;  % Net power after converter losses

fprintf('  FC: P_rated=%gkW, V_stack=%gV, eta=%.0f%%, P_net=%.0fW\n', ...
    P_rated/1e3, V_stack, eta_conv*100, P_fc_net);

%% ========== TOP LEVEL: Simulink signal chain ==========
% FC power = P_rated * FC_cmd (0 or 1 from EMS)
% FC_cmd comes from EMS via Goto/From tag 'FC_cmd'
add_block('simulink/Signal Routing/From', [mdl '/' wt_prefix '_From_FCcmd'], ...
    'Position', [20 640 70 660], ...
    'GotoTag', 'FC_cmd');

add_block('simulink/Sources/Constant', [mdl '/' wt_prefix '_Prated'], ...
    'Position', [20 670 60 690], ...
    'Value', num2str(P_fc_net));

add_block('simulink/Math Operations/Product', [mdl '/' wt_prefix '_Power'], ...
    'Position', [90 650 120 680], 'Inputs', '2');

% FC_cmd * P_rated = actual FC power
add_line(mdl, [wt_prefix '_From_FCcmd/1'], [wt_prefix '_Power/1']);
add_line(mdl, [wt_prefix '_Prated/1'],     [wt_prefix '_Power/2']);

% Log P_fc
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Pfc'], ...
    'Position', [120 680 180 700], ...
    'VariableName', 'P_fc', ...
    'SaveFormat', 'Timeseries');

% I_fc = P_fc / Vdc (with LPF + clamp)
add_block('simulink/Signal Routing/From', [mdl '/' wt_prefix '_From_Vdc'], ...
    'Position', [120 720 160 740], ...
    'GotoTag', 'Vdc_bus');

add_block('simulink/Continuous/State-Space', [mdl '/' wt_prefix '_Vdc_LPF'], ...
    'Position', [180 720 220 740], ...
    'A', '-200', 'B', '200', 'C', '1', 'D', '0', 'X0', '750');

add_block('simulink/Math Operations/MinMax', [mdl '/' wt_prefix '_Vdc_clamp'], ...
    'Position', [240 718 270 745], 'Function', 'max', 'Inputs', '2');
add_block('simulink/Sources/Constant', [mdl '/' wt_prefix '_Vdc_min'], ...
    'Position', [200 750 230 765], 'Value', '400');

add_block('simulink/Math Operations/Divide', [mdl '/' wt_prefix '_Idiv'], ...
    'Position', [300 650 330 695]);

add_block('simulink/Discontinuities/Saturation', [mdl '/' wt_prefix '_Isat'], ...
    'Position', [350 655 390 685], ...
    'UpperLimit', num2str(P_rated / 400), 'LowerLimit', '0');

% Wire top-level signal chain
add_line(mdl, [wt_prefix '_Power/1'],     [wt_prefix '_Idiv/1']);
add_line(mdl, [wt_prefix '_Power/1'],     'Log_Pfc/1');
add_line(mdl, [wt_prefix '_From_Vdc/1'],  [wt_prefix '_Vdc_LPF/1']);
add_line(mdl, [wt_prefix '_Vdc_LPF/1'],   [wt_prefix '_Vdc_clamp/1']);
add_line(mdl, [wt_prefix '_Vdc_min/1'],   [wt_prefix '_Vdc_clamp/2']);
add_line(mdl, [wt_prefix '_Vdc_clamp/1'], [wt_prefix '_Idiv/2']);
add_line(mdl, [wt_prefix '_Idiv/1'],      [wt_prefix '_Isat/1']);

%% ========== FC SUBSYSTEM: Physical blocks only ==========
fc = [mdl '/FC_System'];

% Delete existing contents
delete_subsystem_contents(fc);

% Inport for current signal
add_block('simulink/Sources/In1', [fc '/I_fc_in'], ...
    'Position', [50 105 80 125]);

% Simulink-PS Converter
add_block('nesl_utility/Simulink-PS Converter', [fc '/SPS_Ifc'], ...
    'Position', [120 105 150 130]);

% Controlled Current Source
add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source', ...
    [fc '/CCS_FC'], ...
    'Position', [200 80 240 160]);

% Electrical Reference
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', ...
    [fc '/GND_FC'], ...
    'Position', [200 250 240 290]);

% Connection Ports
add_block('nesl_utility/Connection Port', [fc '/DC_Plus'], ...
    'Position', [320 100 350 120], ...
    'Side', 'right', 'Orientation', 'right');
add_block('nesl_utility/Connection Port', [fc '/DC_Minus'], ...
    'Position', [320 260 350 280], ...
    'Side', 'right', 'Orientation', 'right');

% Internal wiring
add_line(fc, 'I_fc_in/1',       'SPS_Ifc/1');
safe_connect(fc, 'SPS_Ifc/RConn1',   'CCS_FC/RConn1');     % signal
safe_connect(fc, 'CCS_FC/LConn1',    'DC_Plus/RConn1');     % (+) → DC+
safe_connect(fc, 'CCS_FC/RConn2',    'GND_FC/LConn1');      % (-) → GND
safe_connect(fc, 'GND_FC/LConn1',    'DC_Minus/RConn1');    % GND → DC-

% Connect top-level I_fc signal → FC subsystem Inport
add_line(mdl, [wt_prefix '_Isat/1'], 'FC_System/1');

fprintf('FC_System built: 20kW PEMFC average model, EMS-controlled via FC_cmd\n');

end

function delete_subsystem_contents(subsys)
    lines = find_system(subsys, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
    for i = 1:length(lines)
        try delete_line(lines(i)); catch, end
    end
    blocks = find_system(subsys, 'SearchDepth', 1, 'Type', 'block');
    for i = 1:length(blocks)
        if ~strcmp(blocks{i}, subsys)
            try delete_block(blocks{i}); catch, end
        end
    end
end
