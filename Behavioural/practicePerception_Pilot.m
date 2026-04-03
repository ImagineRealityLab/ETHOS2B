function [R_V,R_P] = practicePerception_Pilot(subID,orientations,V, volume, deviceToUse)

% =========================================================================
% Setup
% =========================================================================
[w, rect] = setWindow(0);

soundDir = strcat(cd, '\SoundFiles');
sound0Dir = strcat(soundDir, '\VeryLowPitch250_48000.wav');
sound1Dir = strcat(soundDir,'\LowPitch500_48000.wav');
sound2Dir = strcat(soundDir,'\MidPitch750_48000.wav');

[y0, ~] = psychwavread(sound0Dir);

[y1, freq1] = psychwavread(sound1Dir);

[y2, ~] = psychwavread(sound2Dir);


if size(y1,2) == 1

    y2 = [y2,y2];

    y0 = [y0,y0];
end

wavedata2 = y2';

wavedata0 = y0';

InitializePsychSound;

pahandle = PsychPortAudio('Open', deviceToUse, [], 1, freq1, 2);
PsychPortAudio('Volume', pahandle, volume);

HideCursor;

load('noiseSchedules.mat')
schedules = {schedule1, schedule2, schedule3, schedule4};

% output
output = fullfile(cd,'results',subID);
if ~exist(output,'dir'); mkdir(output); end
saveName = sprintf('PI_%s.mat',subID);

% Trial number and percentage of catch trials
nOri        = length(orientations);
nTrials     = 8;

% cues
cues = {'A','B'};

% responses
R_V = zeros(nOri,nTrials,2);
R_P = zeros(nOri,nTrials,3);


fixTime   = 0.2;
mITI    = 1; % mean ITI - randomly sample from norm
sITI    = 0.5; % SD for sampling
ITIs    = normrnd(mITI,sITI,nOri,nTrials);

vis_scale = [0 logspace(log10(0.005),log10(0.2),299)]; % steps in log space
visibility = V;

% =========================================================================
% Stimuli
% =========================================================================

% Makes the gabors to show for instruction
gaborPatch   = cell(nOri,1);
gaborTexture = cell(nOri,1);
for iOri = 1:nOri
    % stimulus
    gaborPatch{iOri} = make_stimulus(orientations(iOri),1); % full visibility
    % texture
    gaborTexture{iOri} = Screen('MakeTexture',w,gaborPatch{iOri});
end

hz = Screen('NominalFrameRate', w);
ifi = 1/hz;                              % Refresh rate
nStepSize = 1;                           % 2 frames per step

displayDuration = 2.6;  % 2 frames per step
nSteps = round((displayDuration/ifi)/nStepSize);
frame_duration = ifi * nStepSize;

onset_time = 1.9;  
offset_time = 2.1; 
onset_frame = round(onset_time / frame_duration);
offset_frame = round(offset_time / frame_duration);

timePoint0 = 0.05; % a brief buffer to ensure the display is done properly
timePoint1 = 0.2;
timePoint2 = 0.95;
timePoint3 = 1.15;
TP0_frame = round(timePoint0 / frame_duration);
TP1_frame = round(timePoint1 / frame_duration);
TP2_frame = round(timePoint2 / frame_duration);
TP3_frame = round(timePoint3 / frame_duration);



%% Instructon screen
[xCenter, yCenter] = RectCenter(rect);
[x_pix, ~] = Screen('WindowSize', w);
HideCursor;
% show instructions (screen 1)
text = ['Finally, in some parts of the experiment we will ask you to report how vividly you saw the grating on the screen. \n ',...
    'In these blocks you should observe the gratings WITHOUT imagining them. \n',...
    'After each trial, you will again use the slider to now indicate how vividly you saw the grating. \n',...
    'Remember, the beep sounds reflect a countdown for when the stimulus appears. \n ',...
    'Again, make sure to always keep your eyes fixated on the cross in the middle. \n \n ',...
    '[Press any key to continue] \n '];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.6, [255 255 255]);

% show gratings
Xpos     = [x_pix*(1/3) x_pix*(2/3)];
baseRect = [0 0 size(gaborPatch{1},1) size(gaborPatch{1},1)];

allRects = nan(4, 3);
for i = 1:2
    allRects(:, i) = CenterRectOnPointd(baseRect, Xpos(i), yCenter*1.4);
end

Screen('DrawTextures', w, gaborTexture{1}, [], allRects(:,1), [],[], 0.5);
DrawFormattedText(w, 'Grating A', xCenter*(1.8/3), yCenter*1.2, [255 255 255]);

Screen('DrawTextures', w, gaborTexture{2}, [], allRects(:,2), [],[], 0.5);
DrawFormattedText(w, 'Grating B', xCenter*(3.8/3), yCenter*1.2, [255 255 255]);

Screen('Flip', w);
WaitSecs(1);
KbWait;
%% Trials start
for iOri = 1:nOri
    
    WaitSecs(fixTime);
    
    % instruction screen with gratings
    text = sprintf('During the next trials, please try to detect Grating %s (see below) \n ,\n Keep your eyes fixated on the fixation cross as much as possible. \n \n [Press any key to start] \n ',cues{iOri});
    
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);    
    
    Screen('DrawTextures', w, gaborTexture{1}, [], allRects(:,1), [],[], 0.5);
    DrawFormattedText(w, 'Grating A', xCenter*(1.8/3), yCenter*1.2, [255 255 255]);
    
    Screen('DrawTextures', w, gaborTexture{2}, [], allRects(:,2), [],[], 0.5);
    DrawFormattedText(w, 'Grating B', xCenter*(3.8/3), yCenter*1.2, [255 255 255]);
    
    Screen('Flip', w);
    WaitSecs(1);
    KbWait;
    
    RM_list = [ones(1,nTrials/2), ones(1,nTrials/2)+1];
    RM_list = RM_list(randperm(length(RM_list)));
    presence = [ones(1,nTrials/2),zeros(1,nTrials/2) ];
    presence = presence(randperm(length(presence)));
    
    for iTrial = 1:nTrials
        
        % Fixation
                Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
            4, [255,255,255], [rect(3)/2, rect(4)/2], 1);
        Screen('Flip', w);
        WaitSecs(ITIs(iOri,iTrial));

        Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
            4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
        Screen('Flip', w);
        WaitSecs(fixTime);
        
        % Make the textures for dynamic noise
        schedule = zeros(1,nSteps);
        if presence(iTrial) == 1
        schedule(onset_frame:offset_frame) = vis_scale(visibility);
        end

           target = {};

            for i_frame = 1:nSteps
                idx = ((i_frame-1)*nStepSize)+1 : (i_frame*nStepSize);

                    tmp = Screen('MakeTexture', w, ...
                        make_stimulus_differentNoises( ...
                            orientations(iOri), schedule(i_frame), ...
                           schedules{1}{1, i_frame}));
            
                for i = 1:length(idx)
                    target{idx(i)} = tmp;
                end
            end
        
        % Present dynamic noise
             % Present stimulus
                    playing1 = false; playing2 = false; playing3 = false;

        for i_frame = 1:nSteps
            if i_frame >= TP0_frame && i_frame < TP1_frame
                if ~playing1
                    PsychPortAudio('FillBuffer', pahandle, wavedata0);
                    PsychPortAudio('Start', pahandle, 1, 0, 0);
                    playing1 = true; playing2 = false; playing3 = false;
                end
            elseif i_frame >= TP2_frame && i_frame < TP3_frame
                if ~playing2
                    PsychPortAudio('FillBuffer', pahandle, wavedata0);
                    PsychPortAudio('Start', pahandle, 1, 0, 0);
                    playing2 = true; playing1 = false; playing3 = false;
                end
            elseif i_frame >= onset_frame && i_frame <= offset_frame
                if ~playing3
                    PsychPortAudio('FillBuffer', pahandle, wavedata2);
                    PsychPortAudio('Start', pahandle, 1, 0, 0);
                    playing3 = true; playing1 = false; playing2 = false;
                end
            else
                PsychPortAudio('Stop', pahandle);
                playing1 = false; playing2 = false; playing3 = false;
            end
            if ~isempty(target{i_frame})
                Screen('DrawTexture', w, target{i_frame});
            end
            
            fix_color = [0,0,0];
            Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], 4, fix_color, [rect(3)/2, rect(4)/2], 1);
            Screen('Flip', w);
        end % end frame loop
        
        % Vividness rating
        text = 'Please reproduce how vividly you saw the grating? \n'; 

                RM = RM_list(iTrial);
                if RM == 1
                text1 = 'Less Vivid [d]';
                text2 = 'More Vivid [f]';
                else
                text1= 'More Vivid [d]';
                text2= 'Less Vivid [f]';
                end
                [~, ~] = sliderRating_forNIMADET(w, text, xCenter*2, yCenter*2,RM,90,rect,V,text1,text2 );
        
    end
end
save(fullfile(output,saveName)); % save everything

Screen('TextSize',w, 28);
DrawFormattedText(w, 'This is the end of the perception practice!', 'center', 'center', [255 255 255]);
Screen('Flip', w);
WaitSecs(2);
Screen('CloseAll')
sca;