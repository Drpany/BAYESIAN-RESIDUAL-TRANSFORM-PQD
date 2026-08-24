%% BRT_signal_generation.m
%% Generate synthetic power quality signal with disturbances

function [v_fund, v_disturbed, include_sag, include_swell, include_trans, ...
          include_harm, include_flk, include_noise, noise_std] = ...
    BRT_signal_generation(t, fs, f0, interactive)

N = length(t);

%% Fundamental voltage signal
fprintf('\n=== STEP 2: FUNDAMENTAL VOLTAGE SIGNAL ===\n');
fprintf('1. Pure sine wave (1.0 pu)\n');
fprintf('2. Sine with DC offset\n');
fprintf('3. Custom amplitude (pu)\n');

if interactive
    choice = input('Choice [1-3, Default: 1]: ', 's');
    if isempty(strtrim(choice)), choice = '1'; end
else
    choice = '1';
end

switch strtrim(choice)
    case '2'
        dc     = prompt_val(interactive, 'DC offset (pu) [Default: 0.1]: ', 0.1);
        v_fund = sin(2*pi*f0*t) + dc;
        fprintf('Sine + DC offset (%.2f pu)\n', dc);
    case '3'
        A      = prompt_val(interactive, 'Amplitude (pu) [Default: 1.0]: ', 1.0);
        v_fund = A * sin(2*pi*f0*t);
        fprintf('Sine wave (%.2f pu)\n', A);
    otherwise
        v_fund = sin(2*pi*f0*t);
        fprintf('Pure sine wave (1.00 pu)\n');
end

%% Voltage sag
fprintf('\n=== STEP 3: VOLTAGE SAG (Optional) ===\n');
include_sag = prompt_yn(interactive, 'Include voltage sag? (y/n) [Default: n]: ', false);

v_sag = zeros(N, 1);
if include_sag
    sag_depth  = prompt_val(interactive, 'Sag depth (0-1 pu) [Default: 0.6]: ', 0.60);
    sag_t0_ms  = prompt_val(interactive, 'Start time (ms) [Default: 60]: ',      60);
    sag_dur_ms = prompt_val(interactive, 'Duration (ms) [Default: 80]: ',        80);

    sag_t0  = sag_t0_ms / 1000;
    sag_t1  = sag_t0 + sag_dur_ms / 1000;
    idx_sag = (t >= sag_t0) & (t <= sag_t1);
    v_sag(idx_sag) = -sag_depth * v_fund(idx_sag);
    fprintf('Sag: %.2f pu, %g - %g ms\n', sag_depth, sag_t0_ms, sag_t0_ms + sag_dur_ms);
end

%% Voltage swell
fprintf('\n=== STEP 4: VOLTAGE SWELL (Optional) ===\n');
include_swell = prompt_yn(interactive, 'Include voltage swell? (y/n) [Default: n]: ', false);

v_swell = zeros(N, 1);
if include_swell
    swell_mag   = prompt_val(interactive, 'Swell magnitude (0-1 pu) [Default: 0.3]: ', 0.30);
    swell_t0_ms = prompt_val(interactive, 'Start time (ms) [Default: 150]: ',           150);
    swell_dur   = prompt_val(interactive, 'Duration (ms) [Default: 80]: ',              80);

    sw_t0  = swell_t0_ms / 1000;
    sw_t1  = sw_t0 + swell_dur / 1000;
    idx_sw = (t >= sw_t0) & (t <= sw_t1);
    v_swell(idx_sw) = swell_mag * v_fund(idx_sw);
    fprintf('Swell: %.2f pu, %g - %g ms\n', swell_mag, swell_t0_ms, swell_t0_ms + swell_dur);
end

%% Harmonics
fprintf('\n=== STEP 5: HARMONICS (Optional) ===\n');
include_harm = prompt_yn(interactive, 'Include harmonics? (y/n) [Default: n]: ', false);

v_harm = zeros(N, 1);
if include_harm
    if interactive
        fprintf('Enter harmonics. Press Enter (blank) when done.\n');
        h_count = 0;
        while true
            h_count = h_count + 1;
            ord_str = input(sprintf('Harmonic %d order (or Enter to finish): ', h_count), 's');
            if isempty(strtrim(ord_str)) || strcmpi(strtrim(ord_str), 'done'), break; end
            h_ord = str2double(strtrim(ord_str));
            if isnan(h_ord), break; end
            h_mag = prompt_val(true, 'Magnitude (pu) [Default: 0.05]: ', 0.05);
            h_ph  = prompt_val(true, 'Phase (degrees) [Default: 0]: ',   0.0);
            v_harm = v_harm + h_mag * sin(2*pi*h_ord*f0*t + h_ph*pi/180);
        end
    else
        v_harm = 0.05 * sin(2*pi*3*f0*t) + 0.05 * sin(2*pi*5*f0*t);
    end
    fprintf('Harmonics added\n');
end

%% Flicker (amplitude modulation)
fprintf('\n=== STEP 6: FLICKER (Optional) ===\n');
include_flk = prompt_yn(interactive, 'Include flicker? (y/n) [Default: n]: ', false);

v_flicker = zeros(N, 1);
if include_flk
    flk_depth = prompt_val(interactive, 'Modulation depth (0-1 pu) [Default: 0.1]: ', 0.10);
    flk_freq  = prompt_val(interactive, 'Modulation frequency (Hz) [Default: 10]: ',  10);
    v_flicker = flk_depth * sin(2*pi*flk_freq*t) .* sin(2*pi*f0*t);
    fprintf('Flicker: +/-%.1f%% @ %.0f Hz\n', flk_depth*100, flk_freq);
end

%% Transient (exponentially decaying)
fprintf('\n=== STEP 7: TRANSIENT (Optional) ===\n');
include_trans = prompt_yn(interactive, 'Include transient? (y/n) [Default: n]: ', false);

v_trans = zeros(N, 1);
if include_trans
    tr_mag  = prompt_val(interactive, 'Magnitude (pu) [Default: 2.0]: ',  2.0);
    tr_t_ms = prompt_val(interactive, 'Occurrence (ms) [Default: 250]: ', 250);
    tr_tau  = prompt_val(interactive, 'Decay tau (ms) [Default: 10]: ',   10);

    tr_t0    = tr_t_ms / 1000;
    tr_tau_s = tr_tau / 1000;
    idx_tr   = (t >= tr_t0);
    v_trans(idx_tr) = tr_mag * exp(-(t(idx_tr) - tr_t0) / tr_tau_s) ...
                      .* sin(2*pi*f0*t(idx_tr));
    fprintf('Transient: %.2f pu at %g ms, tau = %g ms\n', tr_mag, tr_t_ms, tr_tau);
end

%% Measurement noise
fprintf('\n=== STEP 8: MEASUREMENT NOISE (Optional) ===\n');
include_noise = prompt_yn(interactive, 'Include noise? (y/n) [Default: n]: ', false);

v_disturbed = v_fund + v_sag + v_swell + v_harm + v_flicker + v_trans;

if include_noise
    noise_snr_db = prompt_val(interactive, 'Target input SNR (dB) [Default: 20]: ', 20);
    P_signal     = mean(v_disturbed.^2);
    P_noise      = P_signal / (10^(noise_snr_db/10));
    noise_std    = sqrt(P_noise);
    fprintf('Noise: SNR = %.2f dB, std = %.6f pu\n', noise_snr_db, noise_std);
else
    noise_std = 0;
end

comps = '';
if include_sag,   comps = [comps 'Sag '];       end
if include_swell, comps = [comps 'Swell '];     end
if include_harm,  comps = [comps 'Harmonics ']; end
if include_flk,   comps = [comps 'Flicker '];   end
if include_trans, comps = [comps 'Transient ']; end
if include_noise, comps = [comps 'Noise '];     end
if isempty(comps), comps = 'None (pure fundamental)'; end

fprintf('\n=== STEP 9: CONSTRUCTING SIGNAL ===\n');
fprintf('Components: %s\n', strtrim(comps));

end

%% Helpers

function val = prompt_val(interactive, msg, default_val)
    if interactive
        str = input(msg, 's');
        if isempty(strtrim(str))
            val = default_val;
        else
            val = str2double(strtrim(str));
            if isnan(val), val = default_val; end
        end
    else
        val = default_val;
    end
end

function tf = prompt_yn(interactive, msg, default_val)
    if interactive
        str = lower(strtrim(input(msg, 's')));
        if isempty(str)
            tf = default_val;
        else
            tf = strcmp(str, 'y') || strcmp(str, 'yes');
        end
    else
        tf = default_val;
    end
end
