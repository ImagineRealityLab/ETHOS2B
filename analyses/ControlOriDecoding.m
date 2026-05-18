clear
clc
close all
addpath("Utilities")
addpath(genpath("MVPA-Light-master"));
addpath(genpath("behavioural\"))
seed = 42;
rng(seed)

subjects = {'subj-1', 'subj-2', 'subj-3', 'subj-4', 'subj-5'};

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

beh_data = load(sprintf('PMT_%d.mat', iSubj));

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

gratingA_hit = meta.presence == 1 & meta.detection == 1 & meta.orientation ==1;
gratingB_hit = meta.presence == 1 & meta.detection == 1 & meta.orientation ==2;

classA = gratingA_hit;
classB = gratingB_hit;

runClassA = meta.run(classA);
runClassB = meta.run(classB);

classesCombined = [runClassA ; runClassB];

if sum(classA) <2|| sum(classB) <2
    fprintf('Invalid analysis for subject %d', iSubj)
    continue
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
X_train = movmean(X_train, 13, 3); % 20 ms temporal smoothing

cfg = [];
cfg.model = 'lda';
cfg.metric = 'auc';
cfg.preprocess = {'undersample', 'zscore', 'pca'};
[perf,result] = mv_classify_timextime(cfg, X_train, labels_train);

time_axis = meg_all.time{1};
diag_perf = diag(perf);

fprintf('Diagonal mean accuracy: %.3f\n', mean(diag_perf));

[peak_acc, peak_idx] = max(diag_perf);
fprintf('Peak diagonal accuracy: %.3f at t=%.3fs\n', peak_acc, time_axis(peak_idx));

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
title(sprintf('Diagonal decoding - Hit Orientation Decoding, N = %d', nValidSubj));
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
title(sprintf('Diagonal decoding - Hit Orientation Decoding, N = %d', nValidSubj))
colormap(bluewhitered)
clim([0,1])   % symmetric around chance
colorbar_handle = colorbar;
label= ylabel(colorbar_handle, 'AUC', 'FontSize', 16, 'Rotation', 270);

label.Position(1) = 3.5;

xline(0, 'black', 'LineWidth', 3)
yline(0, 'black', 'LineWidth', 3)



