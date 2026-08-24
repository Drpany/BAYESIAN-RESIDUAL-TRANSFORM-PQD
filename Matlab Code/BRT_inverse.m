%% BRT_inverse.m
%% Algorithm 2 -- Inverse BRT (sum of residuals)
%% [Wong & Wang 2015, Algorithm 2, Eq. 12]
%% Input: residuals (cell array of scales)
%% Output: f_recon (reconstructed signal)

function f_recon = BRT_inverse(residuals)
    f_recon = zeros(size(residuals{1}));
    for j = 1:length(residuals)
        f_recon = f_recon + residuals{j};
    end
end
