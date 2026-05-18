clear
clc
close all
addpath("Utilities")
addpath(genpath("MVPA-Light-master"));
addpath("behavioural\")
seed = 42;
rng(seed)

%% --------------------------
% Load MEG
% --------------------------
meg_data = load("results\subj-1\Preprocessed_ICAclean_realigned.mat");
meg_data = meg_data.data_ica_clean;

cfg = [];
cfg.channel = 'MEG';
meg_all = ft_selectdata(cfg, meg_data);

% [channels x time x trials]
all_trials_meg_3d = cat(3, meg_all.trial{:});

%% --------------------------
% Load rejection history
% --------------------------
rejection_hist = load("results\subj-1\rejection_log.mat");
rejection_hist = rejection_hist.rejection_log;

allRejectedTrials = [];
for iRun = 1:8
    allRejectedTrials = [allRejectedTrials, rejection_hist(1,iRun).trials_removed];
end

%% --------------------------
% Load behaviour
% --------------------------
beh_data = load("PMT_10.mat");

block_info    = beh_data.blocks;
trial_info    = beh_data.trials;
response_info = beh_data.R;

cond         = block_info(:,2);     % imagery/perception
presence     = trial_info(:,:,1);
detection    = response_info(:,:,3);
reproduction = response_info(:,:,1);
grating      = block_info(:,1);

nRuns  = size(block_info,1) / 2;
nTrial = size(presence,2);

% expand block variables to trials
conditionPerTrial = repmat(cond,1,nTrial);
oriPerTrial       = repmat(grating,1,nTrial);

runPerTrial = repmat((1:nRuns)',1,nTrial);

allRuns = [];
for iRun = 1:nRuns
    allRuns = [allRuns; runPerTrial(iRun,:); runPerTrial(iRun,:)];
end

% flatten
meta.condition    = reshape(conditionPerTrial',[],1);
meta.orientation  = reshape(oriPerTrial',[],1);
meta.presence     = reshape(presence',[],1);
meta.detection    = reshape(detection',[],1);
meta.reproduction = reshape(reproduction',[],1);
meta.run          = reshape(allRuns',[],1);

%% --------------------------
% Remove rejected trials from BOTH meta and MEG
% --------------------------
nTotalTrials = length(meta.condition);
keepMask = true(nTotalTrials,1);
keepMask(allRejectedTrials) = false;

meta.condition    = meta.condition(keepMask);
meta.orientation  = meta.orientation(keepMask);
meta.presence     = meta.presence(keepMask);
meta.detection    = meta.detection(keepMask);
meta.reproduction = meta.reproduction(keepMask);
meta.run          = meta.run(keepMask);

time_axis = meg_all.time{1};

%% --------------------------
% Define imagery/perception trial indices
% --------------------------
img_idx  = find(meta.condition == 1);
perc_idx = find(meta.condition == 0);

img_vals  = meta.reproduction(img_idx);
perc_vals = meta.reproduction(perc_idx);

%% --------------------------
% Quartile split: top 25% vs bottom 25%
% --------------------------
img_q25 = quantile(img_vals, 0.25);
img_q75 = quantile(img_vals, 0.75);

perc_q25 = quantile(perc_vals, 0.25);
perc_q75 = quantile(perc_vals, 0.75);

% These are indices within the FULL FILTERED dataset
classA = false(length(meta.condition),1); % high imagery vividness
classB = false(length(meta.condition),1); % low imagery vividness
classC = false(length(meta.condition),1); % high perception visibility
classD = false(length(meta.condition),1); % low perception visibility

classA(img_idx(img_vals >= img_q75)) = true;
classB(img_idx(img_vals <= img_q25)) = true;
classC(perc_idx(perc_vals >= perc_q75)) = true;
classD(perc_idx(perc_vals <= perc_q25)) = true;

%% --------------------------
% Prepare train/test data for regression
% --------------------------
meg_train = all_trials_meg_3d(:,:,img_idx);     % [channels x time x trials]
meg_train = permute(meg_train, [3 1 2]);        % [trials x channels x time]

meg_test  = all_trials_meg_3d(:,:,perc_idx);    % [channels x time x trials]
meg_test  = permute(meg_test, [3 1 2]);         % [trials x channels x time]

% optional temporal smoothing
win = 5;
meg_train = movmean(meg_train, win, 3);
meg_test  = movmean(meg_test,  win, 3);

%% --------------------------
% Ridge regression
% --------------------------
cfg = [];
cfg.model = 'ridge';
cfg.preprocess = {'zscore', 'pca'};
[perf, result] = mv_regress(cfg, meg_train, img_vals, meg_test, perc_vals);

%% --------------------------
% Diagonal performance plot
% --------------------------
figure('Color','w');
plot(time_axis, movmean(perf, 50), 'k', 'LineWidth', 2);
xlabel('Time (s)');
ylabel('Performance (mse)');
title('Diagonal vividness --> visibility');
xline(-1.85, '--', 'First beep',  'LineWidth', 2);
xline(-0.95, '--', 'Second beep', 'LineWidth', 2);
xline(0,     '--', 'Last beep',   'LineWidth', 2);


xlim([-2.4 0.7]);
set(gca, 'FontSize', 12, 'LineWidth', 1.2);

%% --------------------------
% ERF: imagery quartiles
% --------------------------
cfg_avg = [];
cfg_avg.channel = 'MLO*';

cfg_avg.trials = find(classA);
avg_high_img = ft_timelockanalysis(cfg_avg, meg_all);

cfg_avg.trials = find(classB);
avg_low_img = ft_timelockanalysis(cfg_avg, meg_all);

figure('Color','w');
plot(avg_high_img.time, mean(avg_high_img.avg,1), 'b', 'LineWidth', 1.5); hold on;
plot(avg_low_img.time,  mean(avg_low_img.avg,1),  'r', 'LineWidth', 1.5);

legend('High vividness','Low vividness', 'Location','best');
xlabel('Time (s)');
ylabel('Mean amplitude');
title('Occipital ERF - Imagery');
xline(-1.85, '--', 'First beep',  'LineWidth', 2, 'HandleVisibility','off');
xline(-0.95, '--', 'Second beep', 'LineWidth', 2, 'HandleVisibility','off');
xline(0,     '--', 'Last beep',   'LineWidth', 2, 'HandleVisibility','off');
xlim([-2.4 0.7]);
set(gca, 'FontSize', 12, 'LineWidth', 1.2);

%% --------------------------
% ERF: perception quartiles
% --------------------------
cfg_avg = [];
cfg_avg.channel = 'MLO*';

cfg_avg.trials = find(classC);
avg_high_perc = ft_timelockanalysis(cfg_avg, meg_all);

cfg_avg.trials = find(classD);
avg_low_perc = ft_timelockanalysis(cfg_avg, meg_all);

figure('Color','w');
plot(avg_high_perc.time, mean(avg_high_perc.avg,1), 'b', 'LineWidth', 1.5); hold on;
plot(avg_low_perc.time,  mean(avg_low_perc.avg,1),  'r', 'LineWidth', 1.5);

legend('High visibility','Low visibility', 'Location','best');
xlabel('Time (s)');
ylabel('Mean amplitude');
title('Occipital ERF - Perception');
xline(-1.85, '--', 'First beep',  'LineWidth', 2, 'HandleVisibility','off');
xline(-0.95, '--', 'Second beep', 'LineWidth', 2, 'HandleVisibility','off');
xline(0,     '--', 'Last beep',   'LineWidth', 2, 'HandleVisibility','off');
xlim([-2.4 0.7]);
set(gca, 'FontSize', 12, 'LineWidth', 1.2);