%% BRT_calculate_and_plot.m
%% Calculate metrics and generate publication-ready figures

function BRT_calculate_and_plot(t, v_noisy, v_fund, v_recon, v_disturbed, ...
                                residuals, res_thresh, fP_chain, n_scales, kernel_sizes, ...
                                fs, f0, include_noise, corr_all, snri_all, snr_in_all, ...
                                snr_out_all, rmse_all, rmse_sag_all, rmse_swell_all, ...
                                rmse_trans_all, include_sag, include_swell, include_trans, elapsed)

%% Console report
dt = t(2) - t(1);
T_actual = t(end) - t(1) + dt;
n_cycles_actual = T_actual * f0;

fprintf('\n=== SIGNAL CONFIGURATION ===\n');
fprintf('  Sampling: %d Hz | Duration: %.2f s | Cycles: %d\n', fs, T_actual, round(n_cycles_actual));
fprintf('  Samples:  %d\n', length(t));

fprintf('\n=== COMPONENTS ===\n');
fprintf('  Fundamental:  YES\n');
if include_sag,   fprintf('  Sag:          YES\n'); else, fprintf('  Sag:          NO\n');  end
if include_swell, fprintf('  Swell:        YES\n'); else, fprintf('  Swell:        NO\n');  end
if include_trans, fprintf('  Transient:    YES\n'); else, fprintf('  Transient:    NO\n');  end
if include_noise, fprintf('  Noise:        YES\n'); else, fprintf('  Noise:        NO\n');  end

fprintf('\n=== PERFORMANCE METRICS (mean +/- std over trials) ===\n');
fprintf('  Correlation: %.4f +/- %.4f\n',   mean(corr_all), std(corr_all));

if include_noise
    fprintf('  SNRI:        %.2f +/- %.2f dB\n', mean(snri_all, 'omitnan'), std(snri_all, 'omitnan'));
    fprintf('  Input SNR:   %.2f +/- %.2f dB\n', mean(snr_in_all, 'omitnan'), std(snr_in_all, 'omitnan'));
    fprintf('  Output SNR:  %.2f +/- %.2f dB\n', mean(snr_out_all, 'omitnan'), std(snr_out_all, 'omitnan'));
else
    fprintf('  SNRI:        N/A (no noise in signal)\n');
    fprintf('  Input SNR:   N/A (no noise in signal)\n');
    fprintf('  Output SNR:  N/A (no noise in signal)\n');
end

fprintf('  RMSE:        %.6f +/- %.6f pu\n', mean(rmse_all), std(rmse_all));

if include_sag
    fprintf('  Sag RMSE:    %.6f +/- %.6f pu\n', mean(rmse_sag_all), std(rmse_sag_all));
end
if include_swell
    fprintf('  Swell RMSE:  %.6f +/- %.6f pu\n', mean(rmse_swell_all), std(rmse_swell_all));
end
if include_trans
    fprintf('  Transient RMSE: %.6f +/- %.6f pu\n', mean(rmse_trans_all), std(rmse_trans_all));
end

thd_in  = compute_THD_compliant(v_noisy, fs, f0);
thd_out = compute_THD_compliant(v_recon, fs, f0);
fprintf('  Input THD:   %.2f%% | Output THD: %.2f%% | Reduction: %.2f%%\n', ...
        thd_in, thd_out, thd_in - thd_out);

pat_sep = pattern_separation(residuals, n_scales);
fprintf('\n=== INTERPRETABILITY METRICS ===\n');
fprintf('  Pattern Separation: %.4f  (1 = perfect, 0 = all energy in one scale)\n', pat_sep);

fprintf('\n=== COMPUTATIONAL PERFORMANCE ===\n');
fprintf('  Execution Time:   %.3f s\n', elapsed);
fprintf('  Processing Speed: %.0f samples/s\n', length(t) / elapsed);

%% Visualization
plot_brt_results(t, v_noisy, v_fund, v_recon, v_disturbed, ...
                 residuals, res_thresh, fP_chain, n_scales, kernel_sizes, ...
                 fs, f0, include_noise);

end

function plot_brt_results(t, v_noisy, v_fund, v_recon, v_disturbed, ...
                          residuals, res_thresh, fP_chain, n_scales, kernel_sizes, ...
                          fs, f0, include_noise)

    %% GLOBAL DEFAULTS (force white background on all new figures)
    set(groot, 'defaultFigureColor',          [1 1 1]);
    set(groot, 'defaultAxesColor',            [1 1 1]);
    set(groot, 'defaultFigureInvertHardcopy', 'off');

    %% IEEE-COMPLIANT COLOUR PALETTE
    CLR_NOISY = [0.00  0.45  0.70];
    CLR_FUND  = [0.80  0.25  0.15];
    CLR_REF   = [0.50  0.50  0.50];
    CLR_EXTRA = [0.55  0.20  0.65];

    CLR_BG    = [1.00  1.00  1.00];
    CLR_AX    = [1.00  1.00  1.00];
    CLR_TXT   = [0.10  0.10  0.10];
    CLR_GRID  = [0.80  0.80  0.80];

    CLR_SCALE = [...
        0.00  0.45  0.70;
        0.80  0.25  0.15;
        0.00  0.62  0.45;
        0.90  0.55  0.00;
        0.55  0.20  0.65;
        0.30  0.75  0.93];

    LS_SCALE = {'-', '-', '-', '-', '-', '-'};

    %% IEEE TYPOGRAPHY (reduced for smaller figure dimensions)
    IEEE_FONT    = 'Times New Roman';
    FONT_LABEL   = 8;
    FONT_TICK    = 7;
    FONT_TITLE   = 8;
    FONT_SGTITLE = 9;
    FONT_LEGEND  = 7;
    FONT_ANNOT   = 7;

    LW_PRIMARY   = 1.00;
    LW_SECONDARY = 0.60;
    LW_GRID_REF  = 0.75;
    LW_THIN      = 0.40;

    MK_SIZE = 4;

    %% Helper: apply IEEE axis styling (static export -- interactivity off)
    function ieee_ax(ax)
        set(ax, ...
            'Color',          CLR_AX,   ...
            'GridColor',      CLR_GRID, ...
            'MinorGridColor', CLR_GRID, ...
            'XColor',         CLR_TXT,  ...
            'YColor',         CLR_TXT,  ...
            'ZColor',         CLR_TXT,  ...
            'FontName',       IEEE_FONT,...
            'FontSize',       FONT_TICK,...
            'LineWidth',      0.60,     ...
            'TickDir',        'in',     ...
            'TickLength',     [0.012 0.018], ...
            'Box',            'on',     ...
            'XGrid',          'on',     ...
            'YGrid',          'on',     ...
            'GridLineStyle',  '--',     ...
            'GridAlpha',      0.40);
        disableDefaultInteractivity(ax);
        ax.Toolbar.Visible = 'off';
    end

    function ieee_xlabel(ax, str)
        xlabel(ax, str, 'FontName', IEEE_FONT, 'FontSize', FONT_LABEL, 'Color', CLR_TXT);
    end
    function ieee_ylabel(ax, str)
        ylabel(ax, str, 'FontName', IEEE_FONT, 'FontSize', FONT_LABEL, 'Color', CLR_TXT);
    end
    function ieee_title(ax, str)
        title(ax, str, 'FontName', IEEE_FONT, 'FontSize', FONT_TITLE, ...
              'FontWeight', 'bold', 'Color', CLR_TXT);
    end
    function ieee_legend(ax, entries, varargin)
        lg = legend(ax, entries, 'Location', 'best', 'AutoUpdate', 'off', ...
                    'FontName', IEEE_FONT, 'FontSize', FONT_LEGEND, ...
                    'Box', 'on', 'Color', CLR_AX, 'EdgeColor', CLR_GRID, ...
                    varargin{:});
        lg.ItemTokenSize = [12, 6];
    end

    tm = t * 1000;   % time axis in ms

    %% FIGURE 1 -- Input Signal + BRT Scale Residuals
    %% Row 0 (top): Input vs Fundamental (full width)
    %% Rows 1-3: Scale residuals, 2 columns x 3 rows
    %% Size: 7.16 x 3.5 in (IEEE double-column horizontal)

    FIG1_W = 7.16;
    FIG1_H = 3.50;

    fig1 = figure('Name',           'BRT -- Signal Analysis (IEEE)', ...
                  'Color',          CLR_BG,              ...
                  'NumberTitle',    'off',                ...
                  'Units',          'inches',             ...
                  'Position',       [0.5 4.0 FIG1_W FIG1_H], ...
                  'InvertHardcopy', 'off');

    % --- Input signal panel: full width at top ---
    % [left  bottom  width  height]  -- all normalised 0-1
    ax_in = axes('Parent', fig1, 'Position', [0.07  0.78  0.90  0.16]); %#ok<LAXES>
    ieee_ax(ax_in);
    plot(ax_in, tm, v_noisy, '-',  'Color', CLR_NOISY, 'LineWidth', LW_SECONDARY);
    hold(ax_in, 'on');
    plot(ax_in, tm, v_fund,  '--', 'Color', CLR_FUND,  'LineWidth', LW_PRIMARY);
    xlim(ax_in, [tm(1) tm(end)]);
    ieee_title(ax_in,  'Input Signal vs. Fundamental');
    ieee_ylabel(ax_in, 'Amp (pu)');
    set(ax_in, 'XTickLabel', {});
    ieee_legend(ax_in, {'Input', 'Fundamental'});

    % --- Residual strip hardcoded positions ---
    % 2 columns, 3 rows, left-to-right top-to-bottom
    % [left  bottom  width  height]
    scale_positions = {
        [0.07,  0.54,  0.43,  0.18],   % r1  -- row 1 left
        [0.54,  0.54,  0.43,  0.18],   % r2  -- row 1 right
        [0.07,  0.32,  0.43,  0.18],   % r3  -- row 2 left
        [0.54,  0.32,  0.43,  0.18],   % r4  -- row 2 right
        [0.07,  0.10,  0.43,  0.18],   % r5  -- row 3 left
        [0.54,  0.10,  0.43,  0.18],   % r6  -- row 3 right
    };

    for s = 1:n_scales
        ax_s = axes('Parent', fig1, 'Position', scale_positions{s}); %#ok<LAXES>
        ieee_ax(ax_s);

        % Raw residual (faded) -- y-axis based on raw for correct scaling
        plot(ax_s, tm, residuals{s}, '-', ...
             'Color', CLR_SCALE(s,:) + 0.50*(1 - CLR_SCALE(s,:)), ...
             'LineWidth', LW_THIN);
        hold(ax_s, 'on');

        % Thresholded residual (solid)
        plot(ax_s, tm, res_thresh{s}, '-', ...
             'Color', CLR_SCALE(s,:), 'LineWidth', LW_PRIMARY);

        % Zero reference
        yline(ax_s, 0, '--', 'Color', CLR_REF, 'LineWidth', 0.5, ...
              'HandleVisibility', 'off');

        % xlim identical on ALL panels -- prevents xlabel side-effect on r5/r6
        xlim(ax_s, [tm(1) tm(end)]);

        % ylim based on RAW residual 99th percentile -- not thresholded
        % This prevents the flooded-colour artefact when thresholded ~ 0
        p99 = prctile(abs(residuals{s}), 99);
        if p99 > eps
            ylim(ax_s, [-p99, p99]);
        end

        % Panel title
        if s < n_scales
            title_str = sprintf('r_{%d}(t),  W = %d', s, kernel_sizes(s));
        else
            title_str = sprintf('r_{%d}(t)  [Coarse]', s);
        end
        ieee_title(ax_s, title_str);
        ieee_ylabel(ax_s, 'Amp (pu)');

        % x-label on bottom row only (s = 5 and 6), suppressed on rows 1-2
        if s >= n_scales - 1
            ieee_xlabel(ax_s, 'Time (ms)');
        else
            set(ax_s, 'XTickLabel', {});
        end

        % Legend on first panel only
        if s == 1
            ieee_legend(ax_s, {'Raw', 'Thresholded'});
        end
    end

    sgtitle(fig1, ...
        'Bayesian Residual Transform \rm--- Power Quality Decomposition', ...
        'FontName', IEEE_FONT, 'FontSize', FONT_SGTITLE, ...
        'FontWeight', 'bold', 'Color', CLR_TXT);

    set(fig1, 'PaperUnits',     'inches',            ...
              'PaperSize',      [FIG1_W  FIG1_H],    ...
              'PaperPosition',  [0 0 FIG1_W FIG1_H], ...
              'InvertHardcopy', 'off');

    export_ieee_fig(fig1, 'BRT_Fig1_Signal_Analysis', 1);


    %% FIGURE 3 -- Forward BRT Cascade
    %% Smoothed approximation f_{P,j+1}(t) vs fundamental only
    %% (input signal removed)
    %% Layout: 2 columns x 3 rows, hardcoded positions
    %% Size: 7.16 x 3.5 in (IEEE double-column horizontal)

    FIG3_W = 7.16;
    FIG3_H = 3.50;

    fig3 = figure('Name',           'BRT -- Forward Cascade (IEEE)', ...
                  'Color',          CLR_BG,              ...
                  'NumberTitle',    'off',                ...
                  'Units',          'inches',             ...
                  'Position',       [0.5 0.5 FIG3_W FIG3_H], ...
                  'InvertHardcopy', 'off');

    % Hardcoded panel positions for n_plots = n_scales-1 = 5
    % 2 columns x 3 rows (last row has only 1 panel if n_plots is odd)
    % [left  bottom  width  height]
    cascade_positions = {
        [0.07,  0.68,  0.43,  0.22],   % j=1  -- row 1 left
        [0.54,  0.68,  0.43,  0.22],   % j=2  -- row 1 right
        [0.07,  0.38,  0.43,  0.22],   % j=3  -- row 2 left
        [0.54,  0.38,  0.43,  0.22],   % j=4  -- row 2 right
        [0.07,  0.08,  0.43,  0.22],   % j=5  -- row 3 left
    };

    n_plots = n_scales - 1;

    for j = 1:n_plots
        ax_c = axes('Parent', fig3, 'Position', cascade_positions{j}); %#ok<LAXES>
        ieee_ax(ax_c);

        % Smoothed approximation (coloured) + fundamental (dashed red)
        plot(ax_c, tm, fP_chain{j+1}, LS_SCALE{j}, ...
             'Color', CLR_SCALE(j,:), 'LineWidth', LW_PRIMARY);
        hold(ax_c, 'on');
        plot(ax_c, tm, v_fund, '--', ...
             'Color', CLR_FUND, 'LineWidth', LW_SECONDARY);

        % xlim identical on all panels
        xlim(ax_c, [tm(1) tm(end)]);

        % ylim scaled to smoothed approximation range
        y_lo  = min(fP_chain{j+1});
        y_hi  = max(fP_chain{j+1});
        y_pad = max((y_hi - y_lo) * 0.08, eps);
        ylim(ax_c, [y_lo - y_pad, y_hi + y_pad]);

        % Panel title (LaTeX)
        t_str = sprintf('$\\hat{f}_{P,%d}(t)$,  W = %d', j+1, kernel_sizes(j));
        title(ax_c, t_str, 'Interpreter', 'latex', ...
              'FontName', IEEE_FONT, 'FontSize', FONT_TITLE, ...
              'FontWeight', 'bold', 'Color', CLR_TXT);

        ieee_ylabel(ax_c, 'Amp (pu)');

        % x-label on bottom row panels only
        if j >= n_plots - 1
            ieee_xlabel(ax_c, 'Time (ms)');
        else
            set(ax_c, 'XTickLabel', {});
        end

        % Legend on first panel only
        if j == 1
            ieee_legend(ax_c, {'Smoothed', 'Fundamental'});
        end
    end

    sgtitle(fig3, ...
        'Forward BRT Cascade \rm--- Smoothed Approximations $\hat{f}_{P,j}(t)$', ...
        'Interpreter', 'latex', ...
        'FontName', IEEE_FONT, 'FontSize', FONT_SGTITLE, ...
        'FontWeight', 'bold', 'Color', CLR_TXT);

    set(fig3, 'PaperUnits',     'inches',            ...
              'PaperSize',      [FIG3_W  FIG3_H],    ...
              'PaperPosition',  [0 0 FIG3_W FIG3_H], ...
              'InvertHardcopy', 'off');

    export_ieee_fig(fig3, 'BRT_Fig3_Cascade', 3);


    %% FIGURE 5 -- Scale-wise SNRI and THD
    %% Size: 3.5 x 3.5 in (IEEE square, small)
    fprintf('\n=== GENERATING SCALE-WISE SNRI AND THD PLOT ===\n');
    fig5 = plot_scalewise_snri_thd(t, v_fund, v_noisy, v_disturbed, ...
                                   residuals, res_thresh, n_scales, fs, f0, include_noise);
    export_ieee_fig(fig5, 'BRT_Fig5_Scalewise_SNRI_THD', 5);

end  % =================== END plot_brt_results ==========================


%% SCALE-WISE SNRI AND THD (IEEE-formatted, 3.5 x 3.5 in square)
function fig = plot_scalewise_snri_thd(t, v_fund, v_noisy, v_disturbed, ...
                                  residuals_raw, res_thresh, n_scales, ...
                                  fs, f0, include_noise)

    CLR_BG      = [1.00 1.00 1.00];
    CLR_AX      = [1.00 1.00 1.00];
    CLR_TXT     = [0.10 0.10 0.10];
    CLR_GRID    = [0.80 0.80 0.80];
    CLR_SNRI    = [0.00 0.45 0.70];
    CLR_THD     = [0.80 0.25 0.15];
    CLR_REF     = [0.50 0.50 0.50];
    CLR_EXTRA   = [0.55 0.20 0.65];
    CLR_IEEE519 = [0.90 0.55 0.00];

    IEEE_FONT    = 'Times New Roman';
    FONT_LABEL   = 7;
    FONT_TICK    = 7;
    FONT_TITLE   = 7;
    FONT_SGTITLE = 8;
    FONT_ANNOT   = 6;
    LW_PRIMARY   = 1.00;
    LW_SECONDARY = 0.60;
    LW_GRID_REF  = 0.75;
    MK_SIZE      = 4;

    function ieee_ax(ax)
        set(ax, 'Color', CLR_AX, 'GridColor', CLR_GRID, ...
                'XColor', CLR_TXT, 'YColor', CLR_TXT, ...
                'FontName', IEEE_FONT, 'FontSize', FONT_TICK, ...
                'LineWidth', 0.60, 'TickDir', 'in', ...
                'TickLength', [0.015 0.020], 'Box', 'on', ...
                'XGrid', 'on', 'YGrid', 'on', ...
                'GridLineStyle', '--', 'GridAlpha', 0.40);
        disableDefaultInteractivity(ax);
        ax.Toolbar.Visible = 'off';
    end

    % Baseline SNR (unthresholded reconstruction)
    signal_power = sum(v_disturbed .^ 2);
    v0 = zeros(size(v_noisy));
    for k = 1:n_scales
        v0 = v0 + residuals_raw{k};
    end
    noise0_power = sum((v0 - v_disturbed) .^ 2);
    snr0 = 10 * log10(signal_power / max(noise0_power, eps));

    % --- Progressive thresholding evaluation ---
    n_eval   = n_scales - 1;
    snri_vec = zeros(1, n_eval);
    thd_vec  = zeros(1, n_eval);
    snr_vec  = zeros(1, n_eval);

    for j = 1:n_eval
        v_j = zeros(size(v_noisy));
        for k = 1:n_scales
            if k <= j && k < n_scales
                v_j = v_j + res_thresh{k};
            else
                v_j = v_j + residuals_raw{k};
            end
        end
        noise_j_power = sum((v_j - v_disturbed) .^ 2);
        snr_j         = 10 * log10(signal_power / max(noise_j_power, eps));
        snri_vec(j)   = snr_j - snr0;
        snr_vec(j)    = snr_j;
        thd_vec(j)    = compute_THD_compliant(v_j, fs, f0);
    end

    % --- Axis tick labels ---
    scale_labels = arrayfun(@(j) sprintf('j=%d', j), 1:n_eval, 'UniformOutput', false);
    x_ticks  = 0:n_eval;
    x_labels = [{'Base'}, scale_labels];

    % --- Figure: 3.5 x 3.5 in square ---
    FIG5_W = 3.50;
    FIG5_H = 3.50;

    fig = figure('Name',           'BRT -- Scale-wise SNRI and THD (IEEE)', ...
                 'Color',          CLR_BG,              ...
                 'NumberTitle',    'off',                ...
                 'Units',          'inches',             ...
                 'Position',       [8.5 4.0 FIG5_W FIG5_H], ...
                 'InvertHardcopy', 'off');

    % Hardcoded panel positions
    % [left  bottom  width  height]
    ax1_pos = [0.15  0.56  0.80  0.34];   % SNRI panel (top)
    ax2_pos = [0.15  0.10  0.80  0.34];   % THD  panel (bottom)

    %% --- Top panel: SNRI ---
    ax1 = axes('Parent', fig, 'Position', ax1_pos); %#ok<LAXES>
    ieee_ax(ax1);
    hold(ax1, 'on');

    if include_noise
        plot(ax1, 0, 0, 'o', 'Color', CLR_REF, ...
             'MarkerSize', MK_SIZE, 'MarkerFaceColor', CLR_AX, ...
             'LineWidth', LW_SECONDARY, ...
             'DisplayName', sprintf('Base (%.1f dB)', snr0));

        plot(ax1, 1:n_eval, snri_vec, 'o-', 'Color', CLR_SNRI, ...
             'LineWidth', LW_PRIMARY, 'MarkerSize', MK_SIZE, ...
             'MarkerFaceColor', CLR_SNRI, 'DisplayName', 'SNRI (dB)');

        y_rng = max(range(snri_vec), 0.1);
        for j = 1:n_eval
            text(ax1, j, snri_vec(j) + y_rng*0.10, ...
                 sprintf('%.1f', snri_vec(j)), ...
                 'FontName', IEEE_FONT, 'FontSize', FONT_ANNOT, ...
                 'Color', CLR_SNRI, 'HorizontalAlignment', 'center', ...
                 'VerticalAlignment', 'bottom');
        end

        yline(ax1, 0, '--', 'Color', CLR_REF, 'LineWidth', 0.5, ...
              'HandleVisibility', 'off');

        yyaxis(ax1, 'right');
        plot(ax1, 1:n_eval, snr_vec, 's--', 'Color', CLR_EXTRA, ...
             'LineWidth', LW_SECONDARY, 'MarkerSize', MK_SIZE - 1, ...
             'MarkerFaceColor', CLR_EXTRA, 'DisplayName', 'SNR_{out} (dB)');
        ylabel(ax1, 'SNR_{out} (dB)', 'FontName', IEEE_FONT, ...
               'FontSize', FONT_LABEL, 'Color', CLR_TXT);
        ax1.YAxis(2).Color    = CLR_TXT;
        ax1.YAxis(2).FontName = IEEE_FONT;
        ax1.YAxis(2).FontSize = FONT_TICK;
        yyaxis(ax1, 'left');

        ylabel(ax1, 'SNRI (dB)', 'FontName', IEEE_FONT, ...
               'FontSize', FONT_LABEL, 'Color', CLR_TXT);
        ax1.YAxis(1).Color = CLR_TXT;

        lg1 = legend(ax1, 'Location', 'southeast', 'AutoUpdate', 'off', ...
                     'FontName', IEEE_FONT, 'FontSize', FONT_ANNOT, ...
                     'Box', 'on', 'Color', CLR_AX, 'EdgeColor', CLR_GRID);
        lg1.ItemTokenSize = [10 5];
    else
        text(ax1, 0.50, 0.50, 'N/A --- No noise component', ...
             'Units', 'normalized', 'HorizontalAlignment', 'center', ...
             'FontName', IEEE_FONT, 'FontSize', FONT_LABEL, 'Color', CLR_REF);
        ylabel(ax1, 'SNRI (dB)', 'FontName', IEEE_FONT, ...
               'FontSize', FONT_LABEL, 'Color', CLR_TXT);
    end

    title(ax1, 'Scale-wise SNRI', ...
          'FontName', IEEE_FONT, 'FontSize', FONT_TITLE, ...
          'FontWeight', 'bold', 'Color', CLR_TXT);
    xlim(ax1, [-0.5, n_eval + 0.5]);
    xticks(ax1, x_ticks);
    set(ax1, 'XTickLabel', {});
    ax1.XAxis.FontName = IEEE_FONT;
    ax1.XAxis.FontSize = FONT_TICK;

    %% --- Bottom panel: THD ---
    ax2 = axes('Parent', fig, 'Position', ax2_pos); %#ok<LAXES>
    ieee_ax(ax2);
    hold(ax2, 'on');

    thd_baseline = compute_THD_compliant(v_noisy, fs, f0);
    plot(ax2, 0, thd_baseline, 'o', 'Color', CLR_REF, ...
         'MarkerSize', MK_SIZE, 'MarkerFaceColor', CLR_AX, ...
         'LineWidth', LW_SECONDARY, ...
         'DisplayName', sprintf('Base %.2f%%', thd_baseline));

    plot(ax2, 1:n_eval, thd_vec, 'o-', 'Color', CLR_THD, ...
         'LineWidth', LW_PRIMARY, 'MarkerSize', MK_SIZE, ...
         'MarkerFaceColor', CLR_THD, 'DisplayName', 'THD (%)')

    y_rng2 = max(range([thd_baseline thd_vec]), 0.1);
    for j = 1:n_eval
        text(ax2, j, thd_vec(j) + y_rng2*0.10, ...
             sprintf('%.1f%%', thd_vec(j)), ...
             'FontName', IEEE_FONT, 'FontSize', FONT_ANNOT, ...
             'Color', CLR_THD, 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', 'bottom');
    end

    yline(ax2, 5, '--', 'Color', CLR_IEEE519, 'LineWidth', LW_GRID_REF, ...
          'Label', 'IEEE 519 (5%)', ...
          'LabelHorizontalAlignment', 'left', ...
          'LabelVerticalAlignment',   'bottom', ...
          'FontName', IEEE_FONT, 'FontSize', FONT_ANNOT, ...
          'HandleVisibility', 'off');

    title(ax2, 'Scale-wise THD', ...
          'FontName', IEEE_FONT, 'FontSize', FONT_TITLE, ...
          'FontWeight', 'bold', 'Color', CLR_TXT);
    xlabel(ax2, 'Thresholded scales (j)', ...
           'FontName', IEEE_FONT, 'FontSize', FONT_LABEL, 'Color', CLR_TXT);
    ylabel(ax2, 'THD (%)', 'FontName', IEEE_FONT, ...
           'FontSize', FONT_LABEL, 'Color', CLR_TXT);
    xlim(ax2, [-0.5, n_eval + 0.5]);
    xticks(ax2, x_ticks);
    xticklabels(ax2, x_labels);
    ax2.XAxis.FontName = IEEE_FONT;
    ax2.XAxis.FontSize = FONT_TICK;

    lg2 = legend(ax2, 'Location', 'best', 'AutoUpdate', 'off', ...
                 'FontName', IEEE_FONT, 'FontSize', FONT_ANNOT, ...
                 'Box', 'on', 'Color', CLR_AX, 'EdgeColor', CLR_GRID);
    lg2.ItemTokenSize = [10 5];

    sgtitle(fig, ...
        'BRT: SNRI and THD vs. Thresholded Scales', ...
        'FontName', IEEE_FONT, 'FontSize', FONT_SGTITLE, ...
        'FontWeight', 'bold', 'Color', CLR_TXT);

    set(fig, 'PaperUnits',     'inches',            ...
             'PaperSize',      [FIG5_W  FIG5_H],    ...
             'PaperPosition',  [0 0 FIG5_W FIG5_H], ...
             'InvertHardcopy', 'off');

end  % ============== END plot_scalewise_snri_thd ========================


%% IEEE Figure Export Helper (300 DPI PNG + .fig)
function export_ieee_fig(fig, filename, fig_num)
    try
        if ~exist('export', 'dir')
            mkdir('export');
        end
        out_png = fullfile('export', [filename '.png']);
        out_fig = fullfile('export', [filename '.fig']);
        print(fig, out_png, '-dpng', '-r300');
        savefig(fig, out_fig);
        fprintf('Exported Figure %d: export/%s.png  (300 DPI)\n', fig_num, filename);
    catch ME
        fprintf('Warning -- export failed for %s: %s\n', filename, ME.message);
    end
end

%% Helpers (duplicate stubs for scope isolation)
function thd = compute_THD_compliant(v, fs, f0, n_harm, use_hann)
    if nargin < 4, n_harm   = 50;    end
    if nargin < 5, use_hann = false; end
    v = v - mean(v);
    if f0 == 50, window_cycles = 10; else, window_cycles = 12; end
    window_samples = round(window_cycles * fs / f0);
    if window_samples > length(v), window_samples = length(v); end
    v_window = v(1:window_samples);
    if use_hann
        w        = hann(window_samples);
        v_window = v_window .* w;
        V        = abs(fft(v_window)) * (2 / sum(w));
    else
        V = abs(fft(v_window)) / window_samples * 2;
    end
    V    = V(1:floor(window_samples/2)+1);
    V(1) = V(1)/2;
    f_res = fs / window_samples;
    bin1 = round(f0 / f_res) + 1;
    if bin1 > 1 && bin1 < length(V)
        V1 = sqrt(V(bin1-1)^2 + V(bin1)^2 + V(bin1+1)^2);
    else
        V1 = max(V);
    end
    harm_sq = 0;
    for k = 2:n_harm
        hbin = round(k * f0 / f_res) + 1;
        if hbin > 1 && hbin < length(V)
            Vk      = sqrt(V(hbin-1)^2 + V(hbin)^2 + V(hbin+1)^2);
            harm_sq = harm_sq + Vk^2;
        end
    end
    thd = 100 * sqrt(harm_sq) / max(V1, eps);
end

function ps = pattern_separation(residuals, n)
    energy  = cellfun(@(r) sum(r.^2), residuals);
    E_total = sum(energy) + eps;
    ps      = 1 - sum((energy / E_total).^2);
end
