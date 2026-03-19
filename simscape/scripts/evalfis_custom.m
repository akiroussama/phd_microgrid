function outputs = evalfis_custom(fis, inputs)
%EVALFIS_CUSTOM  Evaluate Mamdani FIS without Fuzzy Logic Toolbox
%
% fis     = struct from create_prattico_fis()
% inputs  = [DeltaP_kW, SOC_pct, Tariff_EUR] (1×3 or N×3)
% outputs = [Pref_batt, Pref_AC, Grid_conn, FC_conn] (N×4)
%
% Inference: max-min composition (§2.5 p.702)
% Defuzzification: centroid method (§2.5 p.703)

[N, ~] = size(inputs);
n_outputs = length(fis.outputs);
outputs = zeros(N, n_outputs);

for k = 1:N
    x = inputs(k, :);

    %% Step 1: Fuzzify inputs
    % Compute membership degree for each input in each MF
    n_inputs = length(fis.inputs);
    mu_in = cell(1, n_inputs);
    for i = 1:n_inputs
        n_mf = size(fis.inputs(i).mfs, 1);
        mu_in{i} = zeros(1, n_mf);
        for j = 1:n_mf
            params = fis.inputs(i).mfs{j, 2};
            mu_in{i}(j) = trimf_eval(x(i), params);
        end
    end

    %% Step 2: Evaluate rules (max-min)
    n_rules = size(fis.rules, 1);
    rule_strength = zeros(n_rules, 1);

    for r = 1:n_rules
        % AND = min of all input membership degrees
        rule = fis.rules(r, :);
        strengths = zeros(1, n_inputs);
        for i = 1:n_inputs
            mf_idx = rule(i);
            strengths(i) = mu_in{i}(mf_idx);
        end
        rule_strength(r) = min(strengths);  % AND = min
    end

    %% Step 3: Aggregate + Defuzzify each output (centroid)
    for o = 1:n_outputs
        out_range = fis.outputs(o).range;
        n_points = 101;  % Resolution for centroid
        x_out = linspace(out_range(1), out_range(2), n_points);
        mu_agg = zeros(1, n_points);

        % For each rule, clip the output MF at rule strength (implication)
        % then aggregate with max
        for r = 1:n_rules
            if rule_strength(r) < 1e-10, continue; end  % Skip inactive rules
            mf_idx = fis.rules(r, n_inputs + o);
            params = fis.outputs(o).mfs{mf_idx, 2};

            % Compute output MF clipped at rule strength
            for p = 1:n_points
                mu_mf = trimf_eval(x_out(p), params);
                mu_clipped = min(mu_mf, rule_strength(r));  % Implication = min
                mu_agg(p) = max(mu_agg(p), mu_clipped);     % Aggregation = max
            end
        end

        % Centroid defuzzification
        if sum(mu_agg) < 1e-10
            % No rules fired → default to midpoint
            outputs(k, o) = mean(out_range);
        else
            outputs(k, o) = sum(x_out .* mu_agg) / sum(mu_agg);
        end
    end
end

end

function mu = trimf_eval(x, params)
%TRIMF_EVAL  Triangular membership function
%   params = [a, b, c] where a ≤ b ≤ c
%   mu = 0 outside [a,c], peaks at 1 at b
    a = params(1); b = params(2); c = params(3);
    if x <= a || x >= c
        mu = 0;
    elseif x <= b
        if b == a, mu = 1; else, mu = (x - a) / (b - a); end
    else
        if c == b, mu = 1; else, mu = (c - x) / (c - b); end
    end
end
