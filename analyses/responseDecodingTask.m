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

time_interval = [-0.2, 0.7];

cfg = [];
cfg.channel = 'MEG';
cfg.latency = time_interval;
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
%% Create classes and extract related trials

Hit = meta.presence==1 & meta.detection==1;
CR  = meta.presence==0 & meta.detection==0;
FA = meta.presence==0 & meta.detection==1;
Miss = meta.presence==1 & meta.detection==0;

classA = Hit;
classB = CR;

valid_trials = classA | classB;

labels = ones(sum(valid_trials),1)*2;
labels(classA(valid_trials)) = 1;

runs = meta.run(valid_trials);

meg = all_trials_meg_3d(:,:,valid_trials);

idxA = find(labels==1);
idxB = find(labels==2);

nMin = min(length(idxA),length(idxB));

idxA = idxA(randperm(length(idxA),nMin));
idxB = idxB(randperm(length(idxB),nMin));

idx = [idxA; idxB];

labels = labels(idx);
runs   = runs(idx);
meg    = meg(:,:,idx);

X = permute(meg,[3 1 2]);

%% Decoding + plots
cfg = [];
cfg.model = 'lda';
cfg.metric = 'accuracy';
cfg.preprocess = {'average_samples'};
cfg.cv   = 'predefined';
cfg.fold = runs;
cfg.repeat = 2;

[perf,result] = mv_classify_timextime(cfg,X,labels);

time_axis = meg_all.time{1};

diag_perf = diag(perf);

fprintf('Diagonal mean accuracy: %.3f\n', mean(diag_perf));

[peak_acc, peak_idx] = max(diag_perf);
fprintf('Peak diagonal accuracy: %.3f at t=%.3fs\n', peak_acc, time_axis(peak_idx));

figure;
imagesc(time_axis, time_axis, perf);
axis xy;
xlabel('Train Time (s)');
ylabel('Test Time (s)');
title('Temporal Generalization - Hit v CR');
colormap(bluewhitered)
top_acc = max(perf, [], 'all');
clim([0.5 - (top_acc-0.5) , top_acc])


colorbar_handle = colorbar;
ylabel(colorbar_handle,'Accuracy','FontSize',16,'Rotation',270);

xline(0,'black','LineWidth',3)
yline(0,'black','LineWidth',3)

figure;
plot(time_axis, movmean(diag_perf,20),'k','LineWidth',2);
xlabel('Time (s)')
ylabel('Accuracy')
title('Diagonal Decoding Accuracy')
xline(0,'--','Stimulus onset','LineWidth',3)
yline(0.5, '--' , 'Chance level','LineWidth',3)

cfg_avg = [];
cfg_avg.channel = 'MLO*';

cfg_avg.trials = find(classA);
avg_A = ft_timelockanalysis(cfg_avg, meg_all);

cfg_avg.trials = find(classB);
avg_B = ft_timelockanalysis(cfg_avg, meg_all);

figure;

plot(avg_A.time, mean(avg_A.avg), 'b','LineWidth',1.5); hold on;
plot(avg_B.time, mean(avg_B.avg), 'r','LineWidth',1.5);

legend('Hit','CR')

xlabel('Time (s)')
ylabel('Mean amplitude')
title('Occipital ERF')

xline(0,'--','Stimulus onset','LineWidth',3)
xlim(time_interval)