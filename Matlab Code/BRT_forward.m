%% BRT_forward.m
%% Algorithm 1 -- Forward BRT (cascading conditional expectation)
%% [Wong & Wang 2015, Algorithm 1]
%% Input: f (signal), n (scales), lambdas (bandwidth per scale),
%%        kernel_sizes (half-widths), win_max (max window size)
%% Output: residuals (cell array of detail scales), fP (smoothed cascade)

function [residuals, fP] = BRT_forward(f, n, lambdas, kernel_sizes, win_max)
    residuals = cell(n, 1);
    fP = cell(n, 1);
    fP{1} = f;

    for j = 1:n-1
        W = max(1, min(kernel_sizes(j), floor(win_max/2)));
        fP{j+1} = nw_kernel_regression(fP{j}, lambdas(j), W);
    end

    for j = 1:n-1
        residuals{j} = fP{j} - fP{j+1};
    end
    residuals{n} = fP{n};
end


%% Nadaraya-Watson Kernel Regression  [Wong & Wang 2015, Eq. 13]
%% Adaptive smoothing: weights based on signal amplitude similarity (not just distance)
%% Local helper -- only called from BRT_forward above

function f_hat = nw_kernel_regression(f, lambda, W)
    N       = length(f);
    lam2    = lambda^2 + eps;
    win_len = 2*W + 1;

    % Mirror padding for boundary handling
    pad_len = W;
    f_pad   = [f(pad_len:-1:1); f; f(end:-1:end-pad_len+1)];

    % Extract sliding windows
    col_idx = bsxfun(@plus, (1:N)', 0:win_len-1);
    F_mat   = f_pad(col_idx);

    % Gaussian kernel weights based on amplitude difference from center
    f_ctr  = F_mat(:, W+1);
    K      = exp(-bsxfun(@minus, F_mat, f_ctr).^2 / lam2);
    K_sum  = sum(K, 2);
    K_norm = bsxfun(@rdivide, K, max(K_sum, eps));
    f_hat  = sum(K_norm .* F_mat, 2);
end
