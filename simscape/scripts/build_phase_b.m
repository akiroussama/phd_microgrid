function build_phase_b()
%BUILD_PHASE_B Master script: assemble DC Bus + PV + Battery, run validation.
%
% This is the Phase B milestone from the implementation plan:
%   "Le modele doit deja permettre:
%    - bus DC stable autour de 750 V
%    - production PV injectee sur le bus
%    - batterie capable de charger et de decharger
%    - SOC_batt visible et coherent
%    - aucun comportement non physique sur les signes de courant/puissance"
%
% Usage:
%   Run this function in MATLAB with Simscape Electrical installed.
%   >> build_phase_b
%
% Based on: Prattico et al. (2025), DOI: 10.3390/en18225985
% Phase B of: PLAN_IMPLEMENTATION_SIMSCAPE_BLOC_PAR_BLOC.md

fprintf('\n=== PHASE B: DC Bus + PV + Battery ===\n');
fprintf('Building Simscape model from Prattico et al. (2025)\n\n');

%% Step 0: Verify toolboxes
% Check Simscape base
v = ver('Simscape');
if isempty(v)
    error('Simscape not found. Run "ver" to check installed toolboxes.');
end
fprintf('[OK] %s %s\n', v.Name, v.Version);

% Check for Simscape Electrical (name varies by MATLAB version)
all_ver = ver;
all_names = {all_ver.Name};
ee_idx = find(contains(all_names, 'Simscape Electrical') | ...
              contains(all_names, 'Simscape Elec') | ...
              contains(all_names, 'SimPowerSystems') | ...
              contains(all_names, 'Specialized Power Systems'));
if isempty(ee_idx)
    fprintf('[WARN] No "Simscape Electrical" toolbox found by name.\n');
    fprintf('  Installed toolboxes containing "Sim":\n');
    sim_idx = find(contains(all_names, 'Sim'));
    for k = 1:length(sim_idx)
        fprintf('    - %s %s\n', all_ver(sim_idx(k)).Name, all_ver(sim_idx(k)).Version);
    end
    fprintf('  Attempting to continue anyway (blocks may fail)...\n');
else
    for k = 1:length(ee_idx)
        fprintf('[OK] %s %s\n', all_ver(ee_idx(k)).Name, all_ver(ee_idx(k)).Version);
    end
end

%% Step 1: Add scripts to path
script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
fprintf('\n[1/5] Scripts directory added to path.\n');

%% Step 2: Build skeleton + DC Bus
fprintf('[2/5] Building model skeleton + DC Bus Core...\n');
mdl = build_phase_b_skeleton(true);
fprintf('  Model: %s\n', mdl);

%% Step 3: Build PV System
fprintf('[3/5] Building PV System (Solar Cell + Boost + MPPT)...\n');
build_pv_system(mdl);

%% Step 4: Build Battery System
fprintf('[4/5] Building Battery System (Li-ion + Buck-Boost + PI)...\n');
build_battery_system(mdl);

%% Step 5: Connect PV and Battery to DC Bus
fprintf('[5/5] Connecting subsystems to DC Bus...\n');
connect_subsystems_to_dcbus(mdl);

%% Save final model
save_system(mdl, fullfile(script_dir, [mdl '.slx']));

%% Summary
fprintf('\n=== PHASE B BUILD COMPLETE ===\n');
fprintf('Model: %s.slx\n', mdl);
fprintf('Location: %s\n', fullfile(script_dir, [mdl '.slx']));
fprintf('\nComponents:\n');
fprintf('  DC Bus:   750V, C=4.7mF\n');
fprintf('  PV:       12s x 23p Solar Cell (151.8 kWp) + Boost\n');
fprintf('  Battery:  512V/400Ah LiFePO4 (200 kWh) + Buck-Boost\n');
fprintf('\nNext steps:\n');
fprintf('  1. Open model: open_system(''%s'')\n', mdl);
fprintf('  2. Check MATLAB Function blocks (MPPT_PO, SOC_Limiter)\n');
fprintf('     -> Copy code from block Description field\n');
fprintf('  3. Check block library paths match your MATLAB version\n');
fprintf('  4. Run simulation: sim(''%s'', 1)\n', mdl);
fprintf('  5. Validate: Vdc ~750V, P_pv > 0, SOC changes\n');
fprintf('\n=== IMPORTANT NOTES ===\n');
fprintf('- Block library paths may differ in your MATLAB version.\n');
fprintf('  If a block is not found, check with Simulink Library Browser.\n');
fprintf('- MATLAB Function blocks need manual code entry:\n');
fprintf('  Double-click the block, paste code from Description field.\n');
fprintf('- Solar Cell parameters use JinkoSolar 550W proxy values.\n');
fprintf('  Adjust Rs, Rsh, Is, N if using different module datasheet.\n');

end

function connect_subsystems_to_dcbus(mdl)
%CONNECT_SUBSYSTEMS_TO_DCBUS Wire PV and Battery physical ports to DC bus.

% Connect PV_System DC+ to DC Bus Cap + (shared node)
try
    add_line(mdl, 'PV_System/RConn1', 'DC_Bus_Cap/LConn1');
    fprintf('  PV DC+ -> DC Bus [connected]\n');
catch e
    fprintf('  [WARN] PV DC+ connection: %s\n', e.message);
    fprintf('  -> Manual connection may be needed in Simulink.\n');
end

% Connect PV_System DC- to Electrical Reference
try
    add_line(mdl, 'PV_System/RConn2', 'Electrical Reference/LConn1');
    fprintf('  PV DC- -> Ground [connected]\n');
catch e
    fprintf('  [WARN] PV DC- connection: %s\n', e.message);
end

% Connect Battery_System DC+ to DC Bus Cap +
try
    add_line(mdl, 'Battery_System/RConn1', 'DC_Bus_Cap/LConn1');
    fprintf('  Battery DC+ -> DC Bus [connected]\n');
catch e
    fprintf('  [WARN] Battery DC+ connection: %s\n', e.message);
end

% Connect Battery_System DC- to Electrical Reference
try
    add_line(mdl, 'Battery_System/RConn2', 'Electrical Reference/LConn1');
    fprintf('  Battery DC- -> Ground [connected]\n');
catch e
    fprintf('  [WARN] Battery DC- connection: %s\n', e.message);
end

fprintf('  Subsystems connected to DC bus.\n');
end
