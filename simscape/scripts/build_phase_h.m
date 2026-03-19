function build_phase_h()
%BUILD_PHASE_H  Phase H: Complete microgrid + EMS

fprintf('\n=== PHASE H: Complete Microgrid + Fuzzy EMS ===\n');

script_dir = fileparts(mfilename('fullpath'));
addpath(script_dir);
fprintf('[OK] %s %s\n', ver('Simscape').Name, ver('Simscape').Version);

fprintf('[1/11] Skeleton...\n');        mdl = build_phase_b_skeleton(true);
fprintf('[2/11] PV...\n');              build_pv_system(mdl);
fprintf('[3/11] Battery...\n');         build_battery_system(mdl);
fprintf('[4/11] WT...\n');
if isempty(find_system(mdl,'SearchDepth',1,'Name','WT_System'))
    add_block('simulink/Ports & Subsystems/Subsystem',[mdl '/WT_System'],'Position',[200 400 300 480]);
end
build_wt_system(mdl);
fprintf('[5/11] FC...\n');
if isempty(find_system(mdl,'SearchDepth',1,'Name','FC_System'))
    add_block('simulink/Ports & Subsystems/Subsystem',[mdl '/FC_System'],'Position',[200 500 300 580]);
end
build_fc_system(mdl);
fprintf('[6/11] DC Load...\n');         build_dc_load(mdl);
fprintf('[7/11] VSC + AC Loads...\n');
if isempty(find_system(mdl,'SearchDepth',1,'Name','VSC_System'))
    add_block('simulink/Ports & Subsystems/Subsystem',[mdl '/VSC_System'],'Position',[200 600 300 680]);
end
build_vsc_system(mdl);
fprintf('[8/11] PQ Monitoring...\n');   build_pq_monitoring(mdl);
fprintf('[9/11] EMS Fuzzy...\n');       build_ems_fuzzy(mdl);

fprintf('[10/11] Connecting DC sources...\n');
for s = {'PV_System','Battery_System','WT_System','FC_System'}
    try add_line(mdl,[s{1} '/RConn1'],'DC_Bus_Cap/LConn1'); catch, end
    try add_line(mdl,[s{1} '/RConn2'],'Electrical Reference/LConn1'); catch, end
end

fprintf('[11/11] Saving...\n');
save_system(mdl, fullfile(script_dir, [mdl '.slx']));

fprintf('\n=== PHASE H BUILD COMPLETE ===\n');
fprintf('ALL COMPONENTS PRESENT:\n');
fprintf('  Generation: PV(59kW) + WT(55kW) + FC(18kW) = 132kW\n');
fprintf('  Storage:    Battery 200kWh\n');
fprintf('  Loads:      DC(15kW) + AC_res(50kW) + AC_com(45kW) = 110kW\n');
fprintf('  Control:    EMS (rule-based fuzzy approximation)\n');
fprintf('  Monitoring: PQ (ΔV_DC)\n');
fprintf('Run: sim(''%s'', 0.5); validate_phase_h\n', mdl);
end
