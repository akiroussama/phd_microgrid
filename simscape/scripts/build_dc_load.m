function build_dc_load(mdl)
%BUILD_DC_LOAD  Variable DC Load up to 15 kW (Prattico §3.2.6, Figure 7a)
%
% Replaces the fixed 100 ohm load from Phase B with a variable resistance
% driven by the DC load profile from Figure 10(a).
%
% Implementation (from Figure 7a):
%   R(t) = V_DC_rated² / P_load(t)
%   Using Repeating Sequence Interpolated for P_load profile
%
% Based on: Prattico et al. (2025) §3.2.6, §4.3, Figure 7(a), Figure 10(a)

fprintf('  Building DC Load (variable, up to 15 kW)...\n');

%% ========== DC Load Profile (Figure 10a) ==========
% 24h compressed to 24s (1h = 1s). Extracted from paper Figure 10(a).
% Time [s] = hour, Power [kW]
t_profile = [0  7  7.5  8.5  9   11   14   15   17   19   20   22   24];
p_profile = [1.5 1.5 6.0 12.0 12.0 12.0 15.0 12.0 10.0 6.0  3.0  1.5  1.5] * 1e3;  % W

% For short simulations (< 24s), use constant value at t=0.5s ≈ hour 0.5
% This is 1.5 kW (night). For a representative test, use ~10 kW (midday).
% The Repeating Sequence handles this automatically.

fprintf('  DC load profile: %d points, P_min=%.1fkW, P_max=%.1fkW\n', ...
    length(t_profile), min(p_profile)/1e3, max(p_profile)/1e3);

%% ========== Remove existing fixed DC_Load ==========
% Phase B skeleton created a fixed 100 ohm resistor named DC_Load
try
    % Remove the old fixed load and its connections
    old_load = [mdl '/DC_Load'];
    if ~isempty(find_system(mdl, 'SearchDepth', 1, 'Name', 'DC_Load'))
        % Delete lines connected to DC_Load
        ph = get_param(old_load, 'PortHandles');
        conns = get_param(old_load, 'PortConnectivity');
        for i = 1:length(conns)
            try delete_line(mdl, [conns(i).Type]); catch, end
        end
        % Try deleting all lines from/to the block
        lines = find_system(mdl, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
        for i = 1:length(lines)
            try
                src = get_param(lines(i), 'SrcBlockHandle');
                dst = get_param(lines(i), 'DstBlockHandle');
                blk_h = get_param(old_load, 'Handle');
                if src == blk_h || dst == blk_h
                    delete_line(lines(i));
                end
            catch
            end
        end
        delete_block(old_load);
        fprintf('  [OK] Old fixed DC_Load removed\n');
    end
catch e
    fprintf('  [WARN] Could not remove old DC_Load: %s\n', e.message);
end

%% ========== Top-level: Load power computation ==========
% P_load profile → R(t) = V_dc² / P_load(t)

% Load power profile (Repeating Sequence Interpolated)
add_block('simulink/Sources/Repeating Sequence Interpolated', ...
    [mdl '/DC_Load_Profile'], ...
    'Position', [50 750 110 780], ...
    'OutValues', mat2str(p_profile), ...
    'TimeValues', mat2str(t_profile));

% Log P_dc_load
add_block('simulink/Sinks/To Workspace', [mdl '/Log_Pdc_load'], ...
    'Position', [180 785 240 805], ...
    'VariableName', 'P_dc_load', ...
    'SaveFormat', 'Timeseries');

% V_dc² / P_load → R_load
add_block('simulink/Signal Routing/From', [mdl '/DCL_From_Vdc'], ...
    'Position', [50 810 90 830], ...
    'GotoTag', 'Vdc_bus');

% LPF on Vdc to avoid algebraic loop (same pattern as WT/FC)
add_block('simulink/Continuous/State-Space', [mdl '/DCL_Vdc_LPF'], ...
    'Position', [110 810 150 830], ...
    'A', '-200', 'B', '200', 'C', '1', 'D', '0', 'X0', '750');

% V² = Vdc × Vdc
add_block('simulink/Math Operations/Product', [mdl '/DCL_Vsq'], ...
    'Position', [170 808 200 835], 'Inputs', '**');

% R = V² / P_load
add_block('simulink/Math Operations/Divide', [mdl '/DCL_Rdiv'], ...
    'Position', [230 758 260 800]);

% Clamp R to [1, 1e6] (prevent R=0 or R=inf)
add_block('simulink/Discontinuities/Saturation', [mdl '/DCL_Rsat'], ...
    'Position', [280 760 320 790], ...
    'UpperLimit', '1e6', 'LowerLimit', '1');

% Wire signal chain
add_line(mdl, 'DC_Load_Profile/1', 'Log_Pdc_load/1');
add_line(mdl, 'DCL_From_Vdc/1',   'DCL_Vdc_LPF/1');
add_line(mdl, 'DCL_Vdc_LPF/1',    'DCL_Vsq/1');
add_line(mdl, 'DCL_Vdc_LPF/1',    'DCL_Vsq/2');      % V × V = V²
add_line(mdl, 'DCL_Vsq/1',        'DCL_Rdiv/1');      % V² → numerator
add_line(mdl, 'DC_Load_Profile/1', 'DCL_Rdiv/2');      % P_load → denominator
add_line(mdl, 'DCL_Rdiv/1',       'DCL_Rsat/1');

%% ========== Simscape: Variable Resistor ==========
% The variable resistor is driven by R(t) from top level
add_block('simulink/Ports & Subsystems/Subsystem', [mdl '/DC_Load_Var'], ...
    'Position', [450 750 550 830]);

dcl = [mdl '/DC_Load_Var'];
% Delete default contents
lines = find_system(dcl, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
for i = 1:length(lines), try delete_line(lines(i)); catch, end, end
blocks = find_system(dcl, 'SearchDepth', 1, 'Type', 'block');
for i = 1:length(blocks)
    if ~strcmp(blocks{i}, dcl), try delete_block(blocks{i}); catch, end, end
end

% Inport for R value
add_block('simulink/Sources/In1', [dcl '/R_in'], ...
    'Position', [50 105 80 125]);

% Simulink-PS Converter
add_block('nesl_utility/Simulink-PS Converter', [dcl '/SPS_R'], ...
    'Position', [120 105 150 130]);

% Variable Resistor
add_block('fl_lib/Electrical/Electrical Elements/Variable Resistor', ...
    [dcl '/VR_DC'], ...
    'Position', [200 80 240 160]);

% Discover ports
discover_ports([dcl '/VR_DC']);

% Connection Ports
add_block('nesl_utility/Connection Port', [dcl '/DC_Plus'], ...
    'Position', [320 90 350 110], 'Side', 'right');
add_block('nesl_utility/Connection Port', [dcl '/DC_Minus'], ...
    'Position', [320 140 350 160], 'Side', 'right');

% Internal wiring
add_line(dcl, 'R_in/1', 'SPS_R/1');
% Variable Resistor ports discovered: LConn1(+), LConn2(R signal), RConn1(-)
safe_connect(dcl, 'SPS_R/RConn1',    'VR_DC/LConn2');     % R signal (physical)
safe_connect(dcl, 'VR_DC/LConn1',    'DC_Plus/RConn1');    % (+)
safe_connect(dcl, 'VR_DC/RConn1',    'DC_Minus/RConn1');   % (-)

% Connect top-level R signal → subsystem
add_line(mdl, 'DCL_Rsat/1', 'DC_Load_Var/1');

% Connect to DC bus
try
    add_line(mdl, 'DC_Load_Var/RConn1', 'DC_Bus_Cap/LConn1');
    fprintf('  DC Load DC+ -> DC Bus [connected]\n');
catch e
    fprintf('  [WARN] DC Load DC+: %s\n', e.message);
end
try
    add_line(mdl, 'DC_Load_Var/RConn2', 'Electrical Reference/LConn1');
    fprintf('  DC Load DC- -> Ground [connected]\n');
catch e
    fprintf('  [WARN] DC Load DC-: %s\n', e.message);
end

fprintf('  DC_Load_Var built: variable R(t) = V²/P(t), P_max=15kW\n');

end
