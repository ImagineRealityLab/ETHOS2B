clear
clc
close all
addpath("Utilities")
addpath(genpath("MVPA-Light-master"));
addpath(genpath("behavioural\"))
seed = 42;
rng(seed)

subjects = {'subj-1','subj-4', 'subj-5'};
noSubjects = [1 4 5];
results = cell(1, length(subjects));

for iSubj = 1:length(subjects)

meg_data = load(fullfile('results', subjects{iSubj}, 'Preprocessed_ICAclean_realigned.mat'));
meg_data = meg_data.data_ica_clean;

cfg = [];
cfg.channel = 'MEG';
meg_all = ft_selectdata(cfg, meg_data);

all_trials_meg_3d   = cat(3, meg_all.trial{:});  %features, time, samples

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



%% Behavioural data / flatten it

beh_data = load(sprintf('PMT_%d.mat', noSubjects(iSubj)));

block_info   = beh_data.blocks;
trial_info   = beh_data.trials;
response_info= beh_data.R;

% Exclude trials that contained artefacts


cond        = block_info(:,2);     % imagery/perception
presence    = trial_info(:,:,1);
detection   = response_info(:,:,3);
reproduction= response_info(:,:,1);
grating     = block_info(:,1);

nRuns  = size(block_info,1) / 2;
nTrial = size(presence,2);

% expand block variables to trials
conditionPerTrial = repmat(cond,1,nTrial);
oriPerTrial       = repmat(grating,1,nTrial);

% run labels
runPerTrial = repmat((1:nRuns)',1,nTrial);

allRuns = [];
for iRun = 1:nRuns
    allRuns = [allRuns; runPerTrial(iRun, :); runPerTrial(iRun, :)];
end

% flatten everything
meta.condition  = reshape(conditionPerTrial',[],1);
meta.orientation= reshape(oriPerTrial',[],1);
meta.presence   = reshape(presence',[],1);
meta.detection  = reshape(detection',[],1);
meta.reproduction = reshape(reproduction',[],1);
meta.run        = reshape(allRuns',[],1);

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
keepMask(isnan(meta.detection)) = false;

meta.condition    = meta.condition(keepMask);
meta.orientation  = meta.orientation(keepMask);
meta.presence     = meta.presence(keepMask);
meta.detection    = meta.detection(keepMask);
meta.reproduction = meta.reproduction(keepMask);
meta.run          = meta.run(keepMask);

all_trials_meg_3d = all_trials_meg_3d(:,:,keepMask);

TrialsAll = 1:size(meg_all.trial,2);
TrialsToKeep = TrialsAll(keepMask);

cfg  = [];
cfg.trials = TrialsToKeep;
megClean = ft_selectdata(cfg, meg_all);


%% Decoding FA v. CR in Imagery from Alpha power

% Find the related trials
ImgFA = find(meta.condition == 1 & meta.detection == 1 & meta.presence == 0);
ImgCR = find(meta.condition == 1 & meta.detection == 0 & meta.presence == 0);

ResponsePresent = find(meta.detection == 1);
ResponseAbsent = find(meta.detection == 0);
% 
% %% Look at centro-parietal ERF
% 
% cfg = [];
% cfg.trials = ResponsePresent;
% cfg.channel = {'MZC01', 'MZC02', 'MZC03', 'MZC04', 'MZP01'};
% PresentERF = ft_timelockanalysis(cfg, megClean);
% 
% cfg = [];
% cfg.trials = ResponseAbsent;
% cfg.channel = {'MZC01', 'MZC02', 'MZC03', 'MZC04', 'MZP01'};
% absentERF = ft_timelockanalysis(cfg, megClean);
% 
% 
% %% Compute the difference wave
% cfg = [];
% cfg.operation = 'subtract';
% cfg.parameter = 'avg';
% diffERF = ft_math(cfg, PresentERF, absentERF);
% 
% %% Plot
% figure('Color', 'w', 'Position', [100 100 1000 600]);
% 
% % --- Time vector ---
% t = PresentERF.time;
% 
% % --- Average across CPP channels ---
% presentAvg = mean(PresentERF.avg, 1);
% absentAvg  = mean(absentERF.avg, 1);
% diffAvg    = mean(diffERF.avg, 1);
% 
% % ---- Panel 1: Present vs Absent ----
% subplot(1,2,1); hold on;
% 
% % Shaded SEM (optional but clean)
% nChan = size(PresentERF.avg, 1);
% semPresent = std(PresentERF.avg, 0, 1) / sqrt(nChan);
% semAbsent  = std(absentERF.avg,  0, 1) / sqrt(nChan);
% 
% fill([t, fliplr(t)], ...
%      [presentAvg + semPresent, fliplr(presentAvg - semPresent)], ...
%      [0.2 0.4 0.8], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
% fill([t, fliplr(t)], ...
%      [absentAvg + semAbsent, fliplr(absentAvg - semAbsent)], ...
%      [0.8 0.2 0.2], 'FaceAlpha', 0.2, 'EdgeColor', 'none');
% 
% p1 = plot(t, presentAvg, 'Color', [0.2 0.4 0.8], 'LineWidth', 2);
% p2 = plot(t, absentAvg,  'Color', [0.8 0.2 0.2], 'LineWidth', 2);
% 
% xline(0, '--k', 'LineWidth', 1, 'Alpha', 0.5);  % stimulus onset
% yline(0, '-k',  'LineWidth', 0.5, 'Alpha', 0.3);
% 
% xlabel('Time (s)'); 
% ylabel('Amplitude (T)');
% title('CPP: Response Present vs Absent');
% legend([p1 p2], {'Present', 'Absent'}, 'Location', 'northwest', 'Box', 'off');
% xlim([t(1) t(end)]);
% set(gca, 'FontSize', 13, 'Box', 'off', 'TickDir', 'out');
% 
% % ---- Panel 2: Difference wave ----
% subplot(1,2,2); hold on;
% 
% semDiff = std(diffERF.avg, 0, 1) / sqrt(nChan);
% fill([t, fliplr(t)], ...
%      [diffAvg + semDiff, fliplr(diffAvg - semDiff)], ...
%      [0.2 0.7 0.4], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
% 
% plot(t, diffAvg, 'Color', [0.2 0.7 0.4], 'LineWidth', 2.5);
% 
% xline(0, '--k', 'LineWidth', 1, 'Alpha', 0.5);
% yline(0, '-k',  'LineWidth', 0.5, 'Alpha', 0.3);
% 
% xlabel('Time (s)');
% ylabel('\DeltaAmplitude (T)');
% title('CPP Difference (Present – Absent)');
% xlim([t(1) t(end)]);
% set(gca, 'FontSize', 13, 'Box', 'off', 'TickDir', 'out');
% 
% sgtitle('Centro-Parietal Positivity (CPP)', 'FontSize', 15, 'FontWeight', 'bold');

%% Shared parameters
foi       = 8:0.5:13;
t_ftimwin = 5 ./ foi;
half_win  = max(t_ftimwin) / 2;          % 0.3125 s (driven by 8 Hz)
toi       = (-2.4 + half_win):0.05:(0.7 - half_win);

%% Frequency analysis — False Alarms
cfg              = [];
cfg.trials       = ImgFA;
cfg.output       = 'pow';
cfg.method       = 'mtmconvol';
cfg.taper        = 'hanning';
cfg.keeptrials   = 'yes';
cfg.foi          = foi;
cfg.t_ftimwin    = t_ftimwin;
cfg.toi          = toi;
ImgFAFreq        = ft_freqanalysis(cfg, megClean);

%% Frequency analysis — Correct Rejections
cfg.trials       = ImgCR;
ImgCRFreq        = ft_freqanalysis(cfg, megClean);

powIMGFA_mean = squeeze(mean(mean(ImgFAFreq.powspctrm, 1), 2));   % should be freqs x time
powIMGCR_mean = squeeze(mean(mean(ImgCRFreq.powspctrm, 1), 2));
diff = powIMGFA_mean - powIMGCR_mean;

%% Visualize the raw differences first

figure('Color','w','Position',[100 100 900 700])

subplot(3,1,1)
imagesc(ImgCRFreq.time, ImgCRFreq.freq, powIMGFA_mean)
axis xy
xlim([ImgCRFreq.time(1) ImgCRFreq.time(end)])
xlabel('Time (s)'); ylabel('Frequency (Hz)')
title('Imagery False Alarms'); colorbar
clim([min(min(powIMGCR_mean, [], 'all'), min(powIMGFA_mean, [], 'all')), max(max(powIMGCR_mean, [], 'all'), max(powIMGFA_mean, [], 'all'))])

subplot(3,1,2)
imagesc(ImgCRFreq.time, ImgCRFreq.freq, powIMGCR_mean)
axis xy
xlim([ImgCRFreq.time(1) ImgCRFreq.time(end)])
xlabel('Time (s)'); ylabel('Frequency (Hz)')
title('Imagery Correct Rejections'); colorbar
clim([min(min(powIMGCR_mean, [], 'all'), min(powIMGFA_mean, [], 'all')), max(max(powIMGCR_mean, [], 'all'), max(powIMGFA_mean, [], 'all'))])


subplot(3,1,3)
imagesc(ImgCRFreq.time, ImgCRFreq.freq, diff)
axis xy
xlim([ImgCRFreq.time(1) ImgCRFreq.time(end)])
xlabel('Time (s)'); ylabel('Frequency (Hz)')
title('Imagery FA - CR'); colorbar
xline(0,'k--','LineWidth',1.5)


yTrain = [ones(numel(ImgFA),1); 2*ones(numel(ImgCR),1)];
xTrain = cat(1,ImgFAFreq.powspctrm, ImgCRFreq.powspctrm); % [samples x chan x freq x time] 

k = min(5, floor(min(numel(ImgFA), numel(ImgCR)) / 2));

cfg = [];
cfg.model = 'lda';
cfg.metric = 'auc';
cfg.feature_dimension = [2 3];
cfg.generalization_dimension = 4;
cfg.k = k;
cfg.preprocess = {'undersample', 'zscore', 'pca'};
cfg.preprocess_param{3} = [];
cfg.preprocess_param{3}.explained_variance = 0.95;

[perf,result] = mv_classify(cfg, xTrain, yTrain);


results{iSubj} = perf;

end % iSubj

% Helper function: shaded patch without legend entry
plot_with_shade = @(x, y, sd, col) ...
    fill([x; flipud(x)], [y - sd; flipud(y + sd)], col, ...
         'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');

%% Group average
validMask     = ~cellfun(@isempty, results);
validResults  = results(validMask);
sharedResults = mean(cat(3, validResults{:}), 3);   % [nTime x nTime]
nValidSubj    = sum(validMask);

%% Plot TGM
t = ImgFAFreq.time;   % time axis (same for train and test)

figure('Color','w','Position',[100 100 800 700])
imagesc(t, t, sharedResults)
axis xy
xlabel('Testing time (s)')
ylabel('Training time (s)')       % both axes are time now
title(sprintf('Alpha power TGM: FA vs CR (AUC), N = %d', nValidSubj))
clim([0.3 0.7])                   % centre on chance = 0.5
colormap(bluewhitered)            % diverging around 0.5 is more informative
colorbar_h = colorbar;
ylabel(colorbar_h, 'AUC', 'FontSize', 14, 'Rotation', 270)

% Event lines on both axes
xline(0, 'k--', 'LineWidth', 1.5, 'HandleVisibility','off')
yline(0, 'k--', 'LineWidth', 1.5, 'HandleVisibility','off')


ax = gca;
ax.FontSize   = 16;
ax.FontWeight = 'bold';
box off

%% Plot diagonal (train time = test time)
t = ImgFAFreq.time;

% Extract diagonal per subject
all_diag = zeros(length(t), sum(validMask));
for iSubj = 1:sum(validMask)
    all_diag(:, iSubj) = diag(validResults{iSubj});
end

mu  = mean(all_diag, 2);
sd  = std(all_diag, 0, 2);

figure('Color','w','Position',[100 100 900 500])
hold on

% Shaded SD
fill([t, fliplr(t)], [mu-sd; flipud(mu+sd)]', ...
    [0 0.447 0.741], 'FaceAlpha', 0.25, 'EdgeColor', 'none', ...
    'HandleVisibility', 'off');

% Mean line
plot(t, mu, 'Color', [0 0.447 0.741], 'LineWidth', 2.5, ...
    'DisplayName', 'Mean AUC');

% Reference lines
yline(0.5,  'k--', 'Chance', 'LineWidth', 1.5, 'HandleVisibility','off')
xline(0,    'k--',           'LineWidth', 1.5, 'HandleVisibility','off')
xline(-1.85,'k--',           'LineWidth', 1.5, 'HandleVisibility','off')
xline(-0.95,'k--',           'LineWidth', 1.5, 'HandleVisibility','off')

xlabel('Time (s)')
ylabel('AUC')
title(sprintf('Diagonal decoding: Alpha FA vs CR (N=%d)', nValidSubj))
xlim([t(1) t(end)])
ylim([0.3 0.8])
legend('Location','best')
ax = gca;
ax.FontSize   = 16;
ax.FontWeight = 'bold';
box off


