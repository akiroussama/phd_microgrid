%RUN_AUTORESEARCH_EXPERIMENT  Build model, run simulation, evaluate metrics.
%
%   Called by Python agent via: matlab -batch "run_autoresearch_experiment"
%
%   Workflow:
%     1. cd to scripts directory
%     2. build_fullday (creates prattico_fullday.slx)
%     3. sim('prattico_fullday', 24)
%     4. evaluate_experiment (computes metrics, saves CSV, prints SCORE)

try
    % cd to the scripts directory so MATLAB can find all functions
    script_dir = fullfile('D:', 'doctorat', 'workspace', 'these', ...
                          'simscape_opus_46', 'scripts');
    cd(script_dir);
    addpath(script_dir);

    fprintf('\n=== AUTORESEARCH EXPERIMENT ===\n');
    fprintf('Working directory: %s\n', pwd);

    % Step 1: Build the model
    fprintf('\n--- Step 1: Building model ---\n');
    build_fullday();

    % Step 2: Run the simulation
    fprintf('\n--- Step 2: Running simulation ---\n');
    sim('prattico_fullday', 24);
    fprintf('Simulation completed.\n');

    % Step 3: Evaluate
    fprintf('\n--- Step 3: Evaluating ---\n');
    score = evaluate_experiment();

    fprintf('\n=== EXPERIMENT COMPLETE ===\n');

catch ME
    fprintf('\n[FATAL] Experiment failed: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for k = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
    fprintf('SCORE: -Inf\n');

    % Still try to save a failure CSV
    try
        csv_dir = fullfile('D:', 'doctorat', 'workspace', 'these', ...
                           'autoresearch', 'logs');
        if ~exist(csv_dir, 'dir'), mkdir(csv_dir); end
        fid = fopen(fullfile(csv_dir, 'last_result.csv'), 'w');
        fprintf(fid, 'DeltaV_max,SOC_in_range_pct,daily_cost_eur,self_consumption_pct,safety_violations,score\n');
        fprintf(fid, 'NaN,NaN,NaN,NaN,0,-Inf\n');
        fclose(fid);
    catch
    end
end
