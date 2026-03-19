function build_battery_system(mdl)
%BUILD_BATTERY_SYSTEM Add Battery subsystem with Simscape physical blocks.
%
% Builds inside the existing Battery_System subsystem:
%   - Simscape Battery block (Li-ion, Rint model)
%   - 200 kWh / 100 kW, LiFePO4, 512V/400Ah
%   - Bidirectional Buck-Boost DC/DC converter (2 switches + L)
%   - PI controller for DC bus voltage regulation
%   - SOC via Coulomb counting (Eq.17)
%
% Port conventions (discovered from MATLAB R2025a):
%   Voltage Sensor:  LConn1(+ elec), RConn1(V signal), RConn2(- elec)
%   Current Sensor:  LConn1(in elec), RConn1(I signal), RConn2(out elec)
%   Switch:          LConn1(term1 elec), RConn1(gate signal), RConn2(term2 elec)
%
% Based on: Prattico et al. (2025), Eq. 17, Eq. 18

if nargin < 1
    mdl = 'prattico_simscape_phase_b';
end

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);

bat = [mdl '/Battery_System'];

% Clean existing content
delete_subsystem_contents(bat);

%% ========== Battery Block ==========
% LiFePO4, 160s x 3.2V = 512V, 400 Ah, 200 kWh
bat_path = find_block('Battery', { ...
    'ee_lib/Sources/Battery', ...
    'ee/Sources/Battery', ...
    'fl_lib/Electrical/Electrical Sources/Battery'});

add_block(bat_path, [bat '/Battery'], ...
    'Position', [100 150 160 250]);

try_set_param([bat '/Battery'], {'Vnom'}, '512');
try_set_param([bat '/Battery'], {'AH'}, '400');
try_set_param([bat '/Battery'], {'V1'}, '480');
try_set_param([bat '/Battery'], {'AH1'}, '360');
try_set_param([bat '/Battery'], {'R1'}, '0.04');
try_set_param([bat '/Battery'], {'SOC'}, '60');

% Discover Battery ports (may differ from other blocks)
discover_ports([bat '/Battery']);

%% ========== Sensors ==========
% Current Sensor (series with battery +)
add_block('fl_lib/Electrical/Electrical Sensors/Current Sensor', ...
    [bat '/I_bat_Sensor'], ...
    'Position', [250 150 290 230]);

add_block('nesl_utility/PS-Simulink Converter', [bat '/PS_Ibat'], ...
    'Position', [320 250 360 280]);

% Voltage Sensor (across battery terminals)
add_block('fl_lib/Electrical/Electrical Sensors/Voltage Sensor', ...
    [bat '/V_bat_Sensor'], ...
    'Position', [150 280 190 360]);

add_block('nesl_utility/PS-Simulink Converter', [bat '/PS_Vbat'], ...
    'Position', [230 320 270 350]);

%% ========== SOC Estimation (Coulomb counting, Eq.17) ==========
% SOC(t) = SOC_init - (100 / (Q_rated_Ah * 3600)) * integral(I_bat dt)
% Positive I_bat = discharge -> SOC decreases

add_block('simulink/Math Operations/Gain', [bat '/SOC_Gain'], ...
    'Position', [350 250 380 280], ...
    'Gain', num2str(-100 / (400 * 3600)));  % -100/(400Ah * 3600s)

add_block('simulink/Continuous/Integrator', [bat '/SOC_Integrator'], ...
    'Position', [400 250 440 280], ...
    'InitialCondition', '60', ...
    'UpperSaturationLimit', '100', ...
    'LowerSaturationLimit', '0');

add_block('simulink/Signal Routing/Goto', [bat '/Goto_SOC'], ...
    'Position', [470 250 530 270], ...
    'GotoTag', 'SOC_batt', ...
    'TagVisibility', 'global');

add_block('simulink/Sinks/To Workspace', [bat '/Log_SOC'], ...
    'Position', [470 290 530 310], ...
    'VariableName', 'SOC_batt', ...
    'SaveFormat', 'Timeseries');

%% ========== Bidirectional Buck-Boost Converter ==========
% Boost (discharge): Battery -> DC Bus
% Buck (charge): DC Bus -> Battery

% Inductor
add_block('fl_lib/Electrical/Electrical Elements/Inductor', ...
    [bat '/L_bidi'], ...
    'Position', [350 150 390 190], ...
    'l', '3e-3', ...                 % 3 mH
    'i', '0');

% High-side switch (boost mode)
switch_path = find_block('Switch', { ...
    'fl_lib/Electrical/Electrical Elements/Switch', ...
    'ee_lib/Semiconductors & Converters/Switches & Breakers/Ideal Semiconductor Switch', ...
    'ee/Semiconductors & Converters/Switches & Breakers/Ideal Semiconductor Switch'});

add_block(switch_path, [bat '/SW_high'], ...
    'Position', [450 120 490 170]);
add_block(switch_path, [bat '/SW_low'], ...
    'Position', [450 220 490 270]);

discover_ports([bat '/SW_high']);

%% ========== PI Controller for DC Bus Voltage ==========
% Error = Vdc_ref (750V) - Vdc_measured -> PI -> D

add_block('simulink/Sources/Constant', [bat '/Vdc_ref'], ...
    'Position', [100 400 130 420], ...
    'Value', '750');

add_block('simulink/Signal Routing/From', [bat '/From_Vdc'], ...
    'Position', [100 450 140 470], ...
    'GotoTag', 'Vdc_bus');

% Low-pass filter to break algebraic loop AND filter PWM noise on Vdc
% State-space form of H(s) = 1/(tau*s + 1), tau = 1ms
% Equivalent to Transfer Fcn but supports X0 (initial state)
% A=-1/tau, B=1/tau, C=1, D=0 → identical 1st-order LPF
add_block('simulink/Continuous/State-Space', [bat '/Vdc_LPF'], ...
    'Position', [145 450 185 470], ...
    'A', '-200', ...                % -1/tau, tau=5ms (filters 10kHz switching ripple)
    'B', '200', ...                 % 1/tau
    'C', '1', ...
    'D', '0', ...
    'X0', '750');                   % Start at nominal Vdc — no startup transient

add_block('simulink/Math Operations/Sum', [bat '/Vdc_Error'], ...
    'Position', [180 420 210 450], ...
    'Inputs', '+-');

add_block('simulink/Continuous/PID Controller', [bat '/PI_Vdc'], ...
    'Position', [250 415 310 455], ...
    'Controller', 'PI', ...
    'P', '0.0001', ...               % Best result: mean=752.5V
    'I', '0.02', ...                  % ~3Hz bandwidth, stable
    'UpperSaturationLimit', '0.45', ...  % D_low max → Vbus_max = 931V
    'LowerSaturationLimit', '0.05', ...
    'InitialConditionForIntegrator', '0.32');  % D_low_ss ≈ 0.317

%% ========== PWM Generator (10 kHz) ==========
% Gate ON when D > triangle

add_block('simulink/Sources/Repeating Sequence', [bat '/Triangle_PWM'], ...
    'Position', [350 450 390 480], ...
    'rep_seq_t', '[0 5e-5 1e-4]', ...
    'rep_seq_y', '[0 1 0]');

% Sum: D - Triangle
add_block('simulink/Math Operations/Sum', [bat '/PWM_Diff'], ...
    'Position', [420 420 440 450], ...
    'Inputs', '+-');

% Compare: (D - triangle) > 0
add_block('simulink/Logic and Bit Operations/Compare To Zero', ...
    [bat '/PWM_Hi'], ...
    'Position', [460 420 500 450], ...
    'relop', '>');

% NOT for complementary low-side gate
add_block('simulink/Logic and Bit Operations/Logical Operator', ...
    [bat '/NOT_gate'], ...
    'Position', [460 470 500 500], ...
    'Operator', 'NOT');

% Bool -> Double converters
add_block('simulink/Signal Attributes/Data Type Conversion', ...
    [bat '/Bool2Dbl_Hi'], ...
    'Position', [520 420 560 450], ...
    'OutDataTypeStr', 'double');

add_block('simulink/Signal Attributes/Data Type Conversion', ...
    [bat '/Bool2Dbl_Lo'], ...
    'Position', [520 470 560 500], ...
    'OutDataTypeStr', 'double');

% Simulink-PS Converters for gate signals
% CRITICAL: Disable default filter! Without this, the SPS converter smooths
% the 10kHz PWM square wave into a DC average (~0.32), which stays below
% the Switch threshold (0.5) → switch NEVER toggles → no boost/buck.
add_block('nesl_utility/Simulink-PS Converter', [bat '/SPS_GateHi'], ...
    'Position', [580 420 620 450]);
add_block('nesl_utility/Simulink-PS Converter', [bat '/SPS_GateLo'], ...
    'Position', [580 470 620 500]);

% Discover SPS filter params and current values
dp = get_param([bat '/SPS_GateHi'], 'DialogParameters');
fprintf('  SPS_GateHi DialogParameters:\n');
for fn = fieldnames(dp)'
    val = get_param([bat '/SPS_GateHi'], fn{1});
    if ischar(val), fprintf('    %s = %s\n', fn{1}, val); end
end
% Disable filtering completely — both order AND time constant
try
    set_param([bat '/SPS_GateHi'], 'SimscapeFilterOrder', '0');
    set_param([bat '/SPS_GateLo'], 'SimscapeFilterOrder', '0');
    fprintf('  [OK] SPS gate SimscapeFilterOrder = 0 (no filter)\n');
catch e1
    fprintf('  [WARN] SimscapeFilterOrder=0 failed: %s\n', e1.message);
end
try
    set_param([bat '/SPS_GateHi'], 'InputFilterTimeConstant', '1e-7');
    set_param([bat '/SPS_GateLo'], 'InputFilterTimeConstant', '1e-7');
    fprintf('  [OK] SPS gate InputFilterTimeConstant = 1e-7\n');
catch e2
    fprintf('  [WARN] InputFilterTimeConstant failed: %s\n', e2.message);
end
% Verify
filt_order = get_param([bat '/SPS_GateHi'], 'SimscapeFilterOrder');
filt_tau = get_param([bat '/SPS_GateHi'], 'InputFilterTimeConstant');
fprintf('  [VERIFY] SimscapeFilterOrder=%s, InputFilterTimeConstant=%s\n', filt_order, filt_tau);

%% ========== Power Calculation P_bat = V * I ==========
add_block('simulink/Math Operations/Product', [bat '/P_bat_calc'], ...
    'Position', [350 320 380 350], ...
    'Inputs', '2');

add_block('simulink/Signal Routing/Goto', [bat '/Goto_Pbat'], ...
    'Position', [420 320 480 340], ...
    'GotoTag', 'P_batt', ...
    'TagVisibility', 'global');

add_block('simulink/Sinks/To Workspace', [bat '/Log_Pbat'], ...
    'Position', [420 360 480 380], ...
    'VariableName', 'P_batt', ...
    'SaveFormat', 'Timeseries');

%% ========== Electrical Reference (local ground) ==========
add_block('fl_lib/Electrical/Electrical Elements/Electrical Reference', ...
    [bat '/GND_BAT'], ...
    'Position', [450 300 490 340]);

%% ========== Output Ports (Simscape connection to DC bus) ==========
add_block('nesl_utility/Connection Port', [bat '/DC_Plus'], ...
    'Position', [700 130 730 150], ...
    'Side', 'right');

add_block('nesl_utility/Connection Port', [bat '/DC_Minus'], ...
    'Position', [700 300 730 320], ...
    'Side', 'right');

%% ========== Wiring — Simulink signals ==========
% SOC: I_bat -> Gain -> Integrator -> Goto + Log
add_line(bat, 'PS_Ibat/1',       'SOC_Gain/1');
add_line(bat, 'SOC_Gain/1',      'SOC_Integrator/1');
add_line(bat, 'SOC_Integrator/1','Goto_SOC/1');
add_line(bat, 'SOC_Integrator/1','Log_SOC/1');

% P_bat = V_bat * I_bat
add_line(bat, 'PS_Vbat/1',       'P_bat_calc/1');
add_line(bat, 'PS_Ibat/1',       'P_bat_calc/2');
add_line(bat, 'P_bat_calc/1',    'Goto_Pbat/1');
add_line(bat, 'P_bat_calc/1',    'Log_Pbat/1');

% PI Controller: Vdc_ref - Vdc_meas(filtered) -> PI -> D
% LPF breaks algebraic loop: From_Vdc -> LPF(1ms) -> Vdc_Error
add_line(bat, 'Vdc_ref/1',       'Vdc_Error/1');
add_line(bat, 'From_Vdc/1',      'Vdc_LPF/1');
add_line(bat, 'Vdc_LPF/1',       'Vdc_Error/2');
add_line(bat, 'Vdc_Error/1',     'PI_Vdc/1');

% PI D -> PWM chain: D-triangle -> Compare>0 -> Bool2Dbl -> PS
add_line(bat, 'PI_Vdc/1',        'PWM_Diff/1');
add_line(bat, 'Triangle_PWM/1',  'PWM_Diff/2');
add_line(bat, 'PWM_Diff/1',      'PWM_Hi/1');

% High gate
add_line(bat, 'PWM_Hi/1',        'Bool2Dbl_Hi/1');
add_line(bat, 'Bool2Dbl_Hi/1',   'SPS_GateHi/1');

% Low gate (complementary)
add_line(bat, 'PWM_Hi/1',        'NOT_gate/1');
add_line(bat, 'NOT_gate/1',      'Bool2Dbl_Lo/1');
add_line(bat, 'Bool2Dbl_Lo/1',   'SPS_GateLo/1');

%% ========== Wiring — Simscape physical connections ==========
% Port names based on discover_ports (same block types as PV system):
%   Current Sensor: LConn1(in), RConn1(I signal), RConn2(out)
%   Voltage Sensor: LConn1(+), RConn1(V signal), RConn2(-)
%   Switch: LConn1(term1), RConn1(gate signal), RConn2(term2)
%
% Battery ports: discovered at runtime (may be LConn1=+, RConn1=-,
%   or different — safe_connect will diagnose).

% Battery + -> Current Sensor (series)
safe_connect(bat, 'Battery/LConn1',      'I_bat_Sensor/LConn1');
% Current Sensor out -> Inductor
safe_connect(bat, 'I_bat_Sensor/RConn2', 'L_bidi/LConn1');

% Battery - -> Ground
safe_connect(bat, 'Battery/RConn1',      'GND_BAT/LConn1');

% V_bat_Sensor across battery (+, -)
safe_connect(bat, 'Battery/LConn1',      'V_bat_Sensor/LConn1');
safe_connect(bat, 'Battery/RConn1',      'V_bat_Sensor/RConn2');

% Inductor -> midpoint -> SW_high (to DC+) and SW_low (to GND)
safe_connect(bat, 'L_bidi/RConn1',       'SW_high/LConn1');
safe_connect(bat, 'L_bidi/RConn1',       'SW_low/LConn1');

% SW_high terminal2 -> DC_Plus
safe_connect(bat, 'SW_high/RConn2',      'DC_Plus/RConn1');
% SW_low terminal2 -> Ground
safe_connect(bat, 'SW_low/RConn2',       'GND_BAT/LConn1');
% Ground -> DC_Minus
safe_connect(bat, 'GND_BAT/LConn1',      'DC_Minus/RConn1');

% Gate signals -> Switch gate inputs (RConn1 = gate)
% SWAPPED: PI output controls D_low (not D_high) for correct boost polarity
% V_bus = V_bat / (1 - D_low) → higher D_low → higher V_bus
safe_connect(bat, 'SPS_GateHi/RConn1',  'SW_low/RConn1');     % PI duty → low-side
safe_connect(bat, 'SPS_GateLo/RConn1',  'SW_high/RConn1');    % complement → high-side

% Sensor signal outputs -> PS-Simulink converters
safe_connect(bat, 'I_bat_Sensor/RConn1', 'PS_Ibat/LConn1');
safe_connect(bat, 'V_bat_Sensor/RConn1', 'PS_Vbat/LConn1');

%% ========== Annotation ==========
add_block('built-in/Note', [bat '/Note_BAT'], ...
    'Position', [100 50 550 100], ...
    'Text', sprintf(['Battery: LiFePO4 512V/400Ah (200 kWh), Rint model\n' ...
    'Bidirectional Buck-Boost: L=3mH, 10kHz PWM\n' ...
    'PI controller: Vdc_ref=750V\n' ...
    'SOC via Coulomb counting (Eq.17), init=60%%']));

fprintf('Battery_System built: 512V/400Ah + Buck-Boost + PI + SOC\n');
fprintf('NOTE: Battery port names discovered above — check for errors.\n');

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
