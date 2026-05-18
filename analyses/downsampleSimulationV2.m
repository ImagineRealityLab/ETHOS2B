clear
clc
close all

%% Configuration
realitySignalMean = 0.5;
realitySignalSD   = 0.5;

vividnessNoiseSD  = 0.01;
rjNoiseSD         = 0.3;
rjThreshold       = 0.5;

nTrials           = 16*24/2;
nRand             = 1000;
rng(42)

%% Latent reality signal and behavioural readouts
realitySignal = normrnd(realitySignalMean, realitySignalSD, [nTrials, 1]);
realitySignal = rescale(realitySignal, 0, 1);

vividness     = realitySignal + normrnd(0, vividnessNoiseSD, [nTrials, 1]);

rjLatent      = realitySignal + normrnd(0, rjNoiseSD, [nTrials, 1]);
rj            = double(rjLatent > rjThreshold);

%% Downsample through binning the clusters

yesIdx = rj == 1;
noIdx = rj ==0;

yesVividness = vividness(yesIdx);
noVividness = vividness(noIdx);

fprintf('Prior to downsampling there are %d Yes and %d No trials', sum(yesIdx), sum(noIdx));
fprintf('\n The mean vividness of yes trials is %.2f and the mean of the no trials is %.2f', mean(yesVividness), mean(noVividness));

nIters   = 20;
nBins = 10; 
 
ds_vivDiff = nan(nIters, 1);
ds_rsDiff  = nan(nIters, 1);
ds_nKept   = nan(nIters, 1);

edges = quantile(vividness, linspace(0, 1, nBins+1));
edges(1) = -inf; edges(end) = inf;
binIdx = discretize(vividness, edges);
 
for it = 1:nIters
    toKeep = false(nTrials, 1);
    for b = 1:nBins
        yesBin = find(rj == 1 & binIdx == b);
        noBin  = find(rj == 0 & binIdx == b);
        nB   = min(numel(yesBin), numel(noBin));
        if nB == 0, continue; end
        toKeep(yesBin(randperm(numel(yesBin), nB))) = true;
        toKeep(noBin(randperm(numel(noBin),  nB))) = true;
    end
 
    vivStrat = vividness(toKeep);
    rsStrat  = realitySignal(toKeep);
    rjStrat  = rj(toKeep);
 
    ds_vivDiff(it) = mean(vivStrat(rjStrat==1)) - mean(vivStrat(rjStrat==0));
    ds_rsDiff(it)  = mean(rsStrat(rjStrat==1))  - mean(rsStrat(rjStrat==0));
    ds_nKept(it)   = sum(toKeep);
end

%% ============================================================
%% Figure 1 — Distributions before vs after matching
%% ============================================================
colYes = [0    0.45 0.74];
colNo  = [0.85 0.33 0.10];

colYesMean = [0  0  1];
colNoMean  = [1, 0, 0];
 
vEdges = linspace(min(vividness), max(vividness), 25);
rEdges = linspace(min(realitySignal), max(realitySignal), 25);
 
% Vividness before
figure;
histogram(vividness(rj==1), vEdges, 'FaceColor', colYes, 'FaceAlpha', 0.6, 'EdgeColor', 'none'); hold on;
histogram(vividness(rj==0), vEdges, 'FaceColor', colNo,  'FaceAlpha', 0.6, 'EdgeColor', 'none');
xline(mean(vividness(rj==1)), '-', 'Color', colYesMean, 'LineWidth', 5);
xline(mean(vividness(rj==0)), '-', 'Color', colNoMean,  'LineWidth', 5);
ax = gca;
ax.FontSize = 30;
ax.FontWeight = 'bold';

% Vividness after
figure;
v_keep  = vividness(toKeep);
rj_keep = rj(toKeep);
histogram(v_keep(rj_keep==1), vEdges, 'FaceColor', colYes, 'FaceAlpha', 0.6, 'EdgeColor', 'none'); hold on;
histogram(v_keep(rj_keep==0), vEdges, 'FaceColor', colNo,  'FaceAlpha', 0.6, 'EdgeColor', 'none');
xline(mean(v_keep(rj_keep==1)), '-', 'Color', colYesMean, 'LineWidth', 5);
xline(mean(v_keep(rj_keep==0)), '-', 'Color', colNoMean,  'LineWidth', 5);
ax = gca;
ax.FontSize = 30;
ax.FontWeight = 'bold';
 
% Reality signal before
figure;
histogram(realitySignal(rj==1), rEdges, 'FaceColor', colYes, 'FaceAlpha', 0.6, 'EdgeColor', 'none'); hold on;
histogram(realitySignal(rj==0), rEdges, 'FaceColor', colNo,  'FaceAlpha', 0.6, 'EdgeColor', 'none');
xline(mean(realitySignal(rj==1)), '-', 'Color', colYesMean, 'LineWidth', 5);
xline(mean(realitySignal(rj==0)), '-', 'Color', colNoMean,  'LineWidth', 5);
ax = gca;
ax.FontSize = 30;
ax.FontWeight = 'bold';
 
% Reality signal after
figure;
rs_keep = realitySignal(toKeep);
histogram(rs_keep(rj_keep==1), rEdges, 'FaceColor', colYes, 'FaceAlpha', 0.6, 'EdgeColor', 'none'); hold on;
histogram(rs_keep(rj_keep==0), rEdges, 'FaceColor', colNo,  'FaceAlpha', 0.6, 'EdgeColor', 'none');
xline(mean(rs_keep(rj_keep==1)), '-', 'Color', colYesMean, 'LineWidth', 5);
xline(mean(rs_keep(rj_keep==0)), '-', 'Color', colNoMean,  'LineWidth', 5);
ax = gca;
ax.FontSize = 30;
ax.FontWeight = 'bold';
 
%% ============================================================
%% Figure 2 — Per-bin trial counts before and after
%% ============================================================
binCounts_before = nan(nBins, 2);   % [yes no]
binCounts_after  = nan(nBins, 2);
for b = 1:nBins
    binCounts_before(b, 1) = sum(rj == 1 & binIdx == b);
    binCounts_before(b, 2) = sum(rj == 0 & binIdx == b);
    binCounts_after(b, 1)  = sum(toKeep & rj == 1 & binIdx == b);
    binCounts_after(b, 2)  = sum(toKeep & rj == 0 & binIdx == b);
end
 
 
figure;
hb = bar(1:nBins, binCounts_before, 'grouped');
hb(1).FaceColor = colYes; hb(2).FaceColor = colNo;
ax = gca;
ax.FontSize = 30;
ax.FontWeight = 'bold';

 
figure;
hb = bar(1:nBins, binCounts_after, 'grouped');
hb(1).FaceColor = colYes; hb(2).FaceColor = colNo;
ax = gca;
ax.FontSize = 30;
ax.FontWeight = 'bold';
 
%% ============================================================
%% Figure 3 — Per-iteration spread
%% ============================================================
figure('Position', [100 100 800 400], 'Name', 'Per-iteration results');
plot(1:nIters, ds_vivDiff, 'o-', 'Color', [0.4 0.55 0.75], ...
    'LineWidth', 3, 'MarkerFaceColor', [0.4 0.55 0.75], ...
    'DisplayName', 'Vividness yes - no');
hold on;
plot(1:nIters, ds_rsDiff,  's-', 'Color', [0.25 0.65 0.45], ...
    'LineWidth', 3, 'MarkerFaceColor', [0.25 0.65 0.45], ...
    'DisplayName', 'Reality signal yes - no');
yline(0, 'k:', 'HandleVisibility', 'off');
ax = gca;
ax.FontSize = 30;
ax.FontWeight = 'bold';