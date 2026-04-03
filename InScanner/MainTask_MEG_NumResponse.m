%% practice the main task
% contains all components and set at a relatively high visibility level,
% determined by the detection practice to lead to > 0.7 accuracy

function [R,C,data_localizer,MEG_DATA] = MainTask_MEG_NumResponse(subID,orientations,V,useTrigger, localizer_orientations, localizer_per_block, blocks, trials, startBlock,startTrial, ITIs, responseMappings,vividnessMappings,deviceToUse,volume)

% =========================================================================
% Setup
% =========================================================================
[w, rect] = setWindow(0);

warning('off','all');



%% Get sounds
soundDir = strcat(cd, '\SoundFiles');
sound0Dir = strcat(soundDir, '\VeryLowPitch250_48000.wav');
sound1Dir = strcat(soundDir,'\LowPitch500_48000.wav');
sound2Dir = strcat(soundDir,'\MidPitch750_48000.wav');
sound3Dir = strcat(soundDir, '\HighPitch1000_48000.wav');
KbName('UnifyKeyNames')

[y0, ~] = psychwavread(sound0Dir);

[y1, freq1] = psychwavread(sound1Dir);


[y2, ~] = psychwavread(sound2Dir);


[y3, ~] = psychwavread(sound3Dir);

if size(y1,2) == 1
    y1 = [y1 y1]; % ensure stereo
    y2 = [y2,y2];
    y3 = [y3,y3];
    y0 = [y0,y0];
end
wavedata1 = y1';
wavedata2 = y2';
wavedata3 = y3';
wavedata0 = y0';
% sound1 = wavedata0;

InitializePsychSound;

pahandle = PsychPortAudio('Open', deviceToUse, [], 1, freq1, 2);

PsychPortAudio('Volume', pahandle, volume);

HideCursor;

%% Get noise patterns
schedules = struct2cell(load('noiseSchedules.mat'));
schedules = schedules(2:5);


output = fullfile(cd,'results',subID);
if ~exist(output,'dir'); mkdir(output); end
saveName = sprintf('PMT_%s.mat',subID);

MEG_data_saveName = sprintf('MEGP_%s.mat',subID);

localizer_data_saveName = sprintf('Localizer_%s.mat',subID);

%% Trial and block matrices
% Trial numbers and order

nBlocks = size(blocks,1);
trialsPerBlock = size(trials,2);

R       = nan(nBlocks,trialsPerBlock,4);
C       = nan(nBlocks,1); % ima check

% Visibility settings
vis_scale = [0 logspace(log10(0.005),log10(0.2),299)]; % steps in log space
visibility = V;

% responses
vivRating     = 1;
vivRT         = 2;
detResponse   = 3;
detRT         = 4;
fixTime = 0.2;

yesKey        = {'7&','9('};
noKey         = {'9(','7&'};
attentionCheckKeys = {'2@','3#','4$'};

nOri    = length(orientations);

% =========================================================================
%% Stimuli
% =========================================================================

% Makes the gabors to show for instruction
gaborPatch   = cell(nOri,1);
gaborTexture = cell(nOri,1);
for iOri = 1:nOri
    % stimulus
    gaborPatch{iOri} = make_stimulus(orientations(iOri),1,1); % full visibility, full contrast
    % texture
    gaborTexture{iOri} = Screen('MakeTexture',w,gaborPatch{iOri});
end

% Noise stimulus info

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

cues = {'A','B'};

[~, ~] = RectCenter(rect);
[x_pix, y_pix] = Screen('WindowSize', w);

% Square for photodiode
baseRect = [0 0 60 60];
diodeRect = CenterRectOnPoint(baseRect, 10, y_pix);


% Trigger numbers
if useTrigger

    noiseOnset_trigger = 1;          
    gratingOnset_trigger = 2;           
    responseOnset_trigger = 3;   
    responseOffset_trigger = 4;
    reproductionOnset_trigger = 5;
    reproductionOffset_trigger = 6;
    localizerStimOnset_trigger = 7;
    
    trigger_object = io64; 
    % Trigger properties
    status = io64(trigger_object);                                  % check status of parallel port
    assert(status==0, 'Parallel port not opened.');
                                     % check status of parallel port                                  % check status of parallel port
    trigger_scanport = hex2dec('3FF8');
    io64(trigger_object, trigger_scanport, 0);  
    

end



% grating info
% show gratings
[xCenter, yCenter] = RectCenter(rect);
Xpos     = [x_pix*(1/3) x_pix*(2/3)];
baseRect = [0 0 size(gaborPatch{1},1) size(gaborPatch{1},1)];
allRects = nan(4, 3);
for i = 1:2
    allRects(:, i) = CenterRectOnPointd(baseRect, Xpos(i), yCenter*1.4);
end

%% Localizer setup

first_localizer = 1;
turning_point = 0.02;
detectFrames = round(turning_point / frame_duration);
trial_per_run = length(localizer_orientations)*10;
nRuns = floor(nBlocks / localizer_per_block);
repeatProb = 0.1;
ITIs_localizer = 0.8 + 0.4 * rand(nRuns * trial_per_run, 1);

localizer_stimuli_duration = 0.2;
localizer_nSteps = round((localizer_stimuli_duration/ifi)/nStepSize);
nObserve = length(localizer_orientations)*2;

trial_counter = 1;

data_localizer = struct();

KbName('UnifyKeyNames');
confirmKey = '3#';
confirmKeyCode = KbName('3#');

%% Instructon screen

HideCursor;

% show instructions 2.
if startBlock == 1
text = ['Welcome! This is just a reminder of the main task you practiced before coming into the scanner. \n'...,
    'Throughout the experiment, you will be detecting two gratings (shown below). \n'...,
    'You will also hear three beep sounds in each trial. The grating is always shown on the last beep. \n \n'];

text = [text '[Press any key to continue] \n '];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.6, [255 255 255]);

Screen('DrawTextures', w, gaborTexture{1}, [], allRects(:,1), [],[], 0.5);
DrawFormattedText(w, 'Grating A', xCenter*(1.8/3), yCenter*1.2, [255 255 255]);

Screen('DrawTextures', w, gaborTexture{2}, [], allRects(:,2), [],[], 0.5);
DrawFormattedText(w, 'Grating B', xCenter*(3.8/3), yCenter*1.2, [255 255 255]);

Screen('Flip', w);
WaitSecs(1);
KbWait;

text = ['In some blocks, you will also need to imagine a grating, which will always be the same as \n'...,
    'the one you will detect. Please try to imagine the grating exactly when you hear the third beep. \n'...,
    'Whether you will imagine a grating in a block, and which one you should imagine if you need to imagine any \n'...,
    'will be shown to you at the beginning of each block. \n\n [Press any key to continue]'];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);
Screen('Flip', w);
WaitSecs(1);
KbWait;

text = ['Also, the pitch of the tones that you will hear informs you what you should do. \n'...,
    'If the first tone is a HIGH pitch one, you SHOULD imagine a grating, if it is a LOW pitch one you should NOT imagine any gratings. \n\n'...,
    'If you should imagine a grating, the second tone indicates which one you should imagine. \n'...,
    'If the second tone is a HIGH pitch one, you should imagine Grating A, if it is a low pitch one you should imagine Grating B (see below).\n\n' ...
    '[Press any key to continue]'];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);

Screen('DrawTextures', w, gaborTexture{1}, [], allRects(:,1), [],[], 0.5);
DrawFormattedText(w, 'Grating A', xCenter*(1.8/3), yCenter*1.2, [255 255 255]);

Screen('DrawTextures', w, gaborTexture{2}, [], allRects(:,2), [],[], 0.5);
DrawFormattedText(w, 'Grating B', xCenter*(3.8/3), yCenter*1.2, [255 255 255]);

Screen('Flip', w);
WaitSecs(1);
KbWait;

text = ['Please let the experimenter know if you may have any questions at this point. This phase consists of 16 blocks \n'...,
    'and approximately takes 45 minutes. In every 2 blocks, we will have a short break. \n \n'...,
    '[Press any key to continue]'];

Screen('FillRect', w, 0, diodeRect);   % photodiode ON
Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);
Screen('Flip', w);
WaitSecs(1);
KbWait;

else

Screen('TextSize',w, 28);
DrawFormattedText(w, ...
    sprintf('Resuming from block %d.\n\nPlease remain still as much as possible.\n\n[Press any key]', startBlock), ...
    'center','center',255);
WaitSecs(1);
Screen('Flip', w);
Screen('FillRect', w, 0, diodeRect);   % photodiode ON
KbWait;

end %if startblock==1

%% Trials start

total_trial_counter = (startBlock-1) * trialsPerBlock;

MEG_DATA = struct();
MEG_DATA.subject = subID;
MEG_DATA.blocks  = struct();

imageryText = {
    'During this block you will detect grating %s WITHOUT imagining it.\nPlease do NOT imagine the grating during this block. \n Please keep your eyes on the cross as much as possible. \n\n', ...
    ['During this block, you will IMAGINE grating %s and detect grating %s (see below).\n' ...
     'Please IMAGINE grating %s as vividly as possible during each trial,\n' ...
     'as if it was actually presented.\n Please keep your eyes on the cross as much as possible. \n' ...
     'Remember to always IMAGINE the grating on the last beep!\n\n']
};

respText = {
    'Please press [LR] when you see a grating, and [LI] when you do not.', ...
    'Please press [LI] when you see a grating, and [LR] when you do not.'
};

vivText = {
    'Left side of the slider will be low vividness, and right side will be high vividness.', ...
    'Left side of the slider will be high vividness, and right side will be low vividness.'
};

reminderText = '\n Please try to blink only when the slider screen is displayed. \n\n [Press any key to start the block] \n';


for iBlock = startBlock:nBlocks
    
    if iBlock == startBlock
        respWindow = 10;
    else
        respWindow = 3;
    end

    if rem(iBlock,2) == 0
        iRun = iBlock/2;
    else
        iRun = (iBlock+1)/2;
    end


    WaitSecs(fixTime);

    blockType = blocks(iBlock,2);
    shown     = blocks(iBlock,1);
    nCorrect = 0;
    
    if blockType == 2
        imagined = 3 - shown;   % swap A<->B
    else
        imagined = shown;
    end
  
   % instruction screen with gratings
    text = sprintf('This is block %d out of %d. Please try to keep still as much as possible!\n\n', iBlock, nBlocks);

    if blockType == 0
        text = [text sprintf(imageryText{1}, cues{shown})];
    else
        text = [text sprintf(imageryText{2}, ...
            cues{imagined}, cues{shown}, cues{imagined})];
    end

    RM = responseMappings(iBlock);
    VM = vividnessMappings(iBlock);
    
    text = [text sprintf('%s\n%s', respText{RM}, vivText{VM}, reminderText)];
    
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter*0.4, [255 255 255]);
    
    Screen('DrawTextures', w, gaborTexture{1}, [], allRects(:,1), [],[], 0.5);
    DrawFormattedText(w, 'Grating A', xCenter*(1.8/3), yCenter*1.2, [255 255 255]);
    
    Screen('DrawTextures', w, gaborTexture{2}, [], allRects(:,2), [],[], 0.5);
    DrawFormattedText(w, 'Grating B', xCenter*(3.8/3), yCenter*1.2, [255 255 255]);

    Screen('Flip', w);
    WaitSecs(1);
    KbWait;

    condition = blocks(iBlock,2);
    shown_grating = blocks(iBlock,1);
        % =========================================================================
        %% Presentation
        % =========================================================================
    if condition == 0
        sound1 = wavedata0;
        sound2 = wavedata0;
        sound3 = wavedata2;
        imagined = 0;
    elseif condition == 1 && shown_grating == 1
        sound1 = wavedata2;
        sound2 = wavedata3;
        sound3 = wavedata2;
        imagined = 1;
    elseif condition == 1 && shown_grating == 2
        sound1 = wavedata2;
        sound2 = wavedata1;
        sound3 = wavedata2;
        imagined = 2;
    elseif condition == 2 && shown_grating == 1
        sound1 = wavedata2;
        sound2 = wavedata1;
        sound3 = wavedata2;
        imagined = 2;
    elseif condition == 2 && shown_grating == 2
        sound1 = wavedata2;
        sound2 = wavedata1;
        sound3 = wavedata2;
        imagined = 1;
    end

    MEG_DATA.blocks(iBlock).condition        = blocks(iBlock,2);
    MEG_DATA.blocks(iBlock).shown_grating    = blocks(iBlock,1);
    MEG_DATA.blocks(iBlock).responseMapping  = RM;
    MEG_DATA.blocks(iBlock).vividnessMapping = VM;
    MEG_DATA.startBlock = startBlock;
    
    if iBlock == startBlock
        TrialLoopStart = startTrial;
    else
        TrialLoopStart = 1;
    end

    % loop over miniblocks
    for iTrial = TrialLoopStart:trialsPerBlock
            
            trialData = struct();

            trialData.trialIndex   = iTrial;
            trialData.presentTrial = trials(iBlock,iTrial,1);   % 1 = grating, 0 = noise
            trialData.noiseID      = trials(iBlock,iTrial,2);   % 1–4
            trialData.visibility   = visibility;
            trialData.orientation  = orientations(blocks(iBlock,1));
            

            total_trial_counter = total_trial_counter+1;
            % Inter trial interval
            Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
                4, [255,255,255], [rect(3)/2, rect(4)/2], 1);
            Screen('Flip', w);
            WaitSecs(ITIs(total_trial_counter));

            % Fixation 

            Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
                4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
            Screen('Flip', w);
            WaitSecs(fixTime);

            if trials(iBlock,iTrial,1) == 1 % present trial
                % schedule of visibility gradient (i.e how visible at each frame)
                % Increases till most visible at the end
            schedule = zeros(1, nSteps);
%             schedule(onset_frame:offset_frame) = max(vis_scale(round(linspace(1,visibility,nSteps))));
                schedule(onset_frame:offset_frame) = vis_scale(visibility);
            else % Pure noise trial
                % 0 for entire schedule
                schedule = zeros(1,nSteps);
                
            end
            
            % Make the texture for each frame by combining the gabor with noise.
            % Rotates the annulus mask to hide the rotated boundary box around the
            % grating.
           target = {};
           schedule_no = trials(iBlock,iTrial,2);

            for i_frame = 1:nSteps
                idx = ((i_frame-1)*nStepSize)+1 : (i_frame*nStepSize);
            
                    tmp = Screen('MakeTexture', w, ...
                        make_stimulus_differentNoises( ...
                            orientations(blocks(iBlock,1)), schedule(i_frame), schedules{schedule_no}{1, i_frame}));

                for i = 1:length(idx)
                    target{idx(i)} = tmp;
                end

            end
            
        playing1 = false; playing2 = false; playing3 = false;

        

        for i_frame = 1:nSteps
            thisTrigger = 0;
            if i_frame >= TP0_frame && i_frame < TP1_frame
                if ~playing1
                    PsychPortAudio('FillBuffer', pahandle, sound1);
                    PsychPortAudio('Start', pahandle, 1, 0, 0);
                    playing1 = true; playing2 = false; playing3 = false;
                end
            elseif i_frame >= TP2_frame && i_frame < TP3_frame
                if ~playing2
                    PsychPortAudio('FillBuffer', pahandle, sound2);
                    PsychPortAudio('Start', pahandle, 1, 0, 0);
                    playing2 = true; playing1 = false; playing3 = false;
                end
            elseif i_frame >= onset_frame && i_frame <= offset_frame
                if ~playing3
                    PsychPortAudio('FillBuffer', pahandle, sound3);
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

            if useTrigger
                if i_frame == 1
                    thisTrigger = noiseOnset_trigger;
                elseif i_frame == onset_frame
                    thisTrigger = gratingOnset_trigger;
                end
            end

            if i_frame == 1
                    Screen('FillRect', w, 0, diodeRect);
           elseif i_frame == onset_frame
                    Screen('FillRect', w, 0, diodeRect);
            end
            
            fix_color = [0,0,0];
            Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], 4, fix_color, [rect(3)/2, rect(4)/2], 1);
            Screen('Flip', w);
            
            if useTrigger && thisTrigger ~= 0
                io64(trigger_object, trigger_scanport, thisTrigger);
                WaitSecs(0.002); % Brief pulse duration
                io64(trigger_object, trigger_scanport, 0);
            end
            
        end % end frame loop
            
                
        % Detection first
        text = 'Was there a grating on the screen? \n';
        
        if RM == 1 % right hand
            text = [text 'Yes [LR] or no [LI]'];
        else
            text = [text 'No [LR] or yes [LI]'];
        end
        
        Screen('FillRect', w, [255/2,255/2,255/2]); 
        Screen('FillRect', w, 0, diodeRect);   % photodiode ON
        Screen('Flip', w);
       
        DrawFormattedText(w, text, 'center', 'center', 255);   
        vbl = Screen('Flip', w);

        if useTrigger
            thisTrigger = responseOnset_trigger;
            io64(trigger_object, trigger_scanport, thisTrigger);
            WaitSecs(0.002); % Brief pulse
            io64(trigger_object, trigger_scanport, 0);
        end

        % Log response
        keyPressed = 0; % clear previous response
        while ~keyPressed && (GetSecs - vbl) < respWindow
            
            [~, keyTime, keyCode] = KbCheck(-3);
            key = KbName(keyCode);
            
            if ~iscell(key) % only start a keypress if there is only one key being pressed
                if any(strcmp(key, {yesKey{RM},noKey{RM}}))
                    
                    % fill in B
                    R(iBlock,iTrial,detResponse) = strcmp(key,yesKey{RM}); % 1 yes 0 no
                    R(iBlock,iTrial,detRT) = keyTime-vbl;

                    if strcmp(key,yesKey{RM}) == trials(iBlock,iTrial,1) 
                        nCorrect = nCorrect + 1;
                    end
                    
                    keyPressed = true;
                    
                elseif strcmp(key, 'ESCAPE')
                    Screen('TextSize',w, 28);
                    DrawFormattedText(w, 'Experiment was aborted!', 'center', 'center', [255 255 255]);
                    Screen('Flip',w);
                    WaitSecs(0.5);
                    ShowCursor;
                    disp(' ');
                    disp('Experiment aborted by user!');
                    disp(' ');
                    Screen('CloseAll');
                    save(fullfile(output,saveName)); % save everything
                    return;
                end
            end
        end

        if ~keyPressed
        R(iBlock,iTrial,detResponse) = NaN;
        R(iBlock,iTrial,detRT) = NaN;   % or 0, depending on how you code misses
        Screen('TextSize', w, 28);
        DrawFormattedText(w, 'Too slow!', 'center', 'center', [255 255 255]);
        Screen('Flip', w);
        WaitSecs(1.5);   % brief, non-disruptive feedback
        end
        


        Screen('FillRect', w, [255/2,255/2,255/2]);              % blank or fixation
        Screen('FillRect', w, 0, diodeRect);   % photodiode ON
        
        
        Screen('Flip', w);

        if useTrigger
        thisTrigger = responseOffset_trigger;
        io64(trigger_object, trigger_scanport, thisTrigger);
        WaitSecs(0.002); % Brief pulse
        io64(trigger_object, trigger_scanport, 0);
        end
                
                % Vividness rating
                              
                if blocks(iBlock,2) == 0
                text = 'Please reproduce how vividly you SAW the grating? \n';
                else
                text = 'Please reproduce how vividly you IMAGINED the grating? \n';    
                end
              
                if VM == 2
                    text1 = 'More Vivid [RI]';
                    text2 = 'Less Vivid [RR]';
                else
                    text1 = 'Less Vivid [RI]';
                    text2 = 'More Vivid [RR]';
                end

                Screen('FillRect', w, 0, diodeRect);
                Screen('Flip', w);

                if useTrigger
                    thisTrigger = reproductionOnset_trigger;
                    io64(trigger_object, trigger_scanport, thisTrigger);
                    WaitSecs(0.002); % Brief pulse
                    io64(trigger_object, trigger_scanport, 0);
                end

                [rating, rt] = sliderRating_forNIMADET_MEG(w, text, xCenter*2, yCenter*2,VM,90,rect,visibility,text1,text2); 
                
                Screen('FillRect', w, [255/2,255/2,255/2]);   
                Screen('FillRect', w, 0, diodeRect);
                Screen('Flip', w);

                if useTrigger
                thisTrigger = reproductionOffset_trigger;
                io64(trigger_object, trigger_scanport, thisTrigger);
                WaitSecs(0.002); % Brief pulse
                io64(trigger_object, trigger_scanport, 0);
                end

                R(iBlock, iTrial, vivRating) = rating;
                R(iBlock, iTrial, vivRT) = rt;


                trialData.detectionResponse = R(iBlock,iTrial,detResponse);
                trialData.detectionRT       = R(iBlock,iTrial,detRT);
                trialData.vividnessRating   = R(iBlock,iTrial,vivRating);
                trialData.vividnessRT       = R(iBlock,iTrial,vivRT);
                
                MEG_DATA.blocks(iBlock).trials(iTrial) = trialData;
     end
    
    acc = nCorrect/size(trials,2);
    fprintf('Accuracy for this block: %.3f\n',acc);
    
    % Imagery check
    text = 'CHECK! Did you imagine the gratings this block, if so which one did you imagine? \n';

    text = [text 'I did not imagine [RI] imagined Grating A [RM] imagined Grating B [RR]'];
        
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter, [255 255 255]);
    Screen('Flip', w);
    WaitSecs(2)

    % log response
    keyPressed = 0; % clear previous response
    while ~keyPressed
        
        [~, ~, keyCode] = KbCheck(-3);
        key = KbName(keyCode);
        
        if ~iscell(key) % only start a keypress if there is only one key being pressed
            if any(strcmp(key, attentionCheckKeys))
                
                % fill in response
                checkResponse = find(strcmp(key,attentionCheckKeys)); % 1 to 2
                if checkResponse == imagined + 1 
                    C(iBlock) = 1;
                else
                    C(iBlock) = 0;
                end
                
                keyPressed = true;
                
            elseif strcmp(key, 'ESCAPE')
                Screen('TextSize',w, 28);
                DrawFormattedText(w, 'Experiment was aborted!', 'center', 'center', [255 255 255]);
                Screen('Flip',w);
                WaitSecs(0.5);
                ShowCursor;
                disp(' ');
                disp('Experiment aborted by user!');
                disp(' ');
                Screen('CloseAll');
                save(fullfile(output,saveName)); % save everything
                return;
            end
        end
    end
    
    % Feedback
    WaitSecs(0.2);
    if C(iBlock) == 1
        text = 'Correct! \n \n [Press any key to continue]';
    elseif C(iBlock) == 0
        text = 'That is incorrect, please read the block instructions carefully! \n \n [Press any key to continue]';
    end
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', 'center', 255);
    Screen('Flip', w);
    KbWait;

    if rem(iBlock,localizer_per_block) == 0
       if first_localizer
           text = ['Now, you will do a different task. Please do not imagine gratings in this session.\n' ...
            'In this task, you should watch the gratings carefully.\n' ...
            'Sometimes, the same grating orientation will appear twice in a row.\n' ...
            'When that happens, press [RM] as quickly as possible.\n' ...
            'We will now show you a few examples, please do not give any responses at this phase.\n\n' ...
            '[Press any key to start]'];
        Screen('TextSize',w, 28);
        DrawFormattedText(w, text, 'center', 'center', [255 255 255]);
        Screen('Flip', w);
        WaitSecs(1)
        KbWait;

        nPossibleTransitions = nObserve - 1;
        nRepeatTrials = round(repeatProb * nPossibleTransitions);
        
        repeatTrials = false(1, nObserve);
        if nRepeatTrials > 0
            targetIdx = randperm(nPossibleTransitions, nRepeatTrials) + 1;
            repeatTrials(targetIdx) = true;
        end
        
        ori_observe = zeros(1, nObserve);
        ori_observe(1) = localizer_orientations(randi(numel(localizer_orientations)));
        
        for iTrial = 2:nObserve
            if repeatTrials(iTrial)
                ori_observe(iTrial) = ori_observe(iTrial - 1);
            else
                possibleOris = localizer_orientations(localizer_orientations ~= ori_observe(iTrial - 1));
                ori_observe(iTrial) = possibleOris(randi(numel(possibleOris)));
            end
        end

        for iTrial = 1:nObserve
        
            Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], ...
                4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
            Screen('Flip', w);
            WaitSecs(1);
        
            target = cell(1, localizer_nSteps);
        
            for i_frame = 1:localizer_nSteps
                idx = ((i_frame-1)*nStepSize)+1 : (i_frame*nStepSize);
        
                tmp = Screen('MakeTexture', w, ...
                    make_stimulus(ori_observe(iTrial),1,0.8));
        
                for i = 1:length(idx)
                    target{idx(i)} = tmp;
                end
            end
        
            for i_frame = 1:localizer_nSteps
                if ~isempty(target{i_frame})
                    Screen('DrawTexture', w, target{i_frame});
                end
        
                Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], ...
                    4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
                Screen('Flip', w);
            end
        end
       first_localizer = 0;
       end

text = ['Now, for a couple of trials, you will look for repeated grating orientations.\n' ...
    'Press [RM] whenever the same grating orientation appears twice in a row.\n' ...
    'Please keep your eyes on the fixation cross throughout the session.\n' ...
    'Also, please keep still as much as possible, thank you!\n\n' ...
    '[Press any key to continue]'];

DrawFormattedText(w, text, 'center', 'center', [255 255 255]);
Screen('Flip', w);
WaitSecs(1);
KbWait;

nTrials = trial_per_run;
nPossibleTransitions = nTrials - 1;
nRepeatTrials = round(repeatProb * nPossibleTransitions);

repeatTrials = false(1, nTrials);
targetIdx = randperm(nPossibleTransitions, nRepeatTrials) + 1;
repeatTrials(targetIdx) = true;

oris = zeros(1, nTrials);
oris(1) = localizer_orientations(randi(numel(localizer_orientations)));

for iTrial = 2:nTrials
    if repeatTrials(iTrial)
        oris(iTrial) = oris(iTrial - 1);
    else
        possibleOris = localizer_orientations(localizer_orientations ~= oris(iTrial - 1));
        oris(iTrial) = possibleOris(randi(numel(possibleOris)));
    end
end

noiseOrder = repmat(1:4, 1, trial_per_run/4);
noiseOrder = noiseOrder(randperm(trial_per_run));

data_localizer.noiseOrder{iRun} = noiseOrder;

for iTrial = 1:trial_per_run

    detectedRepeat = 0;
    repeatRT = NaN;
    repeatTrial = repeatTrials(iTrial);
    trialOnset = NaN;

    data_localizer.trial(trial_counter).run         = iRun;
    data_localizer.trial(trial_counter).trial       = iTrial;
    data_localizer.trial(trial_counter).noiseID     = noiseOrder(iTrial);
    data_localizer.trial(trial_counter).orientation = oris(iTrial);

    Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], ...
        4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
    Screen('Flip', w);
    KbReleaseWait;
    WaitSecs(ITIs_localizer(trial_counter));

    target = cell(1, localizer_nSteps);

    for i_frame = 1:localizer_nSteps
        idx = ((i_frame-1)*nStepSize)+1 : (i_frame*nStepSize);

        tmp = Screen('MakeTexture', w, make_stimulus(oris(iTrial),1,0.8));

        for i = 1:length(idx)
            target{idx(i)} = tmp;
        end
    end

    for i_frame = 1:localizer_nSteps

        thisTrigger = 0;

        if ~isempty(target{i_frame})
            Screen('DrawTexture', w, target{i_frame});
        end

        Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], 4, [0,0,0], [rect(3)/2, rect(4)/2], 1);

        if i_frame == 1
            Screen('FillRect', w, 0, diodeRect);
            trialOnset = Screen('Flip', w);

            if useTrigger
                thisTrigger = localizerStimOnset_trigger;
                io64(trigger_object, trigger_scanport, thisTrigger);
                WaitSecs(0.002);
                io64(trigger_object, trigger_scanport, 0);
            end
        else
            Screen('Flip', w);
        end

        if ~detectedRepeat
            [keyIsDown, keyTime, keyCode] = KbCheck;
            if keyIsDown && keyCode(confirmKeyCode)
                detectedRepeat = 1;
                repeatRT = keyTime - trialOnset;
            elseif keyIsDown && keyCode(KbName('ESCAPE'))
                Screen('TextSize',w, 28);
                DrawFormattedText(w, 'Experiment was aborted!', 'center', 'center', [255 255 255]);
                Screen('Flip',w);
                WaitSecs(0.5);
                ShowCursor;
                sca;
                return;
            end
        end
    end

    data_localizer.repeatTrial(trial_counter)    = repeatTrial;
    data_localizer.repeatDetected(trial_counter) = detectedRepeat;
    data_localizer.repeatRT(trial_counter)       = repeatRT;

    trial_counter = trial_counter + 1;
    end
    Screen('TextSize',w, 28);
    text = sprintf('Run %d out of %d has ended! \n\n The experimenter will start the next run in a second!' ,iRun, nRuns);
    DrawFormattedText(w, text, 'center', 'center', [255 255 255]);
    Screen('Flip',w);
    RestrictKeysForKbCheck(32);
    KbWait;
    RestrictKeysForKbCheck([]);
    end
    save(fullfile(output, sprintf('MEGP_%s_block%d.mat', subID, iBlock)), 'R', 'C', 'MEG_DATA', 'data_localizer', '-v7.3')
end

save(fullfile(output,saveName)); % save everything

save(fullfile(output, MEG_data_saveName), 'R', 'C', 'MEG_DATA', '-v7.3');

save(fullfile(output, localizer_data_saveName), 'data_localizer', '-v7.3');


Screen('TextSize',w, 28);
DrawFormattedText(w, 'This is the end of the experiment!', 'center', 'center', [255 255 255]);
Screen('Flip', w);
WaitSecs(2);
Screen('CloseAll')
sca;
