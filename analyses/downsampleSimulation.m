clear
clc
close all

%% Configuration
realitySignalMean = 0.5;
realitySignalSD   = 0.5;

vividnessNoiseSD  = 0.3;
rjNoiseSD         = 0.3;
rjThreshold       = 0.5;

nTrials           = 16*24/2;
rng(42);

nRand             = 1000;

%% Latent reality signal and behavioural readouts
realitySignal = normrnd(realitySignalMean, realitySignalSD, [nTrials, 1]);
realitySignal = rescale(realitySignal, 0, 1);

vividness     = realitySignal + normrnd(0, vividnessNoiseSD, [nTrials, 1]);

rjLatent      = realitySignal + normrnd(0, rjNoiseSD, [nTrials, 1]);
rj            = double(rjLatent > rjThreshold);

%% Downsampling
idxRJ_present = find(rj == 1);
idxRJ_absent  = find(rj == 0);
nMin = min(numel(idxRJ_present), numel(idxRJ_absent));

best_diff       = Inf;
best_RJ_present = [];
best_RJ_absent  = [];

for iRand = 1:nRand
    samp_present = idxRJ_present(randperm(numel(idxRJ_present), nMin));
    samp_absent  = idxRJ_absent (randperm(numel(idxRJ_absent ), nMin));

    viv_presentSorted = sort(vividness(samp_present), 'ascend');
    viv_absentSorted  = sort(vividness(samp_absent ), 'ascend');

    diff_val = mean((viv_absentSorted - viv_presentSorted).^2);

    if diff_val < best_diff
        best_diff       = diff_val;
        best_RJ_present = samp_present;
        best_RJ_absent  = samp_absent;
    end
end

keepIdx = false(nTrials, 1);
keepIdx(best_RJ_present) = true;
keepIdx(best_RJ_absent)  = true;

vivDS = vividness(keepIdx);
rjDS  = rj(keepIdx);
rsDS  = realitySignal(keepIdx);

%% fig 1 descriptive
colYes = [0    0.45 0.74];
colNo  = [0.85 0.33 0.10];

figure('Position', [100 100 1300 700], 'Name', 'Descriptive plots');

subplot(2,3,1);
histogram(vividness, 25, 'FaceColor', [0.4 0.55 0.75], 'EdgeColor', 'none');
xline(mean(vividness), 'k--', 'LineWidth', 1.5, 'Label', 'mean');
xlabel('Vividness'); ylabel('Count');
title(sprintf('Vividness distribution  (\\mu = %.2f, \\sigma = %.2f)', ...
    mean(vividness), std(vividness)));
box off;

subplot(2,3,2);
histogram(realitySignal, 25, 'FaceColor', [0.6 0.4 0.65], 'EdgeColor', 'none');
xline(mean(realitySignal), 'k--', 'LineWidth', 1.5, 'Label', 'mean');
xlabel('Reality signal'); ylabel('Count');
title(sprintf('Reality signal distribution  (\\mu = %.2f, \\sigma = %.2f)', ...
    mean(realitySignal), std(realitySignal)));
box off;

subplot(2,3,3);
counts = [sum(rj==1), sum(rj==0)];
b = bar([1 2], counts, 0.6, 'FaceColor', 'flat');
b.CData = [colYes; colNo];
set(gca, 'XTick', [1 2], 'XTickLabel', {'yes', 'no'});
ylabel('Number of trials');
title(sprintf('RJ response counts  (%.0f%% yes)', 100*counts(1)/sum(counts)));
ylim([0 max(counts)*1.15]);
text(1, counts(1)+1.5, sprintf('%d', counts(1)), 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(2, counts(2)+1.5, sprintf('%d', counts(2)), 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
box off;

subplot(2,3,4);
scatter(vividness(rj==1), realitySignal(rj==1), 18, colYes, 'filled', 'MarkerFaceAlpha', 0.6); hold on;
scatter(vividness(rj==0), realitySignal(rj==0), 18, colNo,  'filled', 'MarkerFaceAlpha', 0.6);
xlabel('Vividness'); ylabel('Reality signal');
title(sprintf('Vividness vs reality signal  (r = %.2f)', corr(vividness, realitySignal)));
legend({'yes', 'no'}, 'Location', 'best'); box off;

subplot(2,3,5);
scatter(rjLatent(rj==1), realitySignal(rj==1), 18, colYes, 'filled', 'MarkerFaceAlpha', 0.6); hold on;
scatter(rjLatent(rj==0), realitySignal(rj==0), 18, colNo,  'filled', 'MarkerFaceAlpha', 0.6);
yL = ylim; xline(rjThreshold, 'k--', 'LineWidth', 1.5); ylim(yL);
xlabel('RJ latent variable'); ylabel('Reality signal');
title(sprintf('RJ latent vs reality signal  (r = %.2f)', corr(rjLatent, realitySignal)));
text(rjThreshold, yL(2)*0.95, ' threshold', 'FontSize', 9);
legend({'yes', 'no'}, 'Location', 'best'); box off;

subplot(2,3,6);
histogram(vividness(rj==1), 20, 'FaceColor', colYes, 'EdgeColor', 'none', 'FaceAlpha', 0.6); hold on;
histogram(vividness(rj==0), 20, 'FaceColor', colNo,  'EdgeColor', 'none', 'FaceAlpha', 0.6);
xline(mean(vividness(rj==1)), '-', 'Color', colYes, 'LineWidth', 1.5);
xline(mean(vividness(rj==0)), '-', 'Color', colNo,  'LineWidth', 1.5);
xlabel('Vividness'); ylabel('Count');
title('Vividness by RJ response');
legend({'yes', 'no'}, 'Location', 'best'); box off;

%% fig 2 results
figure('Position', [100 100 1100 600], 'Name', 'Before vs after downsampling');

subplot(2,3,1);
histogram(vividness(rj==1), 20, 'Normalization', 'probability', 'FaceColor', colYes, 'FaceAlpha', 0.6); hold on;
histogram(vividness(rj==0), 20, 'Normalization', 'probability', 'FaceColor', colNo,  'FaceAlpha', 0.6);
title('Vividness by RJ — before'); xlabel('Vividness'); legend('yes', 'no'); box off;

subplot(2,3,2);
histogram(realitySignal(rj==1), 20, 'Normalization', 'probability', 'FaceColor', colYes, 'FaceAlpha', 0.6); hold on;
histogram(realitySignal(rj==0), 20, 'Normalization', 'probability', 'FaceColor', colNo,  'FaceAlpha', 0.6);
title('Reality signal by RJ — before'); xlabel('Reality signal'); legend('yes', 'no'); box off;

subplot(2,3,3);
scatter(vividness(rj==1), realitySignal(rj==1), 15, colYes, 'filled'); hold on;
scatter(vividness(rj==0), realitySignal(rj==0), 15, colNo,  'filled');
xlabel('Vividness'); ylabel('Reality signal'); title('Trials — before'); box off;

subplot(2,3,4);
histogram(vivDS(rjDS==1), 20, 'Normalization', 'probability', 'FaceColor', colYes, 'FaceAlpha', 0.6); hold on;
histogram(vivDS(rjDS==0), 20, 'Normalization', 'probability', 'FaceColor', colNo,  'FaceAlpha', 0.6);
title('Vividness by RJ — after'); xlabel('Vividness'); legend('yes', 'no'); box off;

subplot(2,3,5);
histogram(rsDS(rjDS==1), 20, 'Normalization', 'probability', 'FaceColor', colYes, 'FaceAlpha', 0.6); hold on;
histogram(rsDS(rjDS==0), 20, 'Normalization', 'probability', 'FaceColor', colNo,  'FaceAlpha', 0.6);
title('Reality signal by RJ — after'); xlabel('Reality signal'); legend('yes', 'no'); box off;

subplot(2,3,6);
scatter(vivDS(rjDS==1), rsDS(rjDS==1), 15, colYes, 'filled'); hold on;
scatter(vivDS(rjDS==0), rsDS(rjDS==0), 15, colNo,  'filled');
xlabel('Vividness'); ylabel('Reality signal'); title('Trials — after'); box off;

%% fig 3 barplots
figure('Position', [100 100 1100 420], 'Name', 'Group means before vs after');

% Vividness: yes/no means before vs after, with SEM
v_means = [mean(vividness(rj==1))  mean(vividness(rj==0)); ...
           mean(vivDS(rjDS==1))    mean(vivDS(rjDS==0))];
v_sems  = [std(vividness(rj==1))/sqrt(sum(rj==1))  std(vividness(rj==0))/sqrt(sum(rj==0)); ...
           std(vivDS(rjDS==1))/sqrt(sum(rjDS==1))  std(vivDS(rjDS==0))/sqrt(sum(rjDS==0))];

subplot(1,3,1);
b = bar(v_means, 'grouped'); hold on;
b(1).FaceColor = colYes; b(2).FaceColor = colNo;
x = nan(2, 2);
for i = 1:2, x(i,:) = b(i).XEndPoints; end
errorbar(x', v_means, v_sems, 'k', 'LineStyle', 'none', 'LineWidth', 1.2, 'CapSize', 8);
set(gca, 'XTickLabel', {'before', 'after'});
ylabel('Mean vividness'); title('Vividness by RJ response');
legend({'yes', 'no'}, 'Location', 'best'); box off;

% Reality signal: yes/no means before vs after, with SEM
rs_means = [mean(realitySignal(rj==1))  mean(realitySignal(rj==0)); ...
            mean(rsDS(rjDS==1))         mean(rsDS(rjDS==0))];
rs_sems  = [std(realitySignal(rj==1))/sqrt(sum(rj==1))  std(realitySignal(rj==0))/sqrt(sum(rj==0)); ...
            std(rsDS(rjDS==1))/sqrt(sum(rjDS==1))       std(rsDS(rjDS==0))/sqrt(sum(rjDS==0))];

subplot(1,3,2);
b = bar(rs_means, 'grouped'); hold on;
b(1).FaceColor = colYes; b(2).FaceColor = colNo;
for i = 1:2, x(i,:) = b(i).XEndPoints; end
errorbar(x', rs_means, rs_sems, 'k', 'LineStyle', 'none', 'LineWidth', 1.2, 'CapSize', 8);
set(gca, 'XTickLabel', {'before', 'after'});
ylabel('Mean reality signal'); title('Reality signal by RJ response');
legend({'yes', 'no'}, 'Location', 'best'); box off;


viv_d_before = mean(vividness(rj==1))    - mean(vividness(rj==0));
viv_d_after  = mean(vivDS(rjDS==1))      - mean(vivDS(rjDS==0));
rs_d_before  = mean(realitySignal(rj==1))- mean(realitySignal(rj==0));
rs_d_after   = mean(rsDS(rjDS==1))       - mean(rsDS(rjDS==0));

viv_d_sem_before = sqrt(var(vividness(rj==1))/sum(rj==1) + var(vividness(rj==0))/sum(rj==0));
viv_d_sem_after  = sqrt(var(vivDS(rjDS==1))/sum(rjDS==1) + var(vivDS(rjDS==0))/sum(rjDS==0));
rs_d_sem_before  = sqrt(var(realitySignal(rj==1))/sum(rj==1) + var(realitySignal(rj==0))/sum(rj==0));
rs_d_sem_after   = sqrt(var(rsDS(rjDS==1))/sum(rjDS==1) + var(rsDS(rjDS==0))/sum(rjDS==0));

diff_means = [viv_d_before  viv_d_after; ...
              rs_d_before   rs_d_after];

diff_sems  = [viv_d_sem_before  viv_d_sem_after; ...
              rs_d_sem_before   rs_d_sem_after];

subplot(1,3,3);
b = bar(diff_means, 'grouped'); hold on;
b(1).FaceColor = [0.55 0.55 0.55]; b(2).FaceColor = [0.25 0.65 0.45];
for i = 1:2, x(i,:) = b(i).XEndPoints; end
errorbar(x', diff_means, diff_sems, 'k', 'LineStyle', 'none', 'LineWidth', 1.2, 'CapSize', 8);
set(gca, 'XTickLabel', {'Vividness', 'Reality signal'});
ylabel('Mean yes - no'); title('Yes - no difference');
legend({'before', 'after'}, 'Location', 'best');
yline(0, 'k--'); box off;

%% ============================================================
%% Figure 4 — Sweep over vividness noise (now consistent: rescaled)
%% ============================================================
nReps     = 100;
noiseGrid = 0.05:0.1:1.0;
residualRS    = nan(numel(noiseGrid), nReps);
residualViv   = nan(numel(noiseGrid), nReps);
matchMSE      = nan(numel(noiseGrid), nReps);

for i = 1:numel(noiseGrid)
    vNoise = noiseGrid(i);
    for r = 1:nReps
        rs   = normrnd(realitySignalMean, realitySignalSD, [nTrials, 1]);
        rs   = rescale(rs, 0, 1);   % match the single-run scale
        viv  = rs + normrnd(0, vNoise, [nTrials, 1]);
        rjL  = rs + normrnd(0, rjNoiseSD, [nTrials, 1]);
        rjB  = double(rjL > rjThreshold);

        idxY = find(rjB == 1);
        idxN = find(rjB == 0);
        nM   = min(numel(idxY), numel(idxN));
        if nM == 0, continue; end

        bDiff = Inf; bY = []; bN = [];
        for k = 1:nRand
            sY = idxY(randperm(numel(idxY), nM));
            sN = idxN(randperm(numel(idxN), nM));
            d  = mean((sort(viv(sN)) - sort(viv(sY))).^2);
            if d < bDiff
                bDiff = d; bY = sY; bN = sN;
            end
        end

        residualRS(i, r)  = mean(rs(bY))  - mean(rs(bN));
        residualViv(i, r) = mean(viv(bY)) - mean(viv(bN));
        matchMSE(i, r)    = bDiff;
    end
end

figure('Position', [100 100 1100 350], 'Name', 'Sweep over vividness noise');

subplot(1,3,1);
errorbar(noiseGrid, mean(residualRS, 2, 'omitnan'), std(residualRS, 0, 2, 'omitnan'), ...
    'o-', 'LineWidth', 1.5, 'Color', [0.6 0.4 0.65]);
xlabel('Vividness noise SD'); ylabel('Reality signal yes - no after matching');
title('Residual latent signal'); grid on; yline(0, 'k--'); box off;

subplot(1,3,2);
errorbar(noiseGrid, mean(residualViv, 2, 'omitnan'), std(residualViv, 0, 2, 'omitnan'), ...
    'o-', 'LineWidth', 1.5, 'Color', [0.4 0.55 0.75]);
xlabel('Vividness noise SD'); ylabel('Vividness yes - no after matching');
title('Residual behavioural difference'); grid on; yline(0, 'k--'); box off;

subplot(1,3,3);
errorbar(noiseGrid, mean(matchMSE, 2, 'omitnan'), std(matchMSE, 0, 2, 'omitnan'), ...
    'o-', 'LineWidth', 1.5, 'Color', [0.25 0.65 0.45]);
xlabel('Vividness noise SD'); ylabel('Best sorted-vividness MSE');
title('Quality of best match'); grid on; box off;