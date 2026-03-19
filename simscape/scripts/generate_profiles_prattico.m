function profiles = generate_profiles_prattico(varargin)
%GENERATE_PROFILES_PRATTICO Practical seed profiles for the Prattico clone.
%
% This helper creates paper-consistent input envelopes for a 24 h scenario
% compressed into 24 s of simulation time. It is a reconstruction aid, not
% the original dataset from the publication.
%
% Usage:
%   profiles = generate_profiles_prattico;
%   profiles = generate_profiles_prattico("dt_hours", 1/120, "seed", 7);
%
% Returned fields include both numeric arrays and timeseries objects.

p = inputParser;
addParameter(p, "dt_hours", 1/60, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, "seed", 42, @(x) isnumeric(x) && isscalar(x));
addParameter(p, "save_mat", false, @(x) islogical(x) && isscalar(x));
addParameter(p, "output_mat", "profiles_prattico_seed.mat", @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
opts = p.Results;

dt_hours = opts.dt_hours;
rng(opts.seed, "twister");

% Paper compression: 24 h -> 24 s, so 1 simulated second = 1 real hour.
t_hours = (0:dt_hours:24).';
t_sim_s = t_hours;
compression_factor = 3600;

% PV irradiance: June-like bell profile, peak near noon at ~1000 W/m^2.
sunrise_h = 6.0;
sunset_h = 20.0;
day_mask = (t_hours >= sunrise_h) & (t_hours <= sunset_h);
irradiance_wm2 = zeros(size(t_hours));
solar_shape = sin(pi * (t_hours(day_mask) - sunrise_h) / (sunset_h - sunrise_h));
irradiance_wm2(day_mask) = 1000 * max(solar_shape, 0) .^ 1.65;

% Wind speed: stochastic but bounded, with afternoon strengthening.
wind_base = 6.5 ...
    + 2.5 * sin(2 * pi * (t_hours - 8) / 24) ...
    + 1.2 * sin(4 * pi * (t_hours - 11) / 24);
wind_noise = 0.7 * randn(size(t_hours));
wind_speed_ms = min(max(wind_base + wind_noise, 3.0), 14.0);

% DC load: electronics / ICT style demand with a 15 kW ceiling.
p_dc_load_kw = 6 ...
    + 4.0 * gauss_peak(t_hours, 13.0, 2.2) ...
    + 5.0 * gauss_peak(t_hours, 20.5, 1.8);
p_dc_load_kw = min(max(p_dc_load_kw, 2.5), 15.0);

% Residential AC load: midday peak ~40 kW, evening peak ~50 kW.
p_res_load_kw = 10 ...
    + 30.0 * gauss_peak(t_hours, 12.5, 1.4) ...
    + 40.0 * gauss_peak(t_hours, 20.0, 1.6);
p_res_load_kw = min(max(p_res_load_kw, 5.0), 50.0);

% Commercial AC load: daytime profile, peak ~45 kW, PF ~0.9.
day_window = smooth_window(t_hours, 8.0, 18.0, 0.5);
p_comm_load_kw = 4 + 41 * day_window .* (0.75 + 0.25 * gauss_peak(t_hours, 13.0, 2.8));
p_comm_load_kw = min(max(p_comm_load_kw, 0.0), 45.0);
pf_comm = 0.9;
q_comm_load_kvar = p_comm_load_kw .* tan(acos(pf_comm));

% Tariff: 0.05-0.15 EUR/kWh time-of-use reconstruction.
tariff_eur_kwh = 0.05 * ones(size(t_hours));
tariff_eur_kwh(t_hours >= 7 & t_hours < 17) = 0.10;
tariff_eur_kwh(t_hours >= 17 & t_hours < 22) = 0.15;
tariff_eur_kwh(t_hours >= 22 | t_hours < 7) = 0.05;

% Store SI-unit arrays.
p_dc_load_w = 1e3 * p_dc_load_kw;
p_res_load_w = 1e3 * p_res_load_kw;
p_comm_load_w = 1e3 * p_comm_load_kw;
q_comm_load_var = 1e3 * q_comm_load_kvar;

profiles = struct();
profiles.meta = struct( ...
    "description", "Paper-consistent seed profiles for the Prattico microgrid clone", ...
    "compression_factor_real_seconds_per_sim_second", compression_factor, ...
    "dt_hours", dt_hours, ...
    "seed", opts.seed, ...
    "note", "Reconstruction aid only; not the raw publication dataset." ...
);

profiles.time_hours = t_hours;
profiles.time_seconds = t_sim_s;
profiles.irradiance_wm2 = irradiance_wm2;
profiles.wind_speed_ms = wind_speed_ms;
profiles.p_dc_load_w = p_dc_load_w;
profiles.p_res_load_w = p_res_load_w;
profiles.p_comm_load_w = p_comm_load_w;
profiles.q_comm_load_var = q_comm_load_var;
profiles.tariff_eur_kwh = tariff_eur_kwh;

profiles.irradiance_wm2_ts = timeseries(irradiance_wm2, t_sim_s);
profiles.wind_speed_ms_ts = timeseries(wind_speed_ms, t_sim_s);
profiles.p_dc_load_w_ts = timeseries(p_dc_load_w, t_sim_s);
profiles.p_res_load_w_ts = timeseries(p_res_load_w, t_sim_s);
profiles.p_comm_load_w_ts = timeseries(p_comm_load_w, t_sim_s);
profiles.q_comm_load_var_ts = timeseries(q_comm_load_var, t_sim_s);
profiles.tariff_eur_kwh_ts = timeseries(tariff_eur_kwh, t_sim_s);

if opts.save_mat
    save(opts.output_mat, "-struct", "profiles");
end
end

function y = gauss_peak(t, mu, sigma)
y = exp(-0.5 * ((t - mu) / sigma) .^ 2);
end

function y = smooth_window(t, start_h, end_h, edge_h)
rise = 0.5 * (1 + tanh((t - start_h) / edge_h));
fall = 0.5 * (1 + tanh((end_h - t) / edge_h));
y = rise .* fall;
end
