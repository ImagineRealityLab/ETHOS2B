clear
clc
close all
addpath("Utilities")
addpath(genpath("MVPA-Light-master"));
addpath(genpath("behavioural\"))
seed = 42;
rng(seed)

subjects = {'subj-1', 'subj-2', 'subj-3', 'subj-4', 'subj-5'};

nIters = 20;
nBins  = 10;

results       = cell(1, length(subjects));   % per-subject iter-averaged perf
results_iter  = cell(1, length(subjects));   % per-subject all-iteration perf (T x nIters)
trialsRemoved = zeros(1, length(subjects));
trialsStart   = zeros(1, length(subjects));
ERFs = cell(4, length(subjects));

viv_diffsAll = cell(1, length(subjects));

for iSubj = 1:length(subjects)

    meg_data = load(fullfile('results', subjects{iSubj}, 'Preprocessed_ICAclean_realigned.mat'));
    meg_data = meg_data.data_ica_clean;

    cfg = [];
    cfg.channel = 'MEG';
    meg_all = ft_selectdata(cfg, meg_data);

    all_trials_meg_3d = cat(3, meg_all.trial{:});   % features x time x samples

    rejection_hist = load(fullfile('results', subjects{iSubj}, 'rejection_log.mat'));
    rejection_hist = rejection_hist.rejection_log;

    allRejectedTrials = [];
    if iSubj == 1
        for iRun = 1:8
            allRejectedTrials = [allRejectedTrials, rejection_hist(1,iRun).trials_removed];
        end
    else
        for iRun = 1:length(rejection_hist)
            allRejectedTrials = [allRejectedTrials, rejection_hist(1,iRun).trialsRemovedGlobal];
        end
    end


    beh_data = load(sprintf('PMT_%d.mat', iSubj));

    block_info    = beh_data.blocks;
    trial_info    = beh_data.trials;
    response_info = beh_data.R;

    cond         = block_info(:,2);
    presence     = trial_info(:,:,1);
    detection    = response_info(:,:,3);
    reproduction = response_info(:,:,1);
    grating      = block_info(:,1);

    nRuns  = size(block_info,1) / 2;
    nTrial = size(presence,2);

    conditionPerTrial = repmat(cond,1,nTrial);
    oriPerTrial       = repmat(grating,1,nTrial);
    runPerTrial       = repmat((1:nRuns)',1,nTrial);

    allRuns = [];
    for iRun = 1:nRuns
        allRuns = [allRuns; runPerTrial(iRun, :); runPerTrial(iRun, :)];
    end

    meta.condition    = reshape(conditionPerTrial',[],1);
    meta.orientation  = reshape(oriPerTrial',[],1);
    meta.presence     = reshape(presence',[],1);
    meta.detection    = reshape(detection',[],1);
    meta.reproduction = reshape(reproduction',[],1);
    meta.run          = reshape(allRuns',[],1);

    nTotalTrials = length(meta.condition);
    keepMask = true(nTotalTrials,1);
    keepMask(allRejectedTrials) = false;

    meta.condition    = meta.condition(keepMask);
    meta.orientation  = meta.orientation(keepMask);
    meta.presence     = meta.presence(keepMask);
    meta.detection    = meta.detection(keepMask);
    meta.reproduction = meta.reproduction(keepMask);
    meta.run          = meta.run(keepMask);

    keepMask = true(length(meta.run),1);
    keepMask(isnan(meta.reproduction)) = false;
    keepMask(isnan(meta.detection))    = false;

    meta.condition    = meta.condition(keepMask);
    meta.orientation  = meta.orientation(keepMask);
    meta.presence     = meta.presence(keepMask);
    meta.detection    = meta.detection(keepMask);
    meta.reproduction = meta.reproduction(keepMask);
    meta.run          = meta.run(keepMask);

    all_trials_meg_3d = all_trials_meg_3d(:,:,keepMask);


    img_idx       = find(meta.condition == 1);          % all imagery trials
    vividness_img = meta.reproduction(img_idx);
    detection_img = meta.detection(img_idx);
    nImg          = numel(img_idx);

   
    edges    = quantile(vividness_img, linspace(0, 1, nBins+1));
    edges(1) = -inf; edges(end) = inf;
    binIdx   = discretize(vividness_img, edges);

    toKeepAll = false(nImg, nIters);   
    for it = 1:nIters
        toKeep = false(nImg, 1);
        for b = 1:nBins
            yesBin = find(detection_img == 1 & binIdx == b);
            noBin  = find(detection_img == 0 & binIdx == b);
            nB     = min(numel(yesBin), numel(noBin));
            if nB == 0, continue; end
            toKeep(yesBin(randperm(numel(yesBin), nB))) = true;
            toKeep(noBin (randperm(numel(noBin ), nB))) = true;
        end
        toKeepAll(:, it) = toKeep;
    end

    viv_diffs = nan(nIters, 1);
    for it = 1:nIters
        m = toKeepAll(:, it);
        viv_diffs(it) = mean(vividness_img(m & detection_img==1)) - mean(vividness_img(m & detection_img==0));
    end
    fprintf('Across-iter vividness diff: mean = %.4f, SD = %.4f\n', mean(viv_diffs), std(viv_diffs));
    viv_diffsAll{iSubj} = viv_diffs;

    trialsRemoved(iSubj) = mean(sum(toKeepAll == 0));
    trialsStart(iSubj) = sum(meta.condition == 1);
    

    img_yesTrials = find(meta.condition == 1 & meta.detection == 1);
    labels_train  = zscore(meta.reproduction(img_yesTrials));
    meg_train     = all_trials_meg_3d(:,:,img_yesTrials);
    X_train       = permute(meg_train, [3 1 2]);
    trainRunNo    = meta.run(img_yesTrials);

    sample_rate = meg_data.time{1,1}(2) - meg_data.time{1,1}(1);
    smoothing   = 0.04;
    tp          = smoothing / sample_rate;
    X_train     = movmean(X_train, tp, 3);

    time_axis   = meg_all.time{1};
    nTimepoints = numel(time_axis);
    runs        = unique(meta.run)';


    all_iter_perf = nan(nTimepoints, nIters);

    for it = 1:nIters
        toKeep      = toKeepAll(:, it);
        testAbs     = img_idx(toKeep);                  
        labels_test = meta.detection(testAbs);
        meg_test    = all_trials_meg_3d(:,:,testAbs);
        X_test      = permute(meg_test, [3 1 2]);
        X_test      = movmean(X_test, tp, 3);
        testRunNo   = meta.run(testAbs);

        performance = zeros(nTimepoints, 1);
        nRunsUsed   = 0;

        for iRun = runs
            inTest  = testRunNo  == iRun;
            if sum(inTest) < 2
                continue
            end
            inTrain = trainRunNo ~= iRun;
            if ~any(inTest) || ~any(inTrain), continue; end

            cfg = [];
            cfg.model              = 'ridge';
            cfg.metric             = 'r';
            cfg.lambda             = [10^-1, 1, 10, 100, 1000];
            cfg.preprocess         = {'zscore', 'pca'};
            cfg.preprocess_param   = {};
            cfg.preprocess_param{2} = [];
            cfg.preprocess_param{2}.explained_variance = 0.95;

            [perf, ~] = mv_regress(cfg, ...
                X_train(inTrain,:,:), labels_train(inTrain), ...
                X_test (inTest ,:,:), labels_test (inTest ));

            performance = performance + perf;
            nRunsUsed   = nRunsUsed + 1;
        end

        if nRunsUsed > 0
            all_iter_perf(:, it) = performance ./ nRunsUsed;
        end
    end

    % Average across iterations -> the per-subject result
    perf_mean = mean(all_iter_perf, 2, 'omitnan');


    figure;
    iter_sd = std(all_iter_perf, 0, 2, 'omitnan');
    fill([time_axis(:); flipud(time_axis(:))], ...
         [movmean(perf_mean,20) - iter_sd; flipud(movmean(perf_mean,20) + iter_sd)], ...
         [0.5 0.5 0.5], 'FaceAlpha', 0.2, 'EdgeColor', 'none'); hold on;
    plot(time_axis, movmean(perf_mean, 20), 'k', 'LineWidth', 2);
    xlabel('Time (s)'); ylabel('Correlation (r)');
    title(sprintf('Diagonal decoding - Subject %d (avg over %d iters)', iSubj, nIters));
    xline(-1.85, '--', 'First beep',  'LineWidth', 2);
    xline(-0.95, '--', 'Second beep', 'LineWidth', 2);
    xline(0,     '--', 'Last beep',   'LineWidth', 2);
    xlim([-2.4, 0.7]);

    results{iSubj}      = perf_mean;
    results_iter{iSubj} = all_iter_perf;
    save(fullfile('results', subjects{iSubj}, 'TT2_results.mat'), ...
     'perf_mean', 'all_iter_perf', 'time_axis', 'toKeepAll', ...
     'nIters', 'nBins', 'seed', '-v7.3');

end  % iSubj

plot_with_shade = @(x, y, sd, col) ...
    fill([x; flipud(x)], [y - sd; flipud(y + sd)], col, ...
         'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');

x = time_axis(:);
all_diag = [];
for iSubj = 1:length(results)
    if isempty(results{iSubj}), continue; end
    all_diag(:, end+1) = results{iSubj};
end

mean_diag = mean(all_diag, 2);
sd_diag   = std(all_diag, 0, 2);

figure; hold on;
plot_with_shade(x, mean_diag, sd_diag, [0 0.447 0.941]);
plot(x, mean_diag, 'Color', [0 0.447 0.941], 'LineWidth', 3);
yline(0, 'k--', 'LineWidth', 1);
xline(0, 'k--', 'LineWidth', 1);
xline(-1.85, '--', 'First beep',  'LineWidth', 3, 'HandleVisibility', 'off');
xline(-0.95, '--', 'Second beep', 'LineWidth', 3, 'HandleVisibility', 'off');
xline(0,     '--',   'LineWidth', 3, 'HandleVisibility', 'off');
xlim([-0.2, 0.7]);
ax = gca; ax.FontSize = 30; ax.FontWeight = 'bold';
box off;

percentage = trialsRemoved ./ trialsStart;

% Visualize empirical effect of the downsampling procedure on vividness
% Assumes viv_diffsAll, trialsRemoved, trialsStart, subjects are in the workspace
% from running the main pipeline.

%% Recompute the unmatched (raw) yes-no vividness difference per subject
unmatched_diff = nan(1, length(subjects));
for iSubj = 1:length(subjects)
    % Reload the behavioural data to get the raw vividness/detection for imagery trials
    beh = load(sprintf('PMT_%d.mat', iSubj));
    block_info    = beh.blocks;
    presence      = beh.trials(:,:,1);
    detection     = beh.R(:,:,3);
    reproduction  = beh.R(:,:,1);
    cond          = block_info(:,2);
    nTrial        = size(presence, 2);

    conditionPerTrial = repmat(cond, 1, nTrial);
    cond_vec = reshape(conditionPerTrial', [], 1);
    det_vec  = reshape(detection',     [], 1);
    rep_vec  = reshape(reproduction',  [], 1);

    valid = ~isnan(rep_vec) & ~isnan(det_vec) & (cond_vec == 1);
    rep_img = rep_vec(valid);
    det_img = det_vec(valid);

    unmatched_diff(iSubj) = mean(rep_img(det_img==1)) - mean(rep_img(det_img==0));
end

%% Per-subject matched: mean and SD across iterations
matched_mean = cellfun(@mean, viv_diffsAll);
matched_sd   = cellfun(@std,  viv_diffsAll);
percent_dropped = 100 * trialsRemoved ./ trialsStart;

%% Figure 1: Per-subject before vs after (with iteration SD on matched)
figure('Position', [100 100 700 450]); hold on;

xPos = 1:length(subjects);
b1 = bar(xPos - 0.2, unmatched_diff, 0.35, 'FaceColor', [0.55 0.55 0.55], ...
    'EdgeColor', 'none', 'DisplayName', 'Before matching');
b2 = bar(xPos + 0.2, matched_mean,    0.35, 'FaceColor', [0.25 0.65 0.45], ...
    'EdgeColor', 'none', 'DisplayName', 'After matching');

errorbar(xPos + 0.2, matched_mean, matched_sd, 'k', ...
    'LineStyle', 'none', 'LineWidth', 1.2, 'CapSize', 6, 'HandleVisibility', 'off');

yline(0, 'k:', 'HandleVisibility', 'off');
set(gca, 'XTick', xPos, 'XTickLabel', subjects);
ylabel('Vividness yes - no');
title('Empirical effect of matching on the behavioural confound');
legend('Location', 'best'); box off;

%% Figure 2: Pooled distribution of matched residuals across subjects
figure('Position', [100 100 700 400]); hold on;

allMatched = cell2mat(cellfun(@(x) x(:), viv_diffsAll, 'UniformOutput', false)');
histogram(allMatched, 25, 'FaceColor', [0.25 0.65 0.45], 'EdgeColor', 'none');
xline(0, 'k--', 'LineWidth', 1.5);
xline(mean(allMatched), '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 2, ...
    'Label', sprintf('mean = %.4f', mean(allMatched)));
xlabel('Vividness yes - no after matching');
ylabel('Count (subjects \times iterations)');
title(sprintf('Pooled matched residuals  (n = %d subjects \\times %d iterations)', ...
    length(subjects), length(viv_diffsAll{1})));
box off;

%% Figure 3: Matched residual vs trial loss (per-subject diagnostic)
figure('Position', [100 100 700 450]); hold on;

scatter(percent_dropped, matched_mean, 100, 'filled', 'MarkerFaceColor', [0.4 0.55 0.75]);
errorbar(percent_dropped, matched_mean, matched_sd, 'LineStyle', 'none', ...
    'Color', [0.4 0.55 0.75], 'LineWidth', 1.2, 'CapSize', 6);
for iSubj = 1:length(subjects)
    text(percent_dropped(iSubj) + 0.8, matched_mean(iSubj), subjects{iSubj}, ...
        'FontSize', 10);
end
yline(0, 'k:');
xlabel('% trials dropped');
ylabel('Vividness yes - no after matching (mean over iterations)');
title('Matching quality vs trial loss per subject');
box off;

%% Print a quick summary
fprintf('\n--- Summary across subjects ---\n');
fprintf('Subject  | unmatched diff | matched mean (SD) | %% trials dropped\n');
for iSubj = 1:length(subjects)
    fprintf('%-8s |     %+.4f     |    %+.4f (%.4f)  |     %5.1f%%\n', ...
        subjects{iSubj}, unmatched_diff(iSubj), ...
        matched_mean(iSubj), matched_sd(iSubj), percent_dropped(iSubj));
end
fprintf('\nGroup: matched mean = %+.4f, SD across subjects = %.4f\n', ...
    mean(matched_mean), std(matched_mean));