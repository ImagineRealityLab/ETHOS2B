clear
clc
close all
addpath("Utilities")
addpath(genpath("MVPA-Light-master"));
addpath(genpath("behavioural\"))
seed = 42;
rng(seed)

subjects = {'subj-1', 'subj-2','subj-3','subj-4', 'subj-5'};
subjectnos = [1,2,3,4,5];

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

beh_data = load(sprintf('PMT_%d.mat', subjectnos(iSubj)));

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

img_vals  = meta.reproduction(img_idx);
perc_vals = meta.reproduction(perc_idx);

img_q25  = prctile(img_vals, 25);
img_q75  = prctile(img_vals, 75);

perc_q25 = prctile(perc_vals, 25);
perc_q75 = prctile(perc_vals, 75);

img_median = median(img_vals);
perc_median = median(perc_vals);

if perc_q75 == 0
    perc_q75 = 0 + eps;
end

if perc_median ==0 
    perc_median = 0+eps;
end

imageryYesTrials = find(meta.condition == 1 & meta.detection == 1);
imageryYesVividness = meta.reproduction(imageryYesTrials);
imageryYes_q25 = prctile(imageryYesVividness,25);
imageryYes_q75 = prctile(imageryYesVividness,75);
imageryYes_median = median(imageryYesVividness);




%% Test 1: Vividness to RJ (quartile-based)

classA = meta.condition == 1 & meta.detection == 1 & meta.reproduction >= imageryYes_q75;
classB = meta.condition == 1 & meta.detection == 1 & meta.reproduction <= imageryYes_q25;

% Imagery trials only
classC = meta.condition == 1 & meta.detection == 1;   % "yes" response
classD  = meta.condition == 1 & meta.detection == 0;   % "no" response

idxRJ_present = find(classC);
idxRJ_absent  = find(classD);

% Number of random draws
nRand = 1000;

% Match class sizes
nMin = min(numel(idxRJ_present), numel(idxRJ_absent));

% Preallocate best solution
best_RJ_present = [];
best_RJ_absent  = [];
best_diff = Inf;

for iRand = 1:nRand

    % Randomly sample nMin trials from each class
    samp_present = idxRJ_present(randperm(numel(idxRJ_present), nMin));
    samp_absent  = idxRJ_absent(randperm(numel(idxRJ_absent), nMin));

    % Get vividness ratings for sampled trials
    viv_present = meta.reproduction(samp_present);
    viv_absent  = meta.reproduction(samp_absent);

    % Sort vividness values
    viv_presentSorted = sort(viv_present, 'ascend');
    viv_absentSorted  = sort(viv_absent, 'ascend');

    % Compute distribution mismatch
    diff_val = mean((viv_absentSorted - viv_presentSorted).^2);

    % Keep best-matched subsets
    if diff_val < best_diff
        best_diff = diff_val;
        best_RJ_present = samp_present;
        best_RJ_absent  = samp_absent;
    end
end


%% --------------------------
% Prepare training data
% --------------------------

valid_trials_train = classA | classB;

labels_train = ones(sum(valid_trials_train),1)*2;
labels_train(classA(valid_trials_train)) = 1;

meg_train = all_trials_meg_3d(:,:,valid_trials_train);

idxA = find(labels_train==1);   % HV_img
idxB = find(labels_train==2);   % LV_img

nMin = min(length(idxA), length(idxB));

idx = [idxA; idxB];

labels_train = labels_train(idx);
meg_train    = meg_train(:,:,idx);

X_train = permute(meg_train, [3 1 2]);   % [trials x channels x time]


%% --------------------------
% Prepare testing data
% --------------------------

labels_test = [ones(length(best_RJ_present),1); ones(length(best_RJ_absent), 1) + 1];

meg_test = all_trials_meg_3d(:,:,[best_RJ_present;best_RJ_absent]);


sample_rate = meg_data.time{1,1}(2) - meg_data.time{1,1}(1);
smoothing = 0.04;
tp = smoothing / sample_rate;


X_test = permute(meg_test, [3 1 2]);   % [trials x channels x time]
X_train = movmean(X_train, tp, 3); % 20 ms temporal smoothing
X_test = movmean(X_test, tp, 3); % 20 ms temporal smoothing

trainRunNo = meta.run(classA | classB);
testRunNo = meta.run([best_RJ_present;best_RJ_absent]);

nRun = length(min(meta.run):max(meta.run));
combinedTGM = zeros(size(X_test,3), size(X_test,3));

for iRun = min(meta.run):max(meta.run)

    X_test_sub = X_test(testRunNo == iRun, :,:);
    labels_test_sub = labels_test(testRunNo == iRun);

    X_train_sub = X_train(trainRunNo ~= iRun,:,:);
    labels_train_sub = labels_train(trainRunNo ~= iRun);
    % Adaptive group_size: ensure at least 2 averages per class
    min_samples = min([sum(labels_train_sub==1), sum(labels_train_sub==2), ...
                   sum(labels_test_sub==1),  sum(labels_test_sub==2)]);
    
    group_size = min(5, floor(min_samples / 2));  % guarantee nav >= 2

    
    cfg = [];
    cfg.model = 'lda';
    cfg.metric = 'auc';
    if group_size <= 1
        cfg.preprocess = {'undersample', 'zscore', 'pca'};  % skip averaging entirely
        cfg.preprocess_param = {};
        cfg.preprocess_param{3} = [];
        cfg.preprocess_param{3}.explained_variance = 0.95;
    else
        cfg.preprocess = {'undersample', 'average_samples', 'zscore', 'pca'};
        cfg.preprocess_param = {};
        cfg.preprocess_param{2} = [];
        cfg.preprocess_param{2}.group_size = group_size;
        cfg.preprocess_param{4} = [];
        cfg.preprocess_param{4}.explained_variance = 0.95;
    end

    
    [perf,result] = mv_classify_timextime(cfg, X_train_sub, labels_train_sub, X_test_sub, labels_test_sub);
    
    time_axis = meg_all.time{1};
    combinedTGM = combinedTGM + perf;
end

perf = combinedTGM ./ nRun;
diag_perf = diag(perf);

%% --------------------------
% Plot temporal generalization
% --------------------------

figure;
imagesc(time_axis, time_axis, perf);
axis xy;
xlabel('Train Time (s)');
ylabel('Test Time (s)');
title(sprintf('Temporal Generalization - Subject %d', iSubj))
colormap(bluewhitered)

top_acc = max(perf, [], 'all');
clim([0,1])   % symmetric around chance
colorbar_handle = colorbar;
label= ylabel(colorbar_handle, 'AUC', 'FontSize', 16, 'Rotation', 270);

label.Position(1) = 3.5;

xline(0, 'black', 'LineWidth', 3)
yline(0, 'black', 'LineWidth', 3)

%% --------------------------
% Plot diagonal
% --------------------------

figure;
plot(time_axis, movmean(diag_perf',20), 'k', 'LineWidth', 2);
xlabel('Time (s)')
ylabel('AUC')
title(sprintf('Diagonal Decoding AUC - Subject %d', iSubj))
xline(-1.85, '--', 'First beep', 'LineWidth', 3)
xline(-0.95, '--', 'Second beep', 'LineWidth', 3)
xline(0, '--', 'Last beep', 'LineWidth', 3)
yline(0.5, '--', 'Chance level', 'LineWidth', 3)
xlim([-2.4, 0.7])
%ylim([0.4, 0.7])

%% --------------------------
% ERF: imagery quartiles
% --------------------------

cfg_avg = [];
cfg_avg.channel = 'MLO*';

cfg_avg.trials = find(classA);
avg_A = ft_timelockanalysis(cfg_avg, meg_all);

cfg_avg.trials = find(classB);
avg_B = ft_timelockanalysis(cfg_avg, meg_all);

%% --------------------------
% ERF: perception quartiles
% --------------------------

cfg_avg = [];
cfg_avg.channel = 'MLO*';

cfg_avg.trials = find(classC);
avg_C = ft_timelockanalysis(cfg_avg, meg_all);

cfg_avg.trials = find(classD);
avg_D = ft_timelockanalysis(cfg_avg, meg_all);

erf_cell = cell(1,4);
erf_cell{1} = mean(avg_A.avg);
erf_cell{2} = mean(avg_A.avg);
erf_cell{3} = mean(avg_A.avg);
erf_cell{4} = mean(avg_A.avg);


results{iSubj} = perf;

for iClass = 1:4
    ERFs{iClass, iSubj} = erf_cell{iClass};
end

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
    this_diag = diag(this_TGM);

    all_diag(:, end+1) = this_diag; 

    sharedTGM = sharedTGM + this_TGM;

    nValidSubj = nValidSubj + 1;
end

mean_diag = mean(all_diag, 2);
sd_diag   = std(all_diag, 0, 2);

sharedTGM = sharedTGM ./ nValidSubj;
%% Plot - diagonal

figure; hold on;

% Shaded error
plot_with_shade(x, mean_diag, sd_diag, [0 0.447 0.741]);

% Mean line
plot(x, mean_diag, 'Color', [0 0.447 0.741], 'LineWidth', 2);

% Chance line (adjust if needed)
chance_level = 0.5;
yline(chance_level, 'k--', 'LineWidth', 1);

% Time zero line
xline(0, 'k--', 'LineWidth', 1);

xlabel('Time (s)');
ylabel('AUC');
title(sprintf('Diagonal decoding - Vividness <--> RJ, N = %d', nValidSubj));
xline(-1.85, '--', 'First beep', 'LineWidth', 3, 'HandleVisibility','off')
xline(-0.95, '--', 'Second beep', 'LineWidth', 3, 'HandleVisibility','off')
xline(0, '--', 'Last beep', 'LineWidth', 3, 'HandleVisibility','off')
xlim([-2.4, 0.7])
ylim([0,1])
ax = gca;
ax.FontSize = 20;
ax.FontWeight = 'bold';

box off;

%% Plot - TGM

figure;
imagesc(time_axis, time_axis, sharedTGM);
axis xy;
xlabel('Train Time (s)');
ylabel('Test Time (s)');
title(sprintf('TGM - Vividness <--> RJ, N = %d', nValidSubj))
colormap(bluewhitered)
clim([0,1])   % symmetric around chance
colorbar_handle = colorbar;
label= ylabel(colorbar_handle, 'AUC', 'FontSize', 16, 'Rotation', 270);

label.Position(1) = 3.5;

xline(0, 'black', 'LineWidth', 3)
yline(0, 'black', 'LineWidth', 3)
ax = gca;
ax.FontSize = 20;
ax.FontWeight = 'bold';

box off;



