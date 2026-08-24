%% BRT_PowerQuality_main.m
%% Bayesian Residual Transform for power quality disturbance processing
%% Implements Wong & Wang (2015), "A Bayesian Residual Transform for
%% Signal Processing," IEEE Access, 3, 709-717, DOI: 10.1109/ACCESS.2015.2437873
%% (Alg. 1 forward BRT, Alg. 2 inverse BRT, Alg. 3 MAD threshold suppression)
%%
%% Usage: BRT_PowerQuality_main          - interactive prompts (Enter = skip)
%%        BRT_PowerQuality_main(false)   - run with all defaults, no prompts

function BRT_PowerQuality_main(interactive)

if nargin < 1, interactive = true; end

clc; close all;
tic_total = tic;

fprintf('\n+----------------------------------------------------------------+\n');
fprintf('|        BRT POWER QUALITY ANALYSIS REPORT                      |\n');
fprintf('+----------------------------------------------------------------+\n');

%% Configuration
fprintf('\n=== STEP 1: SIGNAL CONFIGURATION ===\n');

fs       = prompt_val(interactive, 'Sampling frequency (Hz) [Default: 10000]: ', 10000);
T        = prompt_val(interactive, 'Duration (seconds) [Default: 0.5]: ',         0.5);
f0       = prompt_val(interactive, 'Fundamental frequency (Hz) [Default: 50]: ',  50);
n_trials = prompt_val(interactive, 'Number of trials [Default: 10]: ',             10);

t = (0 : 1/fs : T - 1/fs)';
N = length(t);
win_samp = round(0.02 * fs);
n_cycles = T * f0;

fprintf('Signal: %d Hz, %.2f sec (%d cycles)\n', fs, T, n_cycles);
fprintf('Trials: %d | Window: %d samples\n', n_trials, win_samp);

%% Generate signals (disturbances + noise)
[v_fund, v_disturbed, include_sag, include_swell, include_trans, include_harm, include_flk, include_noise, noise_std] = ...
    BRT_signal_generation(t, fs, f0, interactive);

fprintf('\n=== STEP 10: BRT ALGORITHM PARAMETERS ===\n');

n_scales = round(prompt_val(interactive, 'Scales (3-6) [Default: 6]: ', 6));
n_scales = max(3, min(6, n_scales));

k_thresh = prompt_val(interactive, 'Threshold factor k_thresh [Default: 2.5]: ', 2.5);

use_custom = prompt_yn(interactive, 'Use custom kernel sizes? (y/n) [Default: n]: ', false);

if use_custom && interactive
    fprintf('Enter %d kernel sizes separated by spaces:\n', n_scales);
    ks_str = input('', 's');
    if isempty(strtrim(ks_str))
        kernel_sizes = default_kernels(n_scales);
    else
        kernel_sizes = sscanf(ks_str, '%f').';
        if length(kernel_sizes) ~= n_scales
            warning('BRT:kernelCount', 'Wrong count; using defaults.');
            kernel_sizes = default_kernels(n_scales);
        end
    end
else
    kernel_sizes = default_kernels(n_scales);
end

fprintf('Using %d scales, kernels [%s], k_thresh=%.2f\n', ...
        n_scales, num2str(kernel_sizes), k_thresh);

%% BRT multi-trial analysis
fprintf('\n=== BRT PROCESSING (%d trials) ===\n', n_trials);

rng(42, 'twister');

corr_all    = zeros(n_trials, 1);
snri_all    = NaN(n_trials, 1);
snr_in_all  = NaN(n_trials, 1);
snr_out_all = NaN(n_trials, 1);
rmse_all    = zeros(n_trials, 1);

rmse_sag_all   = zeros(n_trials, 1);
rmse_swell_all = zeros(n_trials, 1);
rmse_trans_all = zeros(n_trials, 1);

signal_power = sum(v_disturbed.^2);   % trial-invariant

for tr = 1:n_trials
    v_noisy   = v_disturbed + noise_std * randn(N, 1);
    lam       = std(v_noisy);
    lambdas   = lam * 1.5.^(0:n_scales-2);

    [residuals, fP_chain] = BRT_forward(v_noisy, n_scales, lambdas, kernel_sizes, win_samp);
    res_thresh = BRT_noise_suppress(residuals, k_thresh);
    v_recon    = BRT_inverse(res_thresh);

    fc = v_fund - mean(v_fund);
    rc = v_recon - mean(v_recon);
    corr_all(tr) = sum(fc .* rc) / sqrt(sum(fc.^2) * sum(rc.^2) + eps);

    if include_noise
        noise_in_power  = sum((v_noisy - v_disturbed).^2);
        noise_out_power = sum((v_recon - v_disturbed).^2);

        snr_in_all(tr)  = 10*log10(signal_power / max(noise_in_power,  eps));
        snr_out_all(tr) = 10*log10(signal_power / max(noise_out_power, eps));
        snri_all(tr)    = 10*log10(noise_in_power / max(noise_out_power, eps));
    end

    rmse_all(tr) = sqrt(mean((v_recon - v_disturbed).^2));

    if include_sag
        sag_t0  = 60 / 1000;
        sag_t1  = sag_t0 + 80 / 1000;
        idx_sag = (t >= sag_t0) & (t <= sag_t1);
        rmse_sag_all(tr) = sqrt(mean((v_recon(idx_sag) - v_disturbed(idx_sag)).^2));
    end

    if include_swell
        sw_t0  = 150 / 1000;
        sw_t1  = sw_t0 + 80 / 1000;
        idx_sw = (t >= sw_t0) & (t <= sw_t1);
        rmse_swell_all(tr) = sqrt(mean((v_recon(idx_sw) - v_disturbed(idx_sw)).^2));
    end

    if include_trans
        tr_t0  = 250 / 1000;
        idx_tr = (t >= tr_t0);
        rmse_trans_all(tr) = sqrt(mean((v_recon(idx_tr) - v_disturbed(idx_tr)).^2));
    end
end

elapsed = toc(tic_total);

%% Final pass (reproducible)
rng(99, 'twister');
v_noisy    = v_disturbed + noise_std * randn(N, 1);
lam        = std(v_noisy);
lambdas    = lam * 1.5.^(0:n_scales-2);
[residuals, fP_chain] = BRT_forward(v_noisy, n_scales, lambdas, kernel_sizes, win_samp);
res_thresh = BRT_noise_suppress(residuals, k_thresh);
v_recon    = BRT_inverse(res_thresh);

%% Results & visualization
BRT_calculate_and_plot(t, v_noisy, v_fund, v_recon, v_disturbed, residuals, res_thresh, ...
                       fP_chain, n_scales, kernel_sizes, fs, f0, include_noise, ...
                       corr_all, snri_all, snr_in_all, snr_out_all, rmse_all, ...
                       rmse_sag_all, rmse_swell_all, rmse_trans_all, ...
                       include_sag, include_swell, include_trans, elapsed);

end

%% Helper functions

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

function ks = default_kernels(n)
    switch n
        case 3, ks = [1 2 4];
        case 4, ks = [1 2 4 7];
        case 5, ks = [1 2 4 7 12];
        case 6, ks = [1 2 4 7 12 20];
        otherwise, ks = [1 2 4 7 12 20];
    end
end
