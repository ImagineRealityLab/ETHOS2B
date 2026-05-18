%% =========================================================
%  Prestimulus alpha → Detection GLM
%  Tests H1 (sensory gain) vs H2 (prior precision) on
%  imagery vs no-imagery absence trials
% ==========================================================

clear; clc; close all
addpath("Utilities")
addpath(genpath("behavioural\"))
seed = 42; rng(seed)

subjects   = {'subj-1','subj-4','subj-5'};
noSubjects = [1 4 5];

% Analysis parameters
alpha_foi     = 8:0.5:13;        % alpha band
pre_toi_main  = [-1.9, 0];       % primary prestimulus window

% Pre-allocate
glm_results = struct();

for iSubj = 1:length(subjects)

    fprintf('\n========== Subject %s ==========\n', subjects{iSubj})

    %% Load MEG data
    meg_data = load(fullfile('results', subjects{iSubj}, ...
        'Preprocessed_ICAclean_realigned.mat'));
    meg_data = meg_data.data_ica_clean;

    cfg         = [];
    cfg.channel = 'MEG';
    meg_all     = ft_selectdata(cfg, meg_data);

    %% Load rejection log
    rejection_hist = load(fullfile('results', subjects{iSubj}, ...
        'rejection_log.mat'));
    rejection_hist = rejection_hist.rejection_log;

    allRejectedTrials = [];
    if iSubj == 1
        for iRun = 1:8
            allRejectedTrials = [allRejectedTrials, ...
                rejection_hist(1,iRun).trials_removed];
        end
    else
        for iRun = 1:length(rejection_hist)
            allRejectedTrials = [allRejectedTrials, ...
                rejection_hist(1,iRun).trialsRemovedGlobal];
        end
    end

    %% Load and flatten behavioural data
    beh_data      = load(sprintf('PMT_%d.mat', noSubjects(iSubj)));
    block_info    = beh_data.blocks;
    trial_info    = beh_data.trials;
    response_info = beh_data.R;

    cond         = block_info(:,2);        % imagery=1 / perception=0
    presence     = trial_info(:,:,1);
    detection    = response_info(:,:,3);
    reproduction = response_info(:,:,1);
    grating      = block_info(:,1);

    nRuns  = size(block_info,1) / 2;
    nTrial = size(presence,2);

    % Expand block variables to trials
    conditionPerTrial = repmat(cond,    1, nTrial);
    oriPerTrial       = repmat(grating, 1, nTrial);
    runPerTrial       = repmat((1:nRuns)', 1, nTrial);

    allRuns = [];
    for iRun = 1:nRuns
        allRuns = [allRuns; runPerTrial(iRun,:); runPerTrial(iRun,:)];
    end

    % Flatten
    meta.condition    = reshape(conditionPerTrial', [], 1);
    meta.orientation  = reshape(oriPerTrial',       [], 1);
    meta.presence     = reshape(presence',          [], 1);
    meta.detection    = reshape(detection',         [], 1);
    meta.reproduction = reshape(reproduction',      [], 1);
    meta.run          = reshape(allRuns',           [], 1);

    % Apply artefact rejection mask
    nTotal           = length(meta.condition);
    keepMask         = true(nTotal, 1);
    keepMask(allRejectedTrials) = false;

    f = fieldnames(meta);
    for k = 1:length(f), meta.(f{k}) = meta.(f{k})(keepMask); end

    % Drop trials with missing behavioural responses
    keepMask2 = ~isnan(meta.reproduction) & ~isnan(meta.detection);
    for k = 1:length(f), meta.(f{k}) = meta.(f{k})(keepMask2); end
    
    imgIdx = find(meta.condition == 1);
    percIdx = find(meta.condition == 0);
    zViv = zscore(meta.reproduction(imgIdx));
    zVis = zscore(meta.reproduction(percIdx));
    meta.reproduction(imgIdx) = zViv;
    meta.reproduction(percIdx) = zVis;

    % Get the matching MEG trials
    TrialsAll    = 1:size(meg_all.trial, 2);
    TrialsKept   = TrialsAll(keepMask2);

    cfg            = [];
    cfg.trials     = TrialsKept;
    megClean       = ft_selectdata(cfg, meg_all);

    %% Frequency analysis (all trials)
    t_ftimwin = 5 ./ alpha_foi;
    half_win  = max(t_ftimwin) / 2;

    cfg            = [];
    cfg.output     = 'pow';
    cfg.method     = 'mtmconvol';
    cfg.taper      = 'hanning';
    cfg.keeptrials = 'yes';
    cfg.foi        = alpha_foi;
    cfg.t_ftimwin  = t_ftimwin;
    cfg.toi        = (-2.4 + half_win):0.05:(0.7 - half_win);
    Freq           = ft_freqanalysis(cfg, megClean);

    %% Per-trial alpha (scalar)
    t_idx_main  = Freq.time >= pre_toi_main(1)  & Freq.time <= pre_toi_main(2);
    alpha_main  = squeeze(mean(Freq.powspctrm(:,:,:,t_idx_main),  [2 3 4], 'omitnan'));
    alpha_main  = log10(alpha_main  + eps);

    %% Build design matrix
    T = table( ...
        meta.detection,                  ...
        zscore(alpha_main),              ...
        meta.condition - 0.5,            ...   % imagery=+0.5, no-imagery=-0.5
        meta.presence  - 0.5,            ...   % present=+0.5, absent=-0.5
        meta.reproduction,       ...
        meta.run,                        ...
        'VariableNames', ...
        {'detection','alpha','condition','presence','vivvis','run'});

    %% Fit logistic GLM — main window
    formula = ['detection ~ alpha * condition * vivvis + ' ...
           'presence + alpha:presence + run'];

    try
        mdl = fitglm(T, formula, 'Distribution','binomial', 'Link','logit');
    catch ME
        warning('Subject %s GLM failed: %s', subjects{iSubj}, ME.message)
        glm_results(iSubj).betas = [];
        continue
    end

    disp(mdl.Coefficients)

    %% Store
    glm_results(iSubj).subject     = subjects{iSubj};
    glm_results(iSubj).betas       = mdl.Coefficients.Estimate;
    glm_results(iSubj).pvals       = mdl.Coefficients.pValue;
    glm_results(iSubj).names       = mdl.Coefficients.Row;

    clear meta

end % iSubj


%% =========================================================
%  GROUP LEVEL
% ==========================================================

validIdx = find(~cellfun(@isempty, {glm_results.betas}));
nSubj    = length(validIdx);
fprintf('\n========== GROUP (N = %d) ==========\n', nSubj)
if nSubj < 2, error('Not enough subjects'); end

beta_names      = glm_results(validIdx(1)).names;
all_betas       = cell2mat(arrayfun(@(s) glm_results(s).betas,       validIdx, 'uni',0));

% Index helper
idx = @(name) find(strcmp(beta_names, name));

% Critical terms
terms_to_test = { ...
    'condition',                  'B_condition (manipulation check)';   ...
    'presence',                   'B_presence (sanity check)';          ...
    'vivvis',                     'B_vivvis (subjective signal)';       ...
    'alpha',                      'B_alpha (main effect)';              ...
    'alpha:condition',            'B_alpha x cond';                     ...
    'alpha:vivvis',               'B_alpha x vivvis';                   ...
    'condition:vivvis',           'B_cond x vivvis';                    ...
    'alpha:condition:vivvis',     'B_alpha x cond x vivvis (KEY)'       ...
};

fprintf('\n=== TESTS (main window) ===\n')
for iT = 1:size(terms_to_test,1)
    name  = terms_to_test{iT,1};
    label = terms_to_test{iT,2};
    i     = idx(name);
    if isempty(i), fprintf('%s -- not in model\n', label); continue; end
    [~, p, ~, s] = ttest(all_betas(i,:));
    fprintf('%-40s mean=%6.3f  t(%d)=%6.3f  p=%.4f\n', ...
        label, mean(all_betas(i,:)), nSubj-1, s.tstat, p)
end

%% Simple slopes for alpha × condition (collapsed over presence)
fprintf('\n=== Alpha simple slopes by condition ===\n')
simple_img = all_betas(idx('alpha'),:) + 0.5 * all_betas(idx('alpha:condition'),:);
simple_no  = all_betas(idx('alpha'),:) - 0.5 * all_betas(idx('alpha:condition'),:);

[~, p_img, ~, s_img] = ttest(simple_img);
[~, p_no,  ~, s_no]  = ttest(simple_no);
fprintf('Alpha in IMAGERY:    mean=%.3f  t=%.3f  p=%.4f\n', mean(simple_img), s_img.tstat, p_img)
fprintf('Alpha in NO-IMAGERY: mean=%.3f  t=%.3f  p=%.4f\n', mean(simple_no),  s_no.tstat,  p_no)

%% Four-cell simple slopes (cond × vivvis) — alpha effect in each cell
fprintf('\n=== Alpha simple slopes by cell (condition × vivvis) ===\n')
b_a   = all_betas(idx('alpha'),:);
b_axc = all_betas(idx('alpha:condition'),:);
b_axv = all_betas(idx('alpha:vivvis'),:);
i_3w  = idx('alpha:condition:vivvis');

if ~isempty(i_3w)
    b_3w = all_betas(i_3w,:);
else
    b_3w = zeros(1, nSubj);
end

% vivvis is z-scored within condition, so ±1 = ±1 SD
cells = {                                          ...
    'Imagery, High vividness',     +0.5,  +1;      ...
    'Imagery, Low vividness',      +0.5,  -1;      ...
    'No-imagery, High visibility', -0.5,  +1;      ...
    'No-imagery, Low visibility',  -0.5,  -1       ...
};

cell_slopes = zeros(4, nSubj);
for iC = 1:4
    c = cells{iC,2}; v = cells{iC,3};
    cell_slopes(iC,:) = b_a + c*b_axc + v*b_axv + c*v*b_3w;
    [~, pv, ~, st] = ttest(cell_slopes(iC,:));
    fprintf('%-30s mean=%6.3f  t=%6.3f  p=%.4f\n', ...
        cells{iC,1}, mean(cell_slopes(iC,:)), st.tstat, pv)
end


%% =========================================================
%  PLOTS
% ==========================================================

%% 1. Beta coefficients
plot_terms = {'condition','presence','vivvis','alpha', ...
              'alpha:condition','alpha:vivvis', ...
              'condition:vivvis','alpha:condition:vivvis'};

figure('Color','w','Position',[100 100 1400 450])
for iB = 1:length(plot_terms)
    i = idx(plot_terms{iB});
    if isempty(i), continue; end
    vals = all_betas(i,:);
    [~, p] = ttest(vals);
    mu  = mean(vals);
    sem = std(vals) / sqrt(nSubj);
    col = [0.7 0.7 0.7]; if p < 0.05, col = [0.2 0.6 0.9]; end

    subplot(1, length(plot_terms), iB); hold on
    scatter(ones(1,nSubj), vals, 40, 'k', 'filled', 'MarkerFaceAlpha', 0.4)
    errorbar(1, mu, sem, 'o', 'Color', col, 'MarkerFaceColor', col, ...
        'LineWidth', 2, 'MarkerSize', 11, 'CapSize', 10)
    yline(0, 'k--')
    xlim([0.5 1.5]); xticks([])
    title(sprintf('%s\np=%.3f', strrep(plot_terms{iB},':',' × '), p), 'FontSize', 10)
    box off
end
sgtitle(sprintf('Prestimulus alpha GLM (N=%d)', nSubj), 'FontWeight','bold')

%% 2. Four-cell simple slopes (cond × vivvis)
figure('Color','w','Position',[100 100 750 500]); hold on
cell_labels = cellfun(@(c) strrep(c,', ','\newline'), cells(:,1), 'uni', 0);
mu_cells  = mean(cell_slopes, 2);
sem_cells = std(cell_slopes, 0, 2) / sqrt(nSubj);

% Colour by condition: imagery = blue, no-imagery = orange
colours = [0.3 0.5 0.8; 0.3 0.5 0.8; 0.9 0.6 0.3; 0.9 0.6 0.3];
for iC = 1:4
    bar(iC, mu_cells(iC), 'FaceColor', colours(iC,:), 'EdgeColor','none')
end
errorbar(1:4, mu_cells, sem_cells, 'k', 'LineStyle','none', ...
    'LineWidth', 1.8, 'CapSize', 10)

for iC = 1:4
    scatter(iC + 0.08*randn(1,nSubj), cell_slopes(iC,:), ...
        40, 'k', 'filled', 'MarkerFaceAlpha', 0.5)
end

yline(0, 'k--', 'LineWidth', 1.2)
xticks(1:4); xticklabels(cell_labels)
ylabel('Alpha → Detection slope (log-odds)')
title('Alpha effect by condition × subjective rating')
box off; ax = gca; ax.FontSize = 12;

