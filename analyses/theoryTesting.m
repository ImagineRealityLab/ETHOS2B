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

time_interval = [-0.3, 0.7];

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

img_idx = find(meta.condition==1);
perc_idx = find(meta.condition==0);

meta.reproduction(img_idx) = meta.reproduction(img_idx) >  median(meta.reproduction(img_idx));
meta.reproduction(perc_idx) = meta.reproduction(perc_idx) >  median(meta.reproduction(perc_idx));

%% Test 1: Vividness to visibility

HV_img = meta.condition ==1 & meta.reproduction ==1;
LV_img = meta.condition ==1 & meta.reproduction ==0;

HV_perc = meta.condition ==0 & meta.reproduction ==1;
LV_perc = meta.condition ==0 & meta.reproduction ==0;

classA = HV_img;
classB = LV_img;
classC = HV_perc;
classD = LV_perc;

%Prepare training data
valid_trials_train = classA | classB;

labels_train = ones(sum(valid_trials_train),1)*2;
labels_train(classA(valid_trials_train)) = 1;
meg_train = all_trials_meg_3d(:,:,valid_trials_train);

idxA = find(labels_train==1);
idxB = find(labels_train==2);

nMin = min(length(idxA),length(idxB));

idxA = idxA(randperm(length(idxA),nMin));
idxB = idxB(randperm(length(idxB),nMin));

idx = [idxA; idxB];

labels_train = labels_train(idx);
meg_train    = meg_train(:,:,idx);

X_train = permute(meg_train,[3 1 2]);

%Prepare testing data

valid_trials_test = classC | classD;

labels_test = ones(sum(valid_trials_test),1)*2;
labels_test(classC(valid_trials_test)) = 1;
meg_test = all_trials_meg_3d(:,:,valid_trials_test);

idxA = find(labels_test==1);
idxB = find(labels_test==2);

nMin = min(length(idxA),length(idxB));

idxA = idxA(randperm(length(idxA),nMin));
idxB = idxB(randperm(length(idxB),nMin));

idx = [idxA; idxB];

labels_test = labels_test(idx);
meg_test    = meg_test(:,:,idx);

X_test = permute(meg_test,[3 1 2]);


cfg = [];
cfg.model = 'lda';
cfg.metric = 'accuracy';
cfg.preprocess = {'average_samples', 'zscore', 'pca'};

[perf,~] = mv_classify_timextime(cfg,X_train,labels_train,X_test,labels_test);

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
title('Temporal Generalization - Vividness --> Visibility');
colormap(bluewhitered)
top_acc = max(perf, [], 'all');
%clim([0.5 - (top_acc-0.5) , top_acc])
clim([0, 1])
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

legend('HV_img','LV_img')

xlabel('Time (s)')
ylabel('Mean amplitude')
title('Occipital ERF')

xline(0,'--','Stimulus onset','LineWidth',3)

cfg_avg = [];
cfg_avg.channel = 'MLO*';

cfg_avg.trials = find(classC);
avg_A = ft_timelockanalysis(cfg_avg, meg_all);

cfg_avg.trials = find(classD);
avg_B = ft_timelockanalysis(cfg_avg, meg_all);

figure;

plot(avg_A.time, mean(avg_A.avg), 'b','LineWidth',1.5); hold on;
plot(avg_B.time, mean(avg_B.avg), 'r','LineWidth',1.5);

legend('HV_perc','LV_perc')

xlabel('Time (s)')
ylabel('Mean amplitude')
title('Occipital ERF')

xline(0,'--','Stimulus onset','LineWidth',3)

%% Test 3: Grating A vividness/visibility to Grating B viviness/visibility

GratingA_HV = meta.orientation ==1 & meta.condition == 1 & meta.reproduction ==1 | meta.orientation ==1 & meta.condition == 0 & meta.detection == 1 & meta.reproduction ==1;
GratingA_LV = meta.orientation ==1 & meta.condition == 1 & meta.reproduction ==0 | meta.orientation ==1 & meta.condition == 0 & meta.detection == 1 & meta.reproduction ==0;

GratingB_HV = meta.orientation ==2 & meta.condition == 1 & meta.reproduction ==1 | meta.orientation ==2 & meta.condition == 0 & meta.detection == 1 & meta.reproduction ==1;
GratingB_LV = meta.orientation ==2 & meta.condition == 1 & meta.reproduction ==0 | meta.orientation ==2 & meta.condition == 0 & meta.detection == 1 & meta.reproduction ==0;

classA = GratingA_HV;
classB = GratingA_LV;
classC = GratingB_HV;
classD = GratingB_LV;

%Prepare training data
valid_trials_train = classA | classB;

labels_train = ones(sum(valid_trials_train),1)*2;
labels_train(classA(valid_trials_train)) = 1;
meg_train = all_trials_meg_3d(:,:,valid_trials_train);

idxA = find(labels_train==1);
idxB = find(labels_train==2);

nMin = min(length(idxA),length(idxB));

idxA = idxA(randperm(length(idxA),nMin));
idxB = idxB(randperm(length(idxB),nMin));

idx = [idxA; idxB];

labels_train = labels_train(idx);
meg_train    = meg_train(:,:,idx);

X_train = permute(meg_train,[3 1 2]);

%Prepare testing data

valid_trials_test = classC | classD;

labels_test = ones(sum(valid_trials_test),1)*2;
labels_test(classC(valid_trials_test)) = 1;
meg_test = all_trials_meg_3d(:,:,valid_trials_test);

idxA = find(labels_test==1);
idxB = find(labels_test==2);

nMin = min(length(idxA),length(idxB));

idxA = idxA(randperm(length(idxA),nMin));
idxB = idxB(randperm(length(idxB),nMin));

idx = [idxA; idxB];

labels_test = labels_test(idx);
meg_test    = meg_test(:,:,idx);

X_test = permute(meg_test,[3 1 2]);


cfg = [];
cfg.model = 'lda';
cfg.metric = 'accuracy';
cfg.preprocess = {'average_samples'};

[perf,result] = mv_classify_timextime(cfg,X_train,labels_train,X_test,labels_test);

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
title('Temporal Generalization - Grating A Viv/Visib --> Grating B');
colormap(bluewhitered)
top_acc = max(perf, [], 'all');
%clim([0.5 - (top_acc-0.5) , top_acc])
clim([0, 1])

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

legend('Grating A - High Viv','Grating A - Low Viv')

xlabel('Time (s)')
ylabel('Mean amplitude')
title('Occipital ERF')

xline(0,'--','Stimulus onset','LineWidth',3)

cfg_avg = [];
cfg_avg.channel = 'MLO*';

cfg_avg.trials = find(classC);
avg_A = ft_timelockanalysis(cfg_avg, meg_all);

cfg_avg.trials = find(classD);
avg_B = ft_timelockanalysis(cfg_avg, meg_all);

figure;

plot(avg_A.time, mean(avg_A.avg), 'b','LineWidth',1.5); hold on;
plot(avg_B.time, mean(avg_B.avg), 'r','LineWidth',1.5);

legend('Grating B - High Viv','Grating B - Low Viv')

xlabel('Time (s)')
ylabel('Mean amplitude')
title('Occipital ERF')

xline(0,'--','Stimulus onset','LineWidth',3)



%% Test 2: Vividness to RJ
% flatten everything
meta.condition    = reshape(conditionPerTrial',[],1);
meta.orientation  = reshape(oriPerTrial',[],1);
meta.presence     = reshape(presence',[],1);
meta.detection    = reshape(detection',[],1);
meta.reproduction = reshape(reproduction',[],1);
meta.run          = reshape(allRuns',[],1);

img_idx  = find(meta.condition==1);
perc_idx = find(meta.condition==0);

meta.reproduction(img_idx)  = meta.reproduction(img_idx)  > median(meta.reproduction(img_idx));
meta.reproduction(perc_idx) = meta.reproduction(perc_idx) > median(meta.reproduction(perc_idx));

HV_img    = meta.condition == 1 & meta.reproduction == 1;
LV_img    = meta.condition == 1 & meta.reproduction == 0;

PresentImg = meta.condition == 1 & meta.detection == 1;
AbsentImg  = meta.condition == 1 & meta.detection == 0;

classA = HV_img;      % train label 1
classB = LV_img;      % train label 2
classC = PresentImg;  % test label 1
classD = AbsentImg;   % test label 2

runs = unique(meta.run);
nRuns = numel(runs);

all_perf = cell(nRuns,1);
all_diag = cell(nRuns,1);

for r = 1:nRuns

    test_run = runs(r);
    fprintf('\n===== Fold %d/%d | Test run = %d =====\n', r, nRuns, test_run);

    train_runs_mask = meta.run ~= test_run;
    test_run_mask   = meta.run == test_run;

    % -------------------------
    % Prepare training data
    % -------------------------
    valid_trials_train = (classA | classB) & train_runs_mask;

    labels_train = ones(sum(valid_trials_train),1) * 2;
    labels_train(classA(valid_trials_train)) = 1;

    meg_train = all_trials_meg_3d(:,:,valid_trials_train);

    idxA = find(labels_train == 1);
    idxB = find(labels_train == 2);

    nMin_train = min(length(idxA), length(idxB));

    if nMin_train == 0
        warning('Skipping fold %d: one training class is empty.', r);
        continue
    end

    idxA = idxA(randperm(length(idxA), nMin_train));
    idxB = idxB(randperm(length(idxB), nMin_train));
    idx  = [idxA; idxB];

    labels_train = labels_train(idx);
    meg_train    = meg_train(:,:,idx);

    X_train = permute(meg_train, [3 1 2]);

    % -------------------------
    % Prepare testing data
    % -------------------------
    valid_trials_test = (classC | classD) & test_run_mask;

    labels_test = ones(sum(valid_trials_test),1) * 2;
    labels_test(classC(valid_trials_test)) = 1;

    meg_test = all_trials_meg_3d(:,:,valid_trials_test);

    idxA = find(labels_test == 1);
    idxB = find(labels_test == 2);

    nMin_test = min(length(idxA), length(idxB));

    if nMin_test == 0
        warning('Skipping fold %d: one test class is empty.', r);
        continue
    end

    % idxA = idxA(randperm(length(idxA), nMin_test));
    % idxB = idxB(randperm(length(idxB), nMin_test));
    idx  = [idxA; idxB];

    labels_test = labels_test(idx);
    meg_test    = meg_test(:,:,idx);

    X_test = permute(meg_test, [3 1 2]);

    % -------------------------
    % Decode
    % -------------------------
    cfg = [];
    cfg.model = 'lda';
    cfg.metric = 'accuracy';
    cfg.preprocess = {'average_samples'};

    [perf, result] = mv_classify_timextime(cfg, X_train, labels_train, X_test, labels_test);

    all_perf{r} = perf;
    all_diag{r} = diag(perf);

    fprintf('Train trials: %d | Test trials: %d\n', size(X_train,1), size(X_test,1));
    fprintf('Fold diagonal mean accuracy: %.3f\n', mean(diag(perf)));

end

% Remove skipped folds
valid_folds = ~cellfun(@isempty, all_perf);
all_perf = all_perf(valid_folds);
all_diag = all_diag(valid_folds);

% Average across folds
perf_4d = cat(3, all_perf{:});
mean_perf = mean(perf_4d, 3);

diag_mat = cat(2, all_diag{:});
mean_diag = mean(diag_mat, 2);

time_axis = meg_all.time{1};

fprintf('\n===== Final LORO result across %d folds =====\n', numel(all_perf));
fprintf('Diagonal mean accuracy: %.3f\n', mean(mean_diag));

[peak_acc, peak_idx] = max(mean_diag);
fprintf('Peak diagonal accuracy: %.3f at t=%.3fs\n', peak_acc, time_axis(peak_idx));

% -------------------------
% Plot averaged temporal generalization
% -------------------------
figure;
imagesc(time_axis, time_axis, mean_perf);
axis xy;
xlabel('Train Time (s)');
ylabel('Test Time (s)');
title('Temporal Generalization - Vividness --> RJ (Leave-One-Run-Out)');
colormap(bluewhitered)
clim([0, 1])
colorbar_handle = colorbar;
ylabel(colorbar_handle,'Accuracy','FontSize',16,'Rotation',270);

xline(0,'black','LineWidth',3)
yline(0,'black','LineWidth',3)

% -------------------------
% Plot averaged diagonal
% -------------------------
figure;
plot(time_axis, movmean(mean_diag,20), 'k', 'LineWidth', 2);
xlabel('Time (s)')
ylabel('Accuracy')
title('Diagonal Decoding Accuracy (Leave-One-Run-Out)')
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

legend('HV_imagery','LV_imagery')

xlabel('Time (s)')
ylabel('Mean amplitude')
title('Occipital ERF')

xline(0,'--','Stimulus onset','LineWidth',3)

cfg_avg = [];
cfg_avg.channel = 'MLO*';

cfg_avg.trials = find(classC);
avg_A = ft_timelockanalysis(cfg_avg, meg_all);

cfg_avg.trials = find(classD);
avg_B = ft_timelockanalysis(cfg_avg, meg_all);

figure;

plot(avg_A.time, mean(avg_A.avg), 'b','LineWidth',1.5); hold on;
plot(avg_B.time, mean(avg_B.avg), 'r','LineWidth',1.5);

legend('Imagined: Response Present','Imagined: Response Absent')

xlabel('Time (s)')
ylabel('Mean amplitude')
title('Occipital ERF')

xline(0,'--','Stimulus onset','LineWidth',3)