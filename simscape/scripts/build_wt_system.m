function build_wt_system(mdl)
%BUILD_WT_SYSTEM  Wind Turbine 60 kW — Average model (Prattico §3.2.2)
%
% Simulink signal chain at TOP LEVEL (avoids subsystem boundary issues):
%   Wind_Speed → P_wt → I_wt = P_wt/Vdc → [WT subsystem Inport]
%
% WT subsystem (physical only):
%   Inport(I_wt) → SPS → Controlled Current Source → DC bus
%
% Based on: Prattico et al. (2025) §3.2.2, Table 5, Figure 4

wt = [mdl '/WT_System'];

% Delete existing contents
delete_subsystem_contents(wt);

%% ========== Parameters ==========
rho       = 1.225;
P_rated   = 60e3;
v_cutin   = 4;
v_rated   = 12;
v_cutout  = 25;
Cp_rated  = 0.45;
eta_conv  = 0.92;

A_rotor = P_rated / (0.5 * rho * v_rated^3 * Cp_rated);
k_wt = 0.5 * rho * A_rotor * Cp_rated * eta_conv;
fprintf('  WT: A=%.0fm², k_wt=%.2f, P_max=%.0fW\n', A_rotor, k_wt, P_rated*eta_conv);

%% ========== TOP LEVEL: Simulink signal chain ==========
% Wind Speed constant
add_block('simulink/Sources/Constant', [mdl '/WT_Wind_Speed'], ...
    'Position', [50 550 80 570], ...
    'Value', num2str(v_rated));

% v² and v³
add_block('simulink/Math Operations/Product', [mdl '/WT_V2'], ...
    'Position', [120 545 150 575], 'Inputs', '**');
add_block('simulink/Math Operations/Product', [mdl '/WT_V3'], ...
    'Position', [170 545 200 580], 'Inputs', '**');

% Gain: k_wt × v³
add_block('simulink/Math Operations/Gain', [mdl '/WT_K'], ...
    'Position', [220 548 260 572], ...
    'Gain', num2str(k_wt));

% Saturation: [0, P_rated × eta]
add_block('simulink/Discontinuities/Saturation', [mdl '/WT_Psat'], ...
    'Position', [280 548 320 572], ...
    'UpperLimit', num2str(P_rated * eta_conv), ...
    'LowerLimit', '0');

% Log P_wt
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Pwt'], ...
    'Position', [340 580 400 600], ...
    'VariableName', 'P_wt', ...
    'SaveFormat', 'Timeseries');

% I_wt = P_wt / Vdc (with LPF + clamp on Vdc)
add_block('simulink/Signal Routing/From', [mdl '/WT_From_Vdc'], ...
    'Position', [220 610 260 630], ...
    'GotoTag', 'Vdc_bus');

add_block('simulink/Continuous/State-Space', [mdl '/WT_Vdc_LPF'], ...
    'Position', [280 610 320 630], ...
    'A', '-200', 'B', '200', 'C', '1', 'D', '0', 'X0', '750');

add_block('simulink/Math Operations/MinMax', [mdl '/WT_Vdc_clamp'], ...
    'Position', [340 608 370 635], 'Function', 'max', 'Inputs', '2');
add_block('simulink/Sources/Constant', [mdl '/WT_Vdc_min'], ...
    'Position', [300 640 330 655], 'Value', '400');

add_block('simulink/Math Operations/Divide', [mdl '/WT_Idiv'], ...
    'Position', [400 545 430 590]);

add_block('simulink/Discontinuities/Saturation', [mdl '/WT_Isat'], ...
    'Position', [450 548 490 582], ...
    'UpperLimit', num2str(P_rated / 400), 'LowerLimit', '0');

% Wire top-level signal chain
add_line(mdl, 'WT_Wind_Speed/1', 'WT_V2/1');
add_line(mdl, 'WT_Wind_Speed/1', 'WT_V2/2');
add_line(mdl, 'WT_V2/1',         'WT_V3/1');
add_line(mdl, 'WT_Wind_Speed/1', 'WT_V3/2');
add_line(mdl, 'WT_V3/1',         'WT_K/1');
add_line(mdl, 'WT_K/1',          'WT_Psat/1');
add_line(mdl, 'WT_Psat/1',       'Log_Pwt/1');
add_line(mdl, 'WT_Psat/1',       'WT_Idiv/1');     % P_wt → numerator
add_line(mdl, 'WT_From_Vdc/1',   'WT_Vdc_LPF/1');
add_line(mdl, 'WT_Vdc_LPF/1',    'WT_Vdc_clamp/1');
add_line(mdl, 'WT_Vdc_min/1',    'WT_Vdc_clamp/2');
add_line(mdl, 'WT_Vdc_clamp/1',  'WT_Idiv/2');     % Vdc → denominator
add_line(mdl, 'WT_Idiv/1',       'WT_Isat/1');
% WT_Isat → WT_System Inport (connected below)

%% ========== WT SUBSYSTEM: Physical blocks only ==========
% Inport for current signal from top level
add_block('simulink/Sources/In1', [wt '/I_wt_in'], ...
    'Position', [50 105 80 125]);

% Simulink-PS Converter
add_block('nesl_utility/Simulink-PS Converter', [wt '/SPS_Iwt'], ...
    'Position', [120 105 150 130]);

% Controlled Current Source
ccs_path = 'fl_lib/Electrical/Electrical Sources/Controlled Current Source';
add_block(ccs_path, [wt '/CCS_WT'], ...
    'Position', [200 80 240 160]);

% Electrical Reference (local ground)
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', ...
    [wt '/GND_WT'], ...
    'Position', [200 250 240 290]);

% Connection Ports (DC+ and DC-)
add_block('nesl_utility/Connection Port', [wt '/DC_Plus'], ...
    'Position', [320 100 350 120], ...
    'Side', 'right', 'Orientation', 'right');
add_block('nesl_utility/Connection Port', [wt '/DC_Minus'], ...
    'Position', [320 260 350 280], ...
    'Side', 'right', 'Orientation', 'right');

% Internal wiring
add_line(wt, 'I_wt_in/1',       'SPS_Iwt/1');
safe_connect(wt, 'SPS_Iwt/RConn1',   'CCS_WT/RConn1');     % signal
safe_connect(wt, 'CCS_WT/LConn1',    'DC_Plus/RConn1');     % (+) → DC+
safe_connect(wt, 'CCS_WT/RConn2',    'GND_WT/LConn1');      % (-) → GND
safe_connect(wt, 'GND_WT/LConn1',    'DC_Minus/RConn1');    % GND → DC-

% Connect top-level I_wt signal → WT subsystem Inport
add_line(mdl, 'WT_Isat/1', 'WT_System/1');

fprintf('WT_System built: 60kW average model, CCS at DC bus\n');

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
