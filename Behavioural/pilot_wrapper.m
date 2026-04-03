% executes all sub-scripts in the correct order and collects intermediate
% results
clear; plotting = false;
addpath('Utilities');
addpath('SelectedNoisePatches')


% settings
orientations = [135 45]; % rotAngles of gratings to use
orientations = orientations(randperm(length(orientations)));
subID        = input('Please enter participant name: ','s'); % get the subject ID
outDir       = fullfile('Results',subID); 
if ~exist(outDir,'dir'); mkdir(outDir); else; warning('Directory already exists!'); end

save(fullfile(outDir,sprintf('%s_settings',subID)),'orientations')

fprintf('\t THE ORIENTATIONS ARE %d AND %d \n',orientations);

% Sound device to use, check with PsychPortAudio('GetDevices'), in case of
% any problems send an email --> a.ozsu@ucl.ac.uk
deviceToUse = 2; %CHECK BEFORE TESTING

% =========================================================================
% Sound check + pitch discrimination (1 trial)
% =========================================================================
[volume] = soundCheck(orientations, deviceToUse);

% =========================================================================
% Practice detection - outside scanner (8 trials x 2 orientation)
% =========================================================================
% just a few trials per orientation to get an idea of what gratings in 
% noise look like 

[PD,PA,V] = practiceDetection_Pilot(subID,orientations, volume, deviceToUse); 
% also gives a rough +
% initial estimate of V (visibility)

% =========================================================================
% Sound Association Training - outside scanner 
% =========================================================================
sound_association_training(orientations, volume, deviceToUse)

% =========================================================================
% Sound Association Training - outside scanner 
% =========================================================================
OrientationDiscriminationTraining(orientations, volume, deviceToUse)

if rem(str2double(subID),2) == 0
    img_prac_ori = 1;
else
    img_prac_ori = 2;
end

% =========================================================================
% Practice imagery timing - Couple of trials with different speed
% configurations to imagine the gratings precisely as the same time we want
% (1 (example) + 16 trials) --> if further practice needed (1 example + 8
% trials)
% =========================================================================

img_prac_img_vividness = practice_imagery_timing(V,orientations,img_prac_ori,volume, deviceToUse);

% =========================================================================
% Practice imagery reproduction - Couple of trials asking participants to 
% reproduce their imagery vividness with a slider adjusting the noiseness
% of the images (8 trials x 2 orientations)
% =========================================================================

practiceImagery_Pilot(subID,orientations,V, volume, deviceToUse);

% =========================================================================
% Initial staircase - (48 trials x 2 orientations) 
% =========================================================================
% Provide an initial estimate of the contrast, to be fine tuned in the
% scanner later

[SC_V1,SC_acc1] = StaircasePilot(subID,orientations(1),'A',V,'test',1, volume, deviceToUse); % grating 1
save(fullfile(outDir,sprintf('%s_settings',subID)),'SC_V1','-append')

[SC_V2,SC_acc2] = StaircasePilot(subID,orientations(2),'B',V,'test',2, volume, deviceToUse); % grating 2
save(fullfile(outDir,sprintf('%s_settings',subID)),'SC_V2','-append')

% plot
subplot(2,1,1);
plot(SC_V1,'-o'); hold on; plot(SC_V2,'-o');
legend('Orientation 1','Orientation 2');
ylabel('Visibility')

subplot(2,1,2);
plot(SC_acc1,'-o'); hold on; plot(SC_acc2,'-o');
hold on; plot(xlim,[0.7 0.7],'k--')
legend('Orientation 1','Orientation 2');
ylabel('Accuracy'); 

[~,b1] = min(abs(SC_acc1-0.7));
[~,b2] = min(abs(SC_acc2-0.7));
V   = mean([SC_V1(b1) SC_V2(b2)]); % take mean staircased SAME FOR BOTH STIMULI!?

% =========================================================================
% Practice no-imagery reproduction - Couple of trials asking participants to 
% reproduce their perception vividness with a slider adjusting the noiseness
% of the images (8 trials x 2 orientations)
% =========================================================================

[R_V,R_P] = practicePerception_Pilot(subID,orientations,V, volume, deviceToUse);

% =========================================================================
% Main task practice - Combining previously practiced elements prior to the
% main task. (4 blocks x 8 trials)
% =========================================================================

[Rprac,Cprac] = Practice_MainTask(subID,orientations,V, volume, deviceToUse);

% =========================================================================
% Main task - Consists of 12 blocks each containing 24 trials.
% =========================================================================
% Generate trials
nBlocks = 4; 
trialsPerBlock = 4;

[blocks, trials, ITIs, responseMappings,vividnessMappings] = generateBlocks(nBlocks, trialsPerBlock);

% Main task
startBlock = 1;
startTrial = 1;

[R,C,BEH_DATA] = MainTask_behavioural(subID,orientations,V, ...
    blocks, trials, startBlock, startTrial, ...
    ITIs, responseMappings,vividnessMappings, deviceToUse,volume);

%% Final data collection
out = struct();

out.subID = subID;
out.timestamp = datestr(now);
out.orientations = orientations;
out.V = V;
out.R = R;
out.C = C;
out.BEH_DATA = BEH_DATA;

save(sprintf('%s_fullTaskOutput.mat', subID), 'out', '-v7.3');

sca

addpath(genpath("Results"))
clc
%% Check eligibility

results_filename = strcat('PMT_', num2str(subID), '.mat');
load(results_filename);


%% Criteria 1: No imagery accuracy above 55% and below 80%

noImgIdx = find(blocks(:,2) == 0);
imgIdx = find(blocks(:,2) == 1);

responseNoImg = R(noImgIdx,:, 3);
responseNoImg = reshape(responseNoImg, [], 1); %Flatten the responses

presenceNoImg = trials(noImgIdx,:,1);
presenceNoImg = reshape(presenceNoImg, [], 1); %Flatten the grand truth presence

accuracy = sum(responseNoImg == presenceNoImg, "all") / size(presenceNoImg,1);

accuracy = accuracy * 100;

fprintf("No imagery accuracy: %d percent", accuracy);

cond1 = accuracy < 80 & accuracy > 55;

%% Criteria 2: At least 2 valid blocks per condition

validNoImg = sum(C(noImgIdx) == 1, "all");
validImg = sum(C(imgIdx) == 1, "all");

fprintf("\n\nNumber of valid imagery blocks: %d, number of valid no imagery blocks: %d", validImg, validNoImg);

cond2 = validImg > 1 & validNoImg > 1;

%% Criteria 3: Self reported failure to imagine the gratings

fprintf("\n\nParticipant reported %d to the final imagination check", vividness)

cond3 = vividness >1;

eligibility = cond1 == true & cond2 == true & cond3 ==true;

if eligibility 
    fprintf("\n\nParticipant is eligible for the MEG.")
else 
    fprintf("\n\nParticipants is not eligible for the MEG, check the conditions above. \n")
end

