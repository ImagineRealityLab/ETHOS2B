clear;
clc;
addpath('Utilities');
addpath('C:\Users\aozsu\Desktop\ETHOS_Behavioral_Pilot\Results');
%% --- Parameters ---
subjectIDs = 1;  % Change to your actual subject list
nSubjects = numel(subjectIDs);

% Preallocate for false alarm rates
falseAlarmRatesAll = zeros(nSubjects, 2);  % Columns: [Imagery, Perception]

% Preallocate vividness storage
groupNames = {'Imagery', 'Perception'};
conditionNames = {'Hit', 'Miss', 'FalseAlarm', 'CorrectRejection'};
VividnessDataGroup = struct();

% Initialize fields as cell arrays (1 cell per subject)
for g = 1:2
    for c = 1:numel(conditionNames)
        field = sprintf('%s%sVividness', groupNames{g}, conditionNames{c});
        VividnessDataGroup.(field) = cell(1, nSubjects);
    end
end

%% --- Loop Over Subjects ---
for iSubject = 1:nSubjects
    subjectID = subjectIDs(iSubject);
    filename = sprintf("PMT_%d.mat", subjectID);
    data = load(filename);

    results = data.R;
    trials = data.trials;
    blocks = data.blocks;

    nTrialsPerBlock = size(trials, 2);
    nBlocks = size(blocks, 1);
    nBlocksPerCond = nBlocks / 2;

    falseAlarms = struct('Imagery', 0, 'Perception', 0);

    % Loop over blocks
    for iBlock = 1:nBlocks
        isImagery = blocks(iBlock, 2) == 1;
        condition = ternary(isImagery, 'Imagery', 'Perception');

        currentResults = squeeze(results(iBlock, :, :));
        currentTrials = trials(iBlock, :);
        currentResults(:, 1) = rescale(currentResults(:, 1));  % rescale vividness

        % False Alarm Count
        absentIdx = currentTrials == 0;
        responsesToAbsent = currentResults(absentIdx, 3);
        falseAlarms.(condition) = falseAlarms.(condition) + sum(responsesToAbsent);

        % Vividness per outcome
        for iTrial = 1:nTrialsPerBlock
            stim = currentTrials(iTrial);
            resp = currentResults(iTrial, 3);
            vivid = currentResults(iTrial, 1);

            if stim == 1 && resp == 1
                outcome = 'Hit';
            elseif stim == 1 && resp == 0
                outcome = 'Miss';
            elseif stim == 0 && resp == 1
                outcome = 'FalseAlarm';
            else
                outcome = 'CorrectRejection';
            end

            fieldName = sprintf('%s%sVividness', condition, outcome);
            VividnessDataGroup.(fieldName){iSubject}(end + 1) = vivid;
        end
    end

    % Compute false alarm rates for current subject
    falseAlarmRatesAll(iSubject, 1) = falseAlarms.Imagery / (nTrialsPerBlock * nBlocksPerCond);
    falseAlarmRatesAll(iSubject, 2) = falseAlarms.Perception / (nTrialsPerBlock * nBlocksPerCond);
end

%% --- Group-Level Means for Vividness ---
VividnessMeans = struct();  % Per-subject means
VividnessMeansGroup = struct();  % Group-level vector of subject means

fields = fieldnames(VividnessDataGroup);  % e.g., 'ImageryHitVividness', ...

for iField = 1:length(fields)
    field = fields{iField};

    % Initialize a vector to store per-subject means
    subjectMeans = NaN(1, nSubjects);  % use NaN to support skipping missing subjects

    for iSubject = 1:nSubjects
        % Extract data for this subject and condition
        data = VividnessDataGroup.(field){iSubject};

        if ~isempty(data)
            subjectMeans(iSubject) = mean(data);
        end
    end

    % Store per-subject means
    VividnessMeans.(field) = subjectMeans;
    VividnessMeansGroup.(field) = subjectMeans;
end

%% --- Prepare Vividness Matrix for Group Plot ---
dataMatrix = [];
groupIndex = [];

for g = 1:2
    group = groupNames{g};
    for c = 1:numel(conditionNames)
        cond = conditionNames{c};
        field = sprintf('%s%sVividness', group, cond);

        if isfield(VividnessMeansGroup, field)
            values = VividnessMeansGroup.(field)(:);
            n = numel(values);

            row = NaN(n, numel(conditionNames));
            row(:, c) = values;

            dataMatrix = [dataMatrix; row];
            groupIndex = [groupIndex, g * ones(1, n)];
        end
    end
end

% %% --- Plot Vividness Ratings ---
% figure;
% c = [0.4, 0.7, 0.9; 0.9, 0.5, 0.4];  % Custom colors: Imagery, Perception
% 
% % Violin Plot for Vividness Ratings
% daviolinplot(dataMatrix, ...
%              'groups', groupIndex, ...
%              'violin', 'full', ...
%              'scatter', 2, ...
%              'jitter', 1, ...
%              'color', c, ...
%              'boxcolors', 'w', ...
%              'scattersize', 10, ...
%              'xtlabels', conditionNames, ...
%              'legend', groupNames);
% 
% ylabel('Vividness Rating');
% title('Vividness Ratings Across Conditions');
% set(gca, 'FontSize', 20);
% 
% 
% %% --- Violin Plot: False Alarm Rates ---
% figure;
% 
% % Convert to cell array for violinplot
% dataFA = {falseAlarmRatesAll(:,1), falseAlarmRatesAll(:,2)};  % {Imagery, Perception}
% 
% daviolinplot(dataFA, ...
%              'violin', 'full', ...
%              'scatter', 2, ...
%              'jitter', 1, ...
%              'box', 1, ...
%              'boxcolors', 'k', ...
%              'colors', c, ...
%              'scattersize', 10, ...
%              'xtlabels', groupNames);
% 
% ylabel('False Alarm Rate');
% title('False Alarm Rates Across Subjects');
% set(gca, 'FontSize', 20);

%% --- Plot Vividness Ratings ---
figure;
colors = [0.4, 0.7, 0.9; 0.9, 0.5, 0.4];

dabarplot(dataMatrix, ...
          'groups', groupIndex, ...
          'errorbars', 'SD', ...
          'xtlabels', conditionNames, ...
          'legend', groupNames, ...
          'color', colors, ...
          'errorhats', 0);
ylabel('Vividness Rating');
set(gca, 'FontSize', 20);
title('Group Vividness Ratings');

%% --- Plot False Alarm Rates Across Subjects ---
figure;
dabarplot(falseAlarmRatesAll, "groups", 1:2, ...
          'xtlabels', groupNames, ...
          'errorbars', 'SD');
title('False Alarm Rates Across Subjects');
ylabel('False Alarm Rate');
set(gca, 'FontSize', 20);

%% --- Helper Function ---
function out = ternary(cond, valTrue, valFalse)
    if cond
        out = valTrue;
    else
        out = valFalse;
    end
end
