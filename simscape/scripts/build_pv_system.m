function build_pv_system(mdl)
%BUILD_PV_SYSTEM Add PV subsystem with Simscape physical blocks.
%
% Builds inside the existing PV_System subsystem:
%   - Solar Cell block (single-diode model, Eq.8)
%   - Array: 12 series x 23 parallel = 276 modules (~150 kWp)
%   - Boost converter: Inductor + Diode + Switch + Capacitor
%   - Constant D=0.4 for initial testing (MPPT to be added later)
%   - PWM generator (D vs triangle wave) for switch gate
%
% Port conventions (discovered from MATLAB R2025a):
%   Solar Cell:      LConn1(Ir signal), LConn2(+ elec), RConn1(- elec)
%   Voltage Sensor:  LConn1(+ elec), RConn1(V signal), RConn2(- elec)
%   Current Sensor:  LConn1(in elec), RConn1(I signal), RConn2(out elec)
%   Switch:          LConn1(term1 elec), RConn1(gate signal), RConn2(term2 elec)
%   Diode:           LConn1(anode), RConn1(cathode)
%
% Based on: Prattico et al. (2025), Eq. 8-9, Eq. 18

if nargin < 1
    mdl = 'prattico_simscape_phase_b';
end

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);

pv = [mdl '/PV_System'];

% Clean existing content inside placeholder subsystem
delete_subsystem_contents(pv);

%% ========== PV Array (Solar Cell block) ==========
% Single-diode model (Eq.8):
%   I = Iph - I0*(exp(q*(V+I*Rs)/(n*k*T)) - 1) - (V+I*Rs)/Rsh
% Array: 12 series x 23 parallel = 276 modules * 550W = 151.8 kWp

solar_path = find_block('Solar Cell', { ...
    'ee_lib/Sources/Solar Cell', ...
    'ee/Sources/Solar Cell', ...
    'fl_lib/Electrical/Electrical Sources/Solar Cell'});

add_block(solar_path, [pv '/Solar_Cell'], ...
    'Position', [100 150 160 250]);

% --- Solar Cell parameterization ---
% The block uses PER-CELL parameters. N_series/N_parallel scale the array.
% Default per-cell: Voc=0.6V, Isc=7.34A, Is=1e-6A, ec=1.5
%
% For 12 modules (72 cells each) in series, 23 parallel:
%   N_series = 864 cells (12 × 72), N_parallel = 23
%   Array Voc = 864 × 0.6 = 518V, Vmpp ~430V
%   With D=0.4: V_out = 430/0.6 = 717V (close to 750V)
%
% Phase B: use DEFAULT per-cell params, only set array config.
% Custom JinkoSolar params to be added after model validates.
sc_block = [pv '/Solar_Cell'];

set_param(sc_block, 'N_series',  '864');    % 12 modules × 72 cells/module
set_param(sc_block, 'N_parallel','23');     % 23 parallel strings

% Print prm mode and Is to verify defaults are valid
fprintf('  prm = '); disp(get_param(sc_block, 'prm'));
fprintf('  Is = %s, Isc = %s, Voc = %s\n', ...
    get_param(sc_block, 'Is'), ...
    get_param(sc_block, 'Isc'), ...
    get_param(sc_block, 'Voc'));

% Print actual ports
discover_ports(sc_block);

%% ========== Irradiance Input ==========
% Solar Cell has NO temperature port (only 3 ports: Ir, +, -)
% Temperature is set as a block parameter, not a dynamic input.
add_block('simulink/Sources/Constant', [pv '/G_STC'], ...
    'Position', [30 170 60 190], ...
    'Value', '1000');                % 1000 W/m² STC

add_block('nesl_utility/Simulink-PS Converter', [pv '/SPS_Irr'], ...
    'Position', [30 220 70 250]);

%% ========== Sensors (PV output V and I) ==========
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', ...
    [pv '/V_pv_Sensor'], ...
    'Position', [250 150 290 230]);

add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor', ...
    [pv '/I_pv_Sensor'], ...
    'Position', [330 150 370 230]);

% PS-Simulink converters for sensor signal outputs
add_block('nesl_utility/PS-Simulink Converter', [pv '/PS_Vpv'], ...
    'Position', [320 270 360 300]);
add_block('nesl_utility/PS-Simulink Converter', [pv '/PS_Ipv'], ...
    'Position', [400 270 440 300]);

%% ========== Power Calculation P = V * I ==========
add_block('simulink/Math Operations/Product', [pv '/P_pv_calc'], ...
    'Position', [470 260 500 290], ...
    'Inputs', '2');

add_block('simulink/Signal Routing/Goto', [pv '/Goto_Ppv'], ...
    'Position', [530 260 590 280], ...
    'GotoTag', 'P_pv', ...
    'TagVisibility', 'global');

add_block('simulink/Sinks/To Workspace', [pv '/Log_Ppv'], ...
    'Position', [530 300 590 320], ...
    'VariableName', 'P_pv', ...
    'SaveFormat', 'Timeseries');

%% ========== Boost Converter (PV -> DC Bus) ==========
% V_out = V_in / (1 - D)  [Eq. 18]
% D = 0.4 -> V_in ~ 450V -> V_out ~ 750V

add_block('fl_lib/Electrical/Electrical Elements/Inductor', ...
    [pv '/L_boost'], ...
    'Position', [450 150 490 190], ...
    'l', '2e-3', ...                 % 2 mH
    'i', '0');

diode_path = find_block('Diode', { ...
    'fl_lib/Electrical/Electrical Elements/Diode', ...
    'ee_lib/Semiconductors & Converters/Diodes/Diode', ...
    'ee/Semiconductors & Converters/Diodes/Diode'});
add_block(diode_path, [pv '/D_boost'], ...
    'Position', [550 120 590 160]);

switch_path = find_block('Switch', { ...
    'fl_lib/Electrical/Electrical Elements/Switch', ...
    'ee_lib/Semiconductors & Converters/Switches & Breakers/Ideal Semiconductor Switch', ...
    'ee/Semiconductors & Converters/Switches & Breakers/Ideal Semiconductor Switch'});
add_block(switch_path, [pv '/IGBT_boost'], ...
    'Position', [550 200 590 250]);

discover_ports([pv '/IGBT_boost']);

% Output capacitor
add_block('fl_lib/Electrical/Electrical Elements/Capacitor', ...
    [pv '/C_out'], ...
    'Position', [650 150 690 230], ...
    'c', '470e-6', ...               % 470 uF
    'v', '750');                      % Init 750V

%% ========== Duty Cycle (constant D=0.4 for Phase B) ==========
% Replaces MPPT for initial testing. MPPT P&O to be added later.
% D=0.4: V_out = V_in/(1-0.4) = 450V/0.6 = 750V
add_block('simulink/Sources/Constant', [pv '/D_const'], ...
    'Position', [350 380 380 400], ...
    'Value', '0.4');

%% ========== PWM Generator (10 kHz) ==========
% Gate ON when D > triangle value
add_block('simulink/Sources/Repeating Sequence', [pv '/Triangle_PWM'], ...
    'Position', [350 430 390 460], ...
    'rep_seq_t', '[0 5e-5 1e-4]', ...
    'rep_seq_y', '[0 1 0]');

add_block('simulink/Math Operations/Sum', [pv '/PWM_Diff'], ...
    'Position', [420 400 440 430], ...
    'Inputs', '+-');

add_block('simulink/Logic and Bit Operations/Compare To Zero', ...
    [pv '/PWM_Compare'], ...
    'Position', [460 400 500 430], ...
    'relop', '>');

add_block('simulink/Signal Attributes/Data Type Conversion', ...
    [pv '/Bool2Dbl'], ...
    'Position', [520 400 560 430], ...
    'OutDataTypeStr', 'double');

add_block('nesl_utility/Simulink-PS Converter', [pv '/SPS_Gate'], ...
    'Position', [580 400 620 430]);
% Disable SPS filter so PWM square wave passes through to Switch gate
try
    set_param([pv '/SPS_Gate'], 'SimscapeFilterOrder', '0');
    set_param([pv '/SPS_Gate'], 'InputFilterTimeConstant', '1e-7');
    fprintf('  [OK] PV SPS gate filter: order=0, tau=1e-7\n');
catch e
    fprintf('  [WARN] PV SPS filter config failed: %s\n', e.message);
end

%% ========== Electrical Reference (local ground) ==========
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', ...
    [pv '/GND_PV'], ...
    'Position', [550 300 590 340]);

%% ========== Output Ports (Simscape connection to DC bus) ==========
add_block('nesl_utility/Connection Port', [pv '/DC_Plus'], ...
    'Position', [750 150 780 170], ...
    'Side', 'right');

add_block('nesl_utility/Connection Port', [pv '/DC_Minus'], ...
    'Position', [750 300 780 320], ...
    'Side', 'right');

%% ========== Wiring — Simulink signals ==========
% Irradiance constant -> Simulink-PS converter
add_line(pv, 'G_STC/1',         'SPS_Irr/1');

% Sensor signals -> Power calculation
add_line(pv, 'PS_Vpv/1',        'P_pv_calc/1');
add_line(pv, 'PS_Ipv/1',        'P_pv_calc/2');
add_line(pv, 'P_pv_calc/1',     'Goto_Ppv/1');
add_line(pv, 'P_pv_calc/1',     'Log_Ppv/1');

% PWM chain: D -> Sum(D-tri) -> Compare>0 -> Bool2Dbl -> PS -> Gate
add_line(pv, 'D_const/1',       'PWM_Diff/1');
add_line(pv, 'Triangle_PWM/1',  'PWM_Diff/2');
add_line(pv, 'PWM_Diff/1',      'PWM_Compare/1');
add_line(pv, 'PWM_Compare/1',   'Bool2Dbl/1');
add_line(pv, 'Bool2Dbl/1',      'SPS_Gate/1');

%% ========== Wiring — Simscape physical connections ==========
% All use safe_connect for auto-diagnosis on failure.
%
% Corrected port names based on discover_ports output:
%   Solar Cell:  LConn1=Ir(signal), LConn2=+(elec), RConn1=-(elec)
%   V Sensor:    LConn1=+(elec), RConn1=V(signal), RConn2=-(elec)
%   I Sensor:    LConn1=in(elec), RConn1=I(signal), RConn2=out(elec)
%   Switch:      LConn1=term1(elec), RConn1=gate(signal), RConn2=term2(elec)

% --- Irradiance input ---
safe_connect(pv, 'SPS_Irr/RConn1',      'Solar_Cell/LConn1');

% --- Solar Cell electrical ---
safe_connect(pv, 'Solar_Cell/LConn2',    'I_pv_Sensor/LConn1');
safe_connect(pv, 'Solar_Cell/LConn2',    'V_pv_Sensor/LConn1');
safe_connect(pv, 'Solar_Cell/RConn1',    'GND_PV/LConn1');

% --- Voltage Sensor ---
safe_connect(pv, 'V_pv_Sensor/RConn2',  'GND_PV/LConn1');
safe_connect(pv, 'V_pv_Sensor/RConn1',  'PS_Vpv/LConn1');

% --- Current Sensor ---
safe_connect(pv, 'I_pv_Sensor/RConn2',  'L_boost/LConn1');
safe_connect(pv, 'I_pv_Sensor/RConn1',  'PS_Ipv/LConn1');

% --- Boost converter ---
safe_connect(pv, 'L_boost/RConn1',      'D_boost/LConn1');
safe_connect(pv, 'L_boost/RConn1',      'IGBT_boost/LConn1');
safe_connect(pv, 'IGBT_boost/RConn2',   'GND_PV/LConn1');
safe_connect(pv, 'D_boost/RConn1',      'C_out/LConn1');
safe_connect(pv, 'C_out/LConn1',        'DC_Plus/RConn1');
safe_connect(pv, 'C_out/RConn1',        'GND_PV/LConn1');
safe_connect(pv, 'GND_PV/LConn1',       'DC_Minus/RConn1');

% --- Gate signal ---
safe_connect(pv, 'SPS_Gate/RConn1',     'IGBT_boost/RConn1');

%% ========== Annotation ==========
add_block('built-in/Note', [pv '/Note_PV'], ...
    'Position', [100 50 500 100], ...
    'Text', sprintf(['PV Array: 12s x 23p = 276 modules (151.8 kWp)\n' ...
    'Single-diode model (Eq.8), JinkoSolar 550W proxy\n' ...
    'Boost: L=2mH, C=470uF, PWM 10kHz, D=0.4 (constant)\n' ...
    'TODO: Replace D_const with MPPT P&O controller']));

fprintf('PV_System built: 12s x 23p Solar Cell + Boost (D=0.4 constant)\n');

end

%% ========== Local Helper Functions ==========

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

function path = find_block(name, candidates)
    for i = 1:length(candidates)
        try
            get_param(candidates{i}, 'BlockType');
            path = candidates{i};
            fprintf('  [FOUND] "%s" at: %s\n', name, path);
            return;
        catch
        end
    end
    % Fallback: use first candidate (add_block will load library)
    path = candidates{1};
    fprintf('  [INFO] "%s" — using: %s (library not pre-loaded)\n', name, path);
end

function try_set_param(block, names, value)
    if ischar(names), names = {names}; end
    for i = 1:length(names)
        try
            set_param(block, names{i}, value);
            return;
        catch
        end
    end
    fprintf('  [WARN] Could not set param {%s} = %s on %s\n', ...
        strjoin(names, '/'), value, block);
end
