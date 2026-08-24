%% BRT_noise_suppress.m
%% Algorithm 3 -- Noise suppression (hard thresholding on detail scales only)
%% [Wong & Wang 2015, Algorithm 3]
%% Uses Median Absolute Deviation (MAD) for threshold estimation
%% Input: residuals (cell array), k_thresh (threshold scaling factor)
%% Output: res_thresh (thresholded residuals)

function res_thresh = BRT_noise_suppress(residuals, k_thresh)
    n = length(residuals);
    res_thresh = cell(n, 1);
    PHI_INV_075 = 0.6745;   % Quantile constant for MAD

    for j = 1:n-1
        rj    = residuals{j};
        mad_j = median(abs(rj - median(rj)));
        theta_j = k_thresh * mad_j / PHI_INV_075;
        res_thresh{j} = sign(rj) .* max(abs(rj) - theta_j, 0);
    end
    res_thresh{n} = residuals{n};   % Coarse scale not thresholded
end
