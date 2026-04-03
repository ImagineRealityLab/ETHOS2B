% executes all sub-scripts in the correct order and collects intermediate
% results
clear; plotting = false;
addpath('Utilities');
addpath('SelectedNoisePatches')
addpath('Settings')

%% Import participant information
subID = input('Please enter participant name: ','s'); % get the subject ID

settings = load(strcat(subID,'_settings.mat'));

orientations = settings.orientations;

%% Set localizer parameters
localizer_orientations = 0:22.5:157.5;
localizer_per_block = 2;
useTrigger = 0;

if useTrigger
    deviceToUse = 5;
else
    deviceToUse = 2;
end

if rem(str2double(subID),2) == 0
    staircase_ori = 1;
    staircase_key = 'A';
else
    staircase_ori = 2;
    staircase_key = 'B';
end
%% Sound check + volume adjustment
[volume] = soundCheck_MEG(orientations,deviceToUse);

%% In-scanner staircase

[SC_V1,SC_acc1] = StaircaseMEG(subID,orientations(staircase_ori),staircase_key,250,1, deviceToUse, volume);

[~,b1] = min(abs(SC_acc1-0.7));

V = SC_V1(b1);


%% Trial structure
nBlocks = 16; % must be at least 4 to illustrate all possibilities!
trialsPerBlock = 4;

[blocks, trials, ITIs, responseMappings,vividnessMappings] = generateBlocks(nBlocks, trialsPerBlock);

outputSettings = fullfile(cd,'settings');
saveNameMegSettings = sprintf('MEGSettings_%s.mat',subID);
save(fullfile(outputSettings,saveNameMegSettings)); % save the settings for crashes


%% Run the main task script

startBlock = 1;
startTrial = 1;

[R,C,data_localizer,MEG_DATA] = MainTask_MEG_NumResponse(subID,orientations,V,useTrigger, ...
    localizer_orientations, localizer_per_block, blocks, trials, startBlock, startTrial, ...
    ITIs, responseMappings,vividnessMappings, deviceToUse,volume);

sca
warning('on','all');


%% Final data collection
out = struct();

out.subID = subID;
out.timestamp = datestr(now);
out.orientations = orientations;
out.localizer_orientations = localizer_orientations;
out.localizer_per_block = localizer_per_block;
out.useTrigger = useTrigger;
out.V = V;

out.R = R;
out.C = C;
out.data_localizer = data_localizer;
out.MEG_DATA = MEG_DATA;

save(sprintf('%s_fullTaskOutput.mat', subID), 'out', '-v7.3');
