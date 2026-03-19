function fis = create_prattico_fis()
%CREATE_PRATTICO_FIS  Mamdani FIS for Prattico et al. (2025) EMS
%
% No Fuzzy Logic Toolbox required — pure MATLAB implementation.
%
% Inputs (Table 2):
%   1. DeltaP  [-150, +150] kW — power imbalance (gen - load)
%   2. SOC     [30, 90]%       — battery state of charge
%   3. Tariff  [0.05, 0.15]    — electricity price €/kWh
%
% Outputs (Table 2):
%   1. Pref_batt [-100, +100] kW — battery power reference
%   2. Pref_AC   [0, 150] kW    — AC-side dispatch
%   3. Grid_conn [0, 1]         — grid connection (binary)
%   4. FC_conn   [0, 1]         — fuel cell activation (binary)
%
% Inference: Mamdani, max-min composition, centroid defuzzification
% Rules: 60 rules (5 DeltaP × 4 SOC × 3 Tariff)
%
% Based on: Prattico et al. (2025) §2.5-2.6, Table 2-3, Figure 2

fprintf('Creating Prattico EMS FIS (no toolbox required)...\n');

%% ========== Input Membership Functions ==========
% DeltaP: 5 MFs (Table 3 categories)
fis.inputs(1).name = 'DeltaP';
fis.inputs(1).range = [-150 150];
fis.inputs(1).mfs = {
    'DeficitHigh',  [-150 -150 -60];   % 1
    'DeficitLow',   [-120 -60   0];    % 2
    'Balanced',     [-30    0  30];     % 3
    'SurplusLow',   [  0   60 120];    % 4
    'SurplusHigh',  [ 60  150 150];    % 5
};

% SOC: 4 MFs (Table 2)
fis.inputs(2).name = 'SOC';
fis.inputs(2).range = [30 90];
fis.inputs(2).mfs = {
    'Low',      [30 30 45];     % 1
    'Medium',   [35 50 65];     % 2
    'High',     [55 70 85];     % 3
    'VeryHigh', [75 90 90];     % 4
};

% Tariff: 3 MFs (Table 2)
fis.inputs(3).name = 'Tariff';
fis.inputs(3).range = [0.05 0.15];
fis.inputs(3).mfs = {
    'Low',    [0.05 0.05 0.09];   % 1
    'Medium', [0.07 0.10 0.13];   % 2
    'High',   [0.11 0.15 0.15];   % 3
};

%% ========== Output Membership Functions ==========
% Pref_batt: 3 MFs
fis.outputs(1).name = 'Pref_batt';
fis.outputs(1).range = [-100 100];
fis.outputs(1).mfs = {
    'Charge',    [-100 -100 0];     % 1
    'Idle',      [-50    0 50];     % 2
    'Discharge', [  0  100 100];    % 3
};

% Pref_AC: 3 MFs
fis.outputs(2).name = 'Pref_AC';
fis.outputs(2).range = [0 150];
fis.outputs(2).mfs = {
    'Low',    [0   0  75];    % 1
    'Medium', [0  75 150];    % 2
    'High',   [75 150 150];   % 3
};

% Grid_connection: 2 MFs
fis.outputs(3).name = 'Grid_conn';
fis.outputs(3).range = [0 1];
fis.outputs(3).mfs = {
    'Disconnected', [0 0   0.5];   % 1
    'Connected',    [0.5 1 1];     % 2
};

% FC_connection: 2 MFs
fis.outputs(4).name = 'FC_conn';
fis.outputs(4).range = [0 1];
fis.outputs(4).mfs = {
    'OFF', [0 0   0.5];   % 1
    'ON',  [0.5 1 1];     % 2
};

%% ========== Rule Base (60 rules: 5×4×3) ==========
% Each rule: [DP_mf, SOC_mf, Tariff_mf, Pbatt_mf, PAC_mf, Grid_mf, FC_mf]
% Index = MF number (1-based)
%
% Logic derived from Table 3 examples + paper §2.6 principles:
%   - Surplus + High SOC → Discharge + Export
%   - Surplus + Low SOC → Charge battery
%   - Surplus + Low Tariff → Charge
%   - Surplus + High Tariff → Export/sell
%   - Deficit + High SOC → Discharge battery
%   - Deficit + Low SOC → FC ON + Grid import
%   - Balanced → Idle, minimal grid
%   - FC ON only if DeficitHigh AND SOC ≤ Medium

% DP: 1=DefH, 2=DefL, 3=Bal, 4=SurL, 5=SurH
% SOC: 1=Low, 2=Med, 3=High, 4=VHigh
% Tar: 1=Low, 2=Med, 3=High
% PBatt: 1=Charge, 2=Idle, 3=Discharge
% PAC: 1=Low, 2=Med, 3=High
% Grid: 1=Disc, 2=Conn
% FC: 1=OFF, 2=ON

rules = [];
% --- DeficitHigh (DP=1) ---
%         DP SOC Tar  PB PAC Grd FC
rules = [rules;
    1  1  1   2  1  2  2;   % DefH, Low, Low    → Idle, Low, Conn, FC ON
    1  1  2   2  1  2  2;   % DefH, Low, Med    → Idle, Low, Conn, FC ON
    1  1  3   2  1  2  2;   % DefH, Low, High   → Idle, Low, Conn, FC ON  [Table 3 R6]
    1  2  1   3  2  2  2;   % DefH, Med, Low    → Disch, Med, Conn, FC ON
    1  2  2   3  2  2  2;   % DefH, Med, Med    → Disch, Med, Conn, FC ON
    1  2  3   3  3  2  2;   % DefH, Med, High   → Disch, High, Conn, FC ON
    1  3  1   3  2  2  1;   % DefH, High, Low   → Disch, Med, Conn, FC OFF
    1  3  2   3  2  2  1;   % DefH, High, Med   → Disch, Med, Conn, FC OFF
    1  3  3   3  3  2  1;   % DefH, High, High  → Disch, High, Conn, FC OFF [Table 3 R5 variant]
    1  4  1   3  1  2  1;   % DefH, VHigh, Low  → Disch, Low, Conn, FC OFF
    1  4  2   3  2  2  1;   % DefH, VHigh, Med  → Disch, Med, Conn, FC OFF
    1  4  3   3  3  2  1;   % DefH, VHigh, High → Disch, High, Conn, FC OFF
];

% --- DeficitLow (DP=2) ---
rules = [rules;
    2  1  1   3  2  2  1;   % DefL, Low, Low    → Disch, Med, Conn, OFF
    2  1  2   3  2  2  1;   % DefL, Low, Med    → Disch, Med, Conn, OFF [Table 3 R4]
    2  1  3   3  2  2  1;   % DefL, Low, High   → Disch, Med, Conn, OFF
    2  2  1   3  1  1  1;   % DefL, Med, Low    → Disch, Low, Disc, OFF
    2  2  2   3  2  2  1;   % DefL, Med, Med    → Disch, Med, Conn, OFF
    2  2  3   3  2  2  1;   % DefL, Med, High   → Disch, Med, Conn, OFF
    2  3  1   3  1  1  1;   % DefL, High, Low   → Disch, Low, Disc, OFF
    2  3  2   3  1  1  1;   % DefL, High, Med   → Disch, Low, Disc, OFF
    2  3  3   3  2  2  1;   % DefL, High, High  → Disch, Med, Conn, OFF
    2  4  1   3  1  1  1;   % DefL, VHigh, Low  → Disch, Low, Disc, OFF
    2  4  2   3  1  1  1;   % DefL, VHigh, Med  → Disch, Low, Disc, OFF
    2  4  3   3  2  2  1;   % DefL, VHigh, High → Disch, Med, Conn, OFF
];

% --- Balanced (DP=3) ---
rules = [rules;
    3  1  1   1  1  1  1;   % Bal, Low, Low     → Charge, Low, Disc, OFF
    3  1  2   2  1  1  1;   % Bal, Low, Med     → Idle, Low, Disc, OFF
    3  1  3   2  1  1  1;   % Bal, Low, High    → Idle, Low, Disc, OFF
    3  2  1   1  1  1  1;   % Bal, Med, Low     → Charge, Low, Disc, OFF
    3  2  2   2  1  1  1;   % Bal, Med, Med     → Idle, Low, Disc, OFF
    3  2  3   2  2  1  1;   % Bal, Med, High    → Idle, Med, Disc, OFF [Table 3 R3]
    3  3  1   2  1  1  1;   % Bal, High, Low    → Idle, Low, Disc, OFF
    3  3  2   2  1  1  1;   % Bal, High, Med    → Idle, Low, Disc, OFF
    3  3  3   3  2  2  1;   % Bal, High, High   → Disch, Med, Conn, OFF
    3  4  1   2  1  1  1;   % Bal, VHigh, Low   → Idle, Low, Disc, OFF
    3  4  2   3  1  1  1;   % Bal, VHigh, Med   → Disch, Low, Disc, OFF
    3  4  3   3  2  2  1;   % Bal, VHigh, High  → Disch, Med, Conn, OFF
];

% --- SurplusLow (DP=4) ---
rules = [rules;
    4  1  1   1  1  1  1;   % SurL, Low, Low    → Charge, Low, Disc, OFF
    4  1  2   1  1  1  1;   % SurL, Low, Med    → Charge, Low, Disc, OFF
    4  1  3   1  2  2  1;   % SurL, Low, High   → Charge, Med, Conn, OFF
    4  2  1   1  1  1  1;   % SurL, Med, Low    → Charge, Low, Disc, OFF [Table 3 R2]
    4  2  2   1  1  1  1;   % SurL, Med, Med    → Charge, Low, Disc, OFF
    4  2  3   1  2  2  1;   % SurL, Med, High   → Charge, Med, Conn, OFF
    4  3  1   1  1  1  1;   % SurL, High, Low   → Charge, Low, Disc, OFF
    4  3  2   2  2  2  1;   % SurL, High, Med   → Idle, Med, Conn, OFF
    4  3  3   3  3  2  1;   % SurL, High, High  → Disch, High, Conn, OFF
    4  4  1   1  2  2  1;   % SurL, VHigh, Low  → Charge, Med, Conn, OFF
    4  4  2   3  2  2  1;   % SurL, VHigh, Med  → Disch, Med, Conn, OFF
    4  4  3   3  3  2  1;   % SurL, VHigh, High → Disch, High, Conn, OFF
];

% --- SurplusHigh (DP=5) ---
rules = [rules;
    5  1  1   1  1  1  1;   % SurH, Low, Low    → Charge, Low, Disc, OFF
    5  1  2   1  2  1  1;   % SurH, Low, Med    → Charge, Med, Disc, OFF
    5  1  3   1  2  2  1;   % SurH, Low, High   → Charge, Med, Conn, OFF
    5  2  1   1  2  1  1;   % SurH, Med, Low    → Charge, Med, Disc, OFF
    5  2  2   1  2  2  1;   % SurH, Med, Med    → Charge, Med, Conn, OFF
    5  2  3   1  3  2  1;   % SurH, Med, High   → Charge, High, Conn, OFF
    5  3  1   1  2  2  1;   % SurH, High, Low   → Charge, Med, Conn, OFF
    5  3  2   1  3  2  1;   % SurH, High, Med   → Charge, High, Conn, OFF
    5  3  3   3  3  2  1;   % SurH, High, High  → Disch, High, Conn, OFF [Table 3 R1]
    5  4  1   1  3  2  1;   % SurH, VHigh, Low  → Charge, High, Conn, OFF [Table 3 R7]
    5  4  2   3  3  2  1;   % SurH, VHigh, Med  → Disch, High, Conn, OFF
    5  4  3   3  3  2  1;   % SurH, VHigh, High → Disch, High, Conn, OFF
];

fis.rules = rules;
fprintf('  FIS created: %d rules, %d inputs, %d outputs\n', ...
    size(rules, 1), length(fis.inputs), length(fis.outputs));

end
