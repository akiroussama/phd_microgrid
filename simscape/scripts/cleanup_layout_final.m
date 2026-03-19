function cleanup_layout_final()
%CLEANUP_LAYOUT_FINAL  Exact ASCII-art layout — 4 rows, top-down
%
%   ROW 1 (y=100):  PV        Battery      WT         FC        ← SOURCES
%                                          WT_Sig     FC_Sig
%
%   ROW 2 (y=450):           [ DC BUS 750V ]                    ← BUS
%
%   ROW 3 (y=700):  DC_Load              VSC_System              ← LOADS
%                   DCL_Sig              VSC_Sig
%
%   ROW 4 (y=1000):    EMS              PQ_Monitor              ← SUPERVISION
%
%   Solver in top-left corner

mdl = 'prattico_simscape_phase_b';
if ~bdIsLoaded(mdl), load_system(mdl); end

fprintf('Applying FINAL top-down layout...\n');

% === CONFIG (top-left) ===
sp(mdl, 'Solver Configuration',  [30    20    130   70]);

% === ROW 1: SOURCES (y=120, wide subsystems) ===
% 4 sources, evenly spaced, x = 50, 320, 590, 860
w = 200; h = 130;
y1 = 120;
sp(mdl, 'PV_System',             [50    y1    50+w   y1+h]);
sp(mdl, 'Battery_System',        [320   y1    320+w  y1+h]);
sp(mdl, 'WT_System',             [590   y1    590+w  y1+h]);
sp(mdl, 'FC_System',             [860   y1    860+w  y1+h]);

% Signal blocks under WT and FC (smaller, y=280)
y1s = 280;
ws = 200; hs = 50;
sp(mdl, 'WT_Signals',            [590   y1s   590+ws y1s+hs]);
sp(mdl, 'FC_Signals',            [860   y1s   860+ws y1s+hs]);

% === ROW 2: DC BUS (y=430, centered, wide) ===
y2 = 430;
sp(mdl, 'DC_Bus',                [330   y2    730    y2+150]);

% === ROW 3: LOADS (y=700) ===
y3 = 700;
sp(mdl, 'DC_Load_Var',           [150   y3    150+w  y3+h]);
sp(mdl, 'VSC_System',            [650   y3    650+w  y3+h]);

% Signal blocks under loads (y=860)
y3s = 860;
sp(mdl, 'DCL_Signals',           [150   y3s   150+ws y3s+hs]);
sp(mdl, 'VSC_Signals',           [650   y3s   650+ws y3s+hs]);

% === ROW 4: SUPERVISION (y=1020) ===
y4 = 1020;
wl = 250; hl = 100;
sp(mdl, 'EMS',                   [150   y4    150+wl y4+hl]);
sp(mdl, 'PQ_Monitor',            [600   y4    600+wl y4+hl]);

fprintf('DONE — 14 blocks, 4 rows, top-down.\n');
fprintf('save_system(''%s'') to save.\n', mdl);

end

function sp(mdl, name, pos)
    try
        set_param([mdl '/' name], 'Position', pos);
    catch
        fprintf('  [SKIP] %s\n', name);
    end
end
