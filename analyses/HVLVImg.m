clear
clc
close all
addpath("Utilities")
addpath(genpath("MVPA-Light-master"));
addpath("behavioural\")
seed = 42;
rng(seed)

meg_data = load("results\subj-1\Preprocessed_ICAclean_realigned.mat");

meg_data = meg_data.data_ica_clean;


cfg = [];
cfg.channel = 'MEG';
meg_all = ft_selectdata(cfg, meg_data);

all_trials_meg_3d   = cat(3, meg_all.trial{:});  %features, time, samples

rejection_hist = load("results\subj-1\rejection_log.mat");
rejection_hist = rejection_hist.rejection_log;

allRejectedTrials = [];
for iRun = 1:8
    allRejectedTrials = [allRejectedTrials, rejection_hist(1,iRun).trials_removed];
end

%% Behavioural data / flatten it

beh_data = load("PMT_10.mat");

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


%% Quartile split: top 25% vs bottom 25%
% Keep original continuous ratings intact

img_idx  = find(meta.condition==1);
perc_idx = find(meta.condition==0);

img_vals  = meta.reproduction(img_idx);

img_q25  = prctile(img_vals, 25);
img_q75  = prctile(img_vals, 75);

perc_vals = meta.reproduction(perc_idx);

perc_q25 = prctile(perc_vals, 25);
perc_q75 = prctile(perc_vals, 75);
perc_median = median(perc_vals);

%% Test 1: Vividness to visibility (quartile-based)

HV_img  = meta.condition == 1 & meta.reproduction >= img_q75;
LV_img  = meta.condition == 1 & meta.reproduction <= img_q25;

classA = HV_img;
classB = LV_img;

fprintf('HV_img trials: %d\n', sum(HV_img));
fprintf('LV_img trials: %d\n', sum(LV_img));

HV_perc  = meta.condition == 1 & meta.reproduction >= perc_median;
LV_perc  = meta.condition == 1 & meta.reproduction <= perc_median;

classA = HV_perc;
classB = LV_perc;

fprintf('HV_img trials: %d\n', sum(HV_perc));
fprintf('LV_img trials: %d\n', sum(LV_perc));


%% --------------------------
% Prepare training data
% --------------------------

valid_trials_train = classA | classB;

labels_train = ones(sum(valid_trials_train),1)*2;
labels_train(classA(valid_trials_train)) = 1;

meg_train = all_trials_meg_3d(:,:,valid_trials_train);

idxA = find(labels_train==1);   % HV_img
idxB = find(labels_train==2);   % LV_img

idx = [idxA; idxB];

labels_train = labels_train(idx);
meg_train    = meg_train(:,:,idx);

X_train = permute(meg_train, [3 1 2]);   % [trials x channels x time]




%% --------------------------
% Decoding
% --------------------------
time_idx = 1:5:size(X_train,3);  

X_train = X_train(:,:,time_idx);
cfg = [];
cfg.model = 'lda';
cfg.metric = 'auc';
cfg.preprocess = {'undersample', 'average_samples', 'zscore', 'pca'};
% cfg.time1 = time_idx;             
% cfg.time2 = time_idx;    
% cfg.time = time_idx;
cfg.cv = 'kfold';
cfg.k = 5;
cfg.repeat = 1; 

[perf,result] = mv_classify_across_time(cfg, X_train, labels_train);

time_axis = meg_all.time{1}(time_idx);
figure;
plot(time_axis, movmean(perf, 30), 'k', 'LineWidth', 2);
xlabel('Time (s)')
ylabel('AUC')
title('Diagonal AUC')
xline(-1.85, '--', 'First beep', 'LineWidth', 3)
xline(-0.95, '--', 'Second beep', 'LineWidth', 3)
xline(0, '--', 'Last beep', 'LineWidth', 3)
yline(0.5, '--', 'Chance level', 'LineWidth', 3)
xlim([-2.4, 0.7])

cfg_avg = [];
cfg_avg.channel = 'MLO*';

cfg_avg.trials = find(classA);
avg_A = ft_timelockanalysis(cfg_avg, meg_all);

cfg_avg.trials = find(classB);
avg_B = ft_timelockanalysis(cfg_avg, meg_all);

figure;
plot(avg_A.time, mean(avg_A.avg), 'b', 'LineWidth', 1.5); hold on;
plot(avg_B.time, mean(avg_B.avg), 'r', 'LineWidth', 1.5);


legend('High-visibility','Low-visibility')
xlabel('Time (s)')
ylabel('Mean amplitude')
title('Occipital ERF')
xline(-1.85, '--', 'First beep', 'LineWidth', 3, 'HandleVisibility','off')
xline(-0.95, '--', 'Second beep', 'LineWidth', 3, 'HandleVisibility','off')
xline(0, '--', 'Last beep', 'LineWidth', 3, 'HandleVisibility','off')
xlim([-2.4, 0.7])








