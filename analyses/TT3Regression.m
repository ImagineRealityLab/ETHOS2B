clear
clc
close all
addpath("Utilities")
addpath(genpath("MVPA-Light-master"));
addpath(genpath("behavioural\"))
seed = 42;
rng(seed)

subjects = {'subj-1', 'subj-2','subj-4', 'subj-5'};
subjNos = [1, 2, 4, 5];

results = cell(1, length(subjects));
ERFs = cell(4, length(subjects));

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

beh_data = load(sprintf('PMT_%d.mat', subjNos(iSubj)));

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

%% Quartile split: top 25% vs bottom 25%
% Keep original continuous ratings intact

img_idx  = find(meta.condition==1);
perc_idx = find(meta.condition==0);

gratingA_idx = find(meta.orientation==1);
gratingB_idx = find(meta.orientation==2);

cond1 = meta.orientation==1 & meta.condition==1 | meta.orientation==1 & meta.detection == 1;
cond2 = meta.orientation==2 & meta.condition==1 | meta.orientation==2 & meta.detection == 1;

img_vals  = meta.reproduction(img_idx);
perc_vals = meta.reproduction(perc_idx);

img_q25  = prctile(img_vals, 25);
img_q75  = prctile(img_vals, 75);

perc_q25 = prctile(perc_vals, 25);
perc_q75 = prctile(perc_vals, 75);

if perc_q75 == 0
    perc_q75 = 0 + eps;
end

%% Test 1: Vividness to visibility (quartile-based)

%% --------------------------
% Prepare training data
% --------------------------
labels_train = meta.reproduction(cond1);
meg_train    = all_trials_meg_3d(:,:,cond1);

X_train = permute(meg_train, [3 1 2]);   % [trials x channels x time]

%% --------------------------
% Prepare testing data
% --------------------------

labels_test = meta.reproduction(cond2);
meg_test    = all_trials_meg_3d(:,:,cond2);

sample_rate = meg_data.time{1,1}(2) - meg_data.time{1,1}(1);
smoothing = 0.04;
tp = smoothing / sample_rate;


X_test = permute(meg_test, [3 1 2]);   % [trials x channels x time]
X_train = movmean(X_train, tp, 3); % 20 ms temporal smoothing
X_test = movmean(X_test, tp, 3); % 20 ms temporal smoothing

labels_train = zscore(labels_train);
labels_test = zscore(labels_test);

cfg = [];
cfg.model = 'ridge';
cfg.metric = 'r';
cfg.lambda = [10^-1, 1, 10, 100, 1000];
cfg.preprocess = {'zscore', 'pca'};
cfg.preprocess_param = {};
cfg.preprocess_param{2} = [];
cfg.preprocess_param{2}.explained_variance = 0.95;

[perf,result] = mv_regress(cfg, X_train, labels_train, X_test, labels_test);
time_axis = meg_all.time{1};

%% --------------------------
% Plot diagonal
% --------------------------

figure;
plot(time_axis, movmean(perf,20), 'k', 'LineWidth', 2);
xlabel('Time (s)')
ylabel('R-squared')
title(sprintf('Diagonal Decoding - Subject %d', iSubj))
xline(-1.85, '--', 'First beep', 'LineWidth', 3)
xline(-0.95, '--', 'Second beep', 'LineWidth', 3)
xline(0, '--', 'Last beep', 'LineWidth', 3)
xlim([-2.4, 0.7])
%ylim([0.4, 0.7])


results{iSubj} = perf;


end % iSubj

% Helper function: shaded patch without legend entry
plot_with_shade = @(x, y, sd, col) ...
    fill([x; flipud(x)], [y - sd; flipud(y + sd)], col, ...
         'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');

%% Extract diagonal across subjects

x = time_axis(:); % ensure column

all_diag = [];
sharedTGM = zeros(length(x),length(x));
nValidSubj = 0;

for iSubj = 1:length(results)
    if isempty(results{iSubj})
        continue
    end

    this_TGM = results{iSubj};

    % Extract diagonal (train = test)

    all_diag(:, end+1) = this_TGM; 


end

mean_diag = mean(all_diag, 2);
sd_diag   = std(all_diag, 0, 2);

%% Plot - diagonal

figure; hold on;

% Shaded error
plot_with_shade(x, mean_diag, sd_diag, [0 0.447 0.941]);

% Mean line
plot(x, mean_diag, 'Color', [0 0.447 0.941], 'LineWidth', 3);

% Chance line (adjust if needed)
chance_level = 0;
yline(chance_level, 'k--', 'LineWidth', 1);

% Time zero line
xline(0, 'k--', 'LineWidth', 1);

% xlabel('Time (s)');
% % ylabel('R-squared');
% title(sprintf('Diagonal decoding - Vividness/Visibility Grating A <--> Grating B, N = %d', 5));
xline(-1.85, '--', 'First beep', 'LineWidth', 3, 'HandleVisibility','off')
xline(-0.95, '--', 'Second beep', 'LineWidth', 3, 'HandleVisibility','off')
xline(0, '--', 'LineWidth', 3, 'HandleVisibility','off')
xlim([-0.2, 0.7])
ax = gca;
ax.FontSize = 30;
ax.FontWeight = 'bold';

box off;
