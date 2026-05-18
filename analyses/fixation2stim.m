clear
clc
close all
addpath("Utilities")
addpath(genpath("MVPA-Light-master"));
addpath(genpath("behavioural\"))
seed = 42;
rng(seed)

subjects = {'subj-1', 'subj-2','subj-3','subj-4', 'subj-5'};

results = cell(1, length(subjects));

for iSubj = 1:length(subjects)

meg_data = load(fullfile('results', subjects{iSubj}, 'preProcLocalizer.mat'));
meg_data = meg_data.data_ica_clean;

cfg = [];
cfg.channel = 'MEG';
cfg.latency = [-0.2 0];
fixationMEG = ft_selectdata(cfg, meg_data);

cfg = [];
cfg.channel = 'MEG';
cfg.latency = [0 0.2];
fixationStim = ft_selectdata(cfg, meg_data);

fixation3d   = cat(3, fixationMEG.trial{:});  %features, time, samples
stim3d       = cat(3, fixationStim.trial{:});  %features, time, samples

X_train      = cat(3, fixation3d, stim3d);  %features, time, samples
X_train = permute(X_train, [3 1 2]);   % [trials x channels x time]
labels_train = [zeros(size(fixation3d,3),1) ; ones(size(stim3d,3),1)];

sample_rate = meg_data.time{1,1}(2) - meg_data.time{1,1}(1);
smoothing = 0.02;
tp = smoothing / sample_rate;

X_train = movmean(X_train, tp, 3); % 20 ms temporal smoothing

cfg = [];
cfg.model = 'lda';
cfg.metric = 'auc';
cfg.preprocess = {'undersample','average_samples', 'zscore', 'pca'};
cfg.preprocess_param{4} = [];
cfg.preprocess_param{4}.explained_variance = 0.95;

[perf,result] = mv_classify_timextime(cfg, X_train, labels_train);

time_axis = fixationMEG.time{1};
    

% perf = combinedTGM ./ nRun;
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
plot(time_axis, diag_perf, 'k', 'LineWidth', 2);
xlabel('Time (s)')
ylabel('AUC')
title(sprintf('Diagonal Decoding AUC - Subject %d', iSubj))
yline(0.5, '--', 'Chance level', 'LineWidth', 3)
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

xlabel('Time (s)');
ylabel('AUC');
ylim([0,1])
ax = gca;
ax.FontSize = 30;
ax.FontWeight = 'bold';

box off;

%% Plot - TGM

figure;
imagesc(time_axis, time_axis, sharedTGM);
axis xy;
colormap(bluewhitered)
clim([0,1])   % symmetric around chance
colorbar_handle = colorbar;

ax = gca;
ax.FontSize = 30;
ax.FontWeight = 'bold';

box off;

