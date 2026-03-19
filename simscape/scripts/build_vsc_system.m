function build_vsc_system(mdl)
%BUILD_VSC_SYSTEM  VSC/PCC 150 kVA — Average model (Prattico §3.2.5, §3.3)
%
% Average-value model of the bidirectional AC/DC converter at PCC:
%   - Grid-connected mode: exchanges P_ref with grid (import/export)
%   - AC loads modeled as power consumption on DC bus (P_ac_total)
%   - Net exchange: P_grid = P_ac_loads - P_dc_generation_surplus
%
% For Phase F testing, P_ref_AC = constant (from EMS in Phase H).
% AC loads (residential 50kW + commercial 45kW) are included as power sinks.
%
% Paper specs (§3.3, Table 5, Figure 8):
%   - 150 kVA bidirectional VSC
%   - 400V L-L, 50Hz AC side
%   - Grid-following (connected) / Grid-forming (islanded)
%   - dq frame control with PI regulators
%
% Based on: Prattico et al. (2025) §3.2.5, §3.3, Figure 8

fprintf('  Building VSC/PCC + AC Loads (average model)...\n');

%% ========== AC Load Profiles (Figure 10b,c — §4.3) ==========
% Residential AC: 12 households, PF≈1, evening peak 50kW
% Time [s] = hour (24h compressed to 24s)
t_res = [0  7  9  11  14  19  22  24];
p_res = [10 10 30 40  30  50  45  10] * 1e3;  % W

% Commercial AC: 2 SMEs, PF=0.9, daytime 45kW peak
t_com = [0  7  8  12  13  18  20  24];
p_com = [5  5  35 35  45  35  15  5] * 1e3;  % W (active only)
q_com = p_com * tan(acos(0.9));  % Reactive power at PF=0.9

fprintf('  AC Residential: %.0f-%.0f kW\n', min(p_res)/1e3, max(p_res)/1e3);
fprintf('  AC Commercial:  %.0f-%.0f kW (PF=0.9)\n', min(p_com)/1e3, max(p_com)/1e3);

%% ========== TOP LEVEL: AC Load profiles + Grid exchange ==========
% Residential load profile
add_block('simulink/Sources/Repeating Sequence Interpolated', ...
    [mdl '/AC_Res_Profile'], ...
    'Position', [50 850 110 880], ...
    'OutValues', mat2str(p_res), ...
    'TimeValues', mat2str(t_res));

% Commercial load profile
add_block('simulink/Sources/Repeating Sequence Interpolated', ...
    [mdl '/AC_Com_Profile'], ...
    'Position', [50 900 110 930], ...
    'OutValues', mat2str(p_com), ...
    'TimeValues', mat2str(t_com));

% Total AC load = residential + commercial
add_block('simulink/Math Operations/Sum', [mdl '/AC_Total'], ...
    'Position', [150 870 180 910], 'Inputs', '++');

% Log AC loads
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Pac'], ...
    'Position', [220 895 280 915], ...
    'VariableName', 'P_ac_load', ...
    'SaveFormat', 'Timeseries');

% The VSC transfers AC load power FROM the DC bus (power sink on DC side)
% Plus grid import/export. For Phase F: P_grid = 0 (no EMS yet).
% Net current drawn from DC bus: I_ac = P_ac_total / V_dc

% Grid power reference (from EMS in Phase H, constant 0 for now)
add_block('simulink/Sources/Constant', [mdl '/P_grid_ref'], ...
    'Position', [50 940 80 960], ...
    'Value', '0');  % No grid exchange in Phase F

% Total power to draw: P_ac_loads + P_grid (positive = draw from DC bus)
add_block('simulink/Math Operations/Sum', [mdl '/VSC_Ptotal'], ...
    'Position', [150 920 180 950], 'Inputs', '++');

% I_vsc = P_total / V_dc (current drawn from DC bus)
add_block('simulink/Signal Routing/From', [mdl '/VSC_From_Vdc'], ...
    'Position', [120 970 160 990], 'GotoTag', 'Vdc_bus');

add_block('simulink/Continuous/State-Space', [mdl '/VSC_Vdc_LPF'], ...
    'Position', [180 970 220 990], ...
    'A', '-200', 'B', '200', 'C', '1', 'D', '0', 'X0', '750');

add_block('simulink/Math Operations/MinMax', [mdl '/VSC_Vdc_clamp'], ...
    'Position', [240 968 270 995], 'Function', 'max', 'Inputs', '2');
add_block('simulink/Sources/Constant', [mdl '/VSC_Vdc_min'], ...
    'Position', [200 1000 230 1015], 'Value', '400');

add_block('simulink/Math Operations/Divide', [mdl '/VSC_Idiv'], ...
    'Position', [300 920 330 960]);

% Saturation: max 200A (150kVA / 750V)
add_block('simulink/Discontinuities/Saturation', [mdl '/VSC_Isat'], ...
    'Position', [350 925 390 955], ...
    'UpperLimit', '200', 'LowerLimit', '-200');  % Bidirectional!

% Log grid power
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Pgrid'], ...
    'Position', [220 945 280 965], ...
    'VariableName', 'P_grid', ...
    'SaveFormat', 'Timeseries');

% Wire signal chain
add_line(mdl, 'AC_Res_Profile/1', 'AC_Total/1');
add_line(mdl, 'AC_Com_Profile/1', 'AC_Total/2');
add_line(mdl, 'AC_Total/1',       'Log_Pac/1');
add_line(mdl, 'AC_Total/1',       'VSC_Ptotal/1');
add_line(mdl, 'P_grid_ref/1',     'VSC_Ptotal/2');
add_line(mdl, 'P_grid_ref/1',     'Log_Pgrid/1');
add_line(mdl, 'VSC_Ptotal/1',     'VSC_Idiv/1');       % P_total → numerator
add_line(mdl, 'VSC_From_Vdc/1',   'VSC_Vdc_LPF/1');
add_line(mdl, 'VSC_Vdc_LPF/1',    'VSC_Vdc_clamp/1');
add_line(mdl, 'VSC_Vdc_min/1',    'VSC_Vdc_clamp/2');
add_line(mdl, 'VSC_Vdc_clamp/1',  'VSC_Idiv/2');       % Vdc → denominator
add_line(mdl, 'VSC_Idiv/1',       'VSC_Isat/1');

%% ========== VSC Subsystem: Controlled Current Source (draws from DC bus) ==========
vsc = [mdl '/VSC_System'];

% Delete existing contents
delete_subsystem_contents(vsc);

% Inport for current signal
add_block('simulink/Sources/In1', [vsc '/I_vsc_in'], ...
    'Position', [50 105 80 125]);

% Negate current: VSC DRAWS from bus (positive P = positive I drawn)
% CCS convention: current flows from (+) to (-) internally
% To draw from bus: bus(+) → CCS(+), CCS(-) → GND
% Control signal positive = draws current from bus
add_block('simulink/Math Operations/Gain', [vsc '/Negate'], ...
    'Position', [100 105 130 125], 'Gain', '1');

% Simulink-PS Converter
add_block('nesl_utility/Simulink-PS Converter', [vsc '/SPS_Ivsc'], ...
    'Position', [160 105 190 130]);

% Controlled Current Source (draws power from DC bus for AC loads)
add_block('fl_lib/Electrical/Electrical Sources/Controlled Current Source', ...
    [vsc '/CCS_VSC'], ...
    'Position', [240 80 280 160]);

% Electrical Reference
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', ...
    [vsc '/GND_VSC'], ...
    'Position', [240 250 280 290]);

% Connection Ports
add_block('nesl_utility/Connection Port', [vsc '/DC_Plus'], ...
    'Position', [360 90 390 110], 'Side', 'right');
add_block('nesl_utility/Connection Port', [vsc '/DC_Minus'], ...
    'Position', [360 260 390 280], 'Side', 'right');

% Internal wiring
add_line(vsc, 'I_vsc_in/1',      'Negate/1');
add_line(vsc, 'Negate/1',         'SPS_Ivsc/1');
safe_connect(vsc, 'SPS_Ivsc/RConn1',  'CCS_VSC/RConn1');   % signal
safe_connect(vsc, 'CCS_VSC/LConn1',   'DC_Plus/RConn1');    % (+)
safe_connect(vsc, 'CCS_VSC/RConn2',   'GND_VSC/LConn1');    % (-)
safe_connect(vsc, 'GND_VSC/LConn1',   'DC_Minus/RConn1');   % GND → DC-

% Connect top-level signal → VSC subsystem
add_line(mdl, 'VSC_Isat/1', 'VSC_System/1');

% Connect to DC bus
try
    add_line(mdl, 'VSC_System/RConn1', 'DC_Bus_Cap/LConn1');
    fprintf('  VSC DC+ -> DC Bus [connected]\n');
catch e
    fprintf('  [WARN] VSC DC+: %s\n', e.message);
end
try
    add_line(mdl, 'VSC_System/RConn2', 'Electrical Reference/LConn1');
    fprintf('  VSC DC- -> Ground [connected]\n');
catch e
    fprintf('  [WARN] VSC DC-: %s\n', e.message);
end

fprintf('  VSC_System built: 150kVA average model (AC loads as DC power sink)\n');
fprintf('  AC Loads: residential(%.0fkW) + commercial(%.0fkW)\n', ...
    max(p_res)/1e3, max(p_com)/1e3);

end

function delete_subsystem_contents(subsys)
    lines = find_system(subsys, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
    for i = 1:length(lines), try delete_line(lines(i)); catch, end, end
    blocks = find_system(subsys, 'SearchDepth', 1, 'Type', 'block');
    for i = 1:length(blocks)
        if ~strcmp(blocks{i}, subsys), try delete_block(blocks{i}); catch, end, end
    end
end
