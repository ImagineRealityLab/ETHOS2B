%% practice the main task
% contains all components and set at a relatively high visibility level,
% determined by the detection practice to lead to > 0.7 accuracy

function [R,C,BEH_DATA] = MainTask_behavioural(subID,orientations,V, ...
    blocks, trials, startBlock, startTrial, ...
    ITIs, responseMappings,vividnessMappings, deviceToUse,volume)
% =========================================================================
% Setup
% =========================================================================
[w, rect] = setWindow(0);

soundDir = strcat(cd, '\SoundFiles');
sound0Dir = strcat(soundDir, '\VeryLowPitch250_48000.wav');
sound1Dir = strcat(soundDir,'\LowPitch500_48000.wav');
sound2Dir = strcat(soundDir,'\MidPitch750_48000.wav');
sound3Dir = strcat(soundDir, '\HighPitch1000_48000.wav');

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

BEH_data_saveName = sprintf('BEHP_%s.mat',subID);

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

yesKey        = {'j','k'};
noKey         = {'k','j'};
attentionCheckKeys = {'h','j','k'};

nOri = length(orientations);

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

fixTime = 0.2;


%% Instructon screen
[~, yCenter] = RectCenter(rect);
[x_pix, ~] = Screen('WindowSize', w);
HideCursor;

% show instructions 2.
if startBlock == 1
text = ['This is the main experiment! Your task will be identical with the practice you have just done. \n',...
    'This part of the experiment consists of 12 blocks, and you will be informed which block you about \n', ...
    'to perform at the beginning of the each block. \n', ...
    'Before you start, if you may have any questions or any needs, please inform the experimenter. \n \n'];


text = [text '[Press any key to continue] \n '];

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

% grating info
% show gratings
[xCenter, yCenter] = RectCenter(rect);
Xpos     = [x_pix*(1/3) x_pix*(2/3)];
baseRect = [0 0 size(gaborPatch{1},1) size(gaborPatch{1},1)];
allRects = nan(4, 3);
for i = 1:2
    allRects(:, i) = CenterRectOnPointd(baseRect, Xpos(i), yCenter*1.4);
end

%% Trials start

total_trial_counter = (startBlock-1) * trialsPerBlock;

BEH_DATA = struct();
BEH_DATA.subject = subID;
BEH_DATA.blocks  = struct();

imageryText = {
    'During this block you will detect grating %s WITHOUT imagining it.\nPlease do NOT imagine the grating during this block. \n Please keep your eyes on the cross as much as possible. \n\n', ...
    ['During this block, you will IMAGINE grating %s and detect grating %s (see below).\n' ...
     'Please IMAGINE grating %s as vividly as possible during each trial,\n' ...
     'as if it was actually presented.\n Please keep your eyes on the cross as much as possible. \n' ...
     'Remember to always IMAGINE the grating on the last beep!\n\n']
};

respText = {
    'Please press [j] when you see a grating, and [k] when you do not.', ...
    'Please press [j] when you do not see a grating, and [k] when you do.'
};

vivText = {
    'Left side of the slider will be low vividness, and right side will be high vividness.', ...
    'Left side of the slider will be high vividness, and right side will be low vividness.'
};

proceedText = '\n\n [Press any key to continue]';


for iBlock = startBlock:nBlocks
    
    WaitSecs(fixTime);
  
   blockType = blocks(iBlock,2);
    shown     = blocks(iBlock,1);
    
    if blockType == 2
        imagined = 3 - shown;   % swap A<->B
    else
        imagined = shown;
    end
  
   % instruction screen with gratings
    text = sprintf('This is block %d out of %d.\n\n', iBlock, nBlocks);

    if blockType == 0
        text = [text sprintf(imageryText{1}, cues{shown})];
    else
        text = [text sprintf(imageryText{2}, ...
            cues{imagined}, cues{shown}, cues{imagined})];
    end

    RM = responseMappings(iBlock);
    VM = vividnessMappings(iBlock);
    
    text = [text sprintf('%s\n%s', respText{RM}, vivText{VM}, proceedText)];

    Screen('DrawTextures', w, gaborTexture{1}, [], allRects(:,1), [],[], 0.5);
    DrawFormattedText(w, 'Grating A', xCenter*(1.8/3), yCenter*1.2, [255 255 255]);
    
    Screen('DrawTextures', w, gaborTexture{2}, [], allRects(:,2), [],[], 0.5);
    DrawFormattedText(w, 'Grating B', xCenter*(3.8/3), yCenter*1.2, [255 255 255]);
    
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter*0.6, [255 255 255]);
   

    Screen('Flip', w);
    WaitSecs(1);
    KbWait;

    condition = blocks(iBlock,2);
    shown_grating = blocks(iBlock,1);
        % =========================================================================
        % Presentation
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
    
    BEH_DATA.blocks(iBlock).condition        = blocks(iBlock,2);
    BEH_DATA.blocks(iBlock).shown_grating    = blocks(iBlock,1);
    BEH_DATA.blocks(iBlock).responseMapping  = RM;
    BEH_DATA.blocks(iBlock).vividnessMapping = VM;
    BEH_DATA.startBlock = startBlock;

    if iBlock == startBlock
        TrialLoopStart = startTrial;
    else
        TrialLoopStart = 1;
    end

    % loop over miniblocks
    for iTrial = TrialLoopStart:trialsPerBlock
            
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
            
        % update miniblock counter
        

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
            
           schedule_id = trials(iBlock,iTrial,2);


            for i_frame = 1:nSteps
                idx = ((i_frame-1)*nStepSize)+1 : (i_frame*nStepSize);
            
                    tmp = Screen('MakeTexture', w, ...
                        make_stimulus_differentNoises( ...
                            orientations(blocks(iBlock,1)), schedule(i_frame), ...
                            schedules{schedule_id}{1, i_frame}));

                for i = 1:length(idx)
                    target{idx(i)} = tmp;
                end

            end
            
        playing1 = false; playing2 = false; playing3 = false;

        for i_frame = 1:nSteps
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
            
            fix_color = [0,0,0];
            Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], 4, fix_color, [rect(3)/2, rect(4)/2], 1);
            Screen('Flip', w);
        end % end frame loop
            
                
                % Detection first
                text = 'Was there a grating on the screen? \n';
                if RM == 1 % right hand
                    text = [text 'Yes [j] or no [k]'];
                else
                    text = [text 'No [j] or yes [k]'];
                end
                Screen('TextSize',w, 28);
                DrawFormattedText(w, text, 'center', 'center', 255);
                vbl = Screen('Flip', w);

                % Log response
                keyPressed = 0; % clear previous response
                while ~keyPressed
                    
                    [~, keyTime, keyCode] = KbCheck(-3);
                    key = KbName(keyCode);
                    
                    if ~iscell(key) % only start a keypress if there is only one key being pressed
                        if any(strcmp(key, {yesKey{RM},noKey{RM}}))
                            
                            % fill in B
                            R(iBlock,iTrial,detResponse) = strcmp(key,yesKey{RM}); % 1 yes 0 no
                            R(iBlock,iTrial,detRT) = keyTime-vbl;
                            
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
            
                
                % Vividness rating
                              
                if blocks(iBlock,2) == 0
                text = 'Please reproduce how vividly you SAW the grating? \n';
                else
                text = 'Please reproduce how vividly you IMAGINED the grating? \n';    
                end
              
                if VM == 2
                    text1 = 'More Vivid [d]';
                    text2 = 'Less Vivid [f]';
                else
                    text1 = 'Less Vivid [d]';
                    text2 = 'More Vivid [f]';
                end                
                [rating, rt] = sliderRating_forNIMADET(w, text, xCenter*2, yCenter*2,VM,90,rect,visibility,text1,text2 ); 
                
                R(iBlock, iTrial, vivRating) = rating;
                R(iBlock, iTrial, vivRT) = rt;

                trialData.detectionResponse = R(iBlock,iTrial,detResponse);
                trialData.detectionRT       = R(iBlock,iTrial,detRT);
                trialData.vividnessRating   = R(iBlock,iTrial,vivRating);
                trialData.vividnessRT       = R(iBlock,iTrial,vivRT);
                
                BEH_DATA.blocks(iBlock).trials(iTrial) = trialData;
     end

    
    
        % Imagery check
    text = 'CHECK! Did you imagine the gratings this block, if so which one did you imagine? \n';

    text = [text 'I did not imagine [h] imagined Grating A [j] imagined Grating B [k]'];
        
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter, [255 255 255]);
    Screen('Flip', w);

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

    save(fullfile(output, sprintf('BEHP_%s_block%d.mat', subID, iBlock)), 'R', 'C', 'BEH_DATA', '-v7.3')
end

vividness = [];
text = ['How easy did you find to imagine the gratings throughout the experiment? \n (Very Easy [1] - Very Difficult [5] \n\n' ...
                '1 [A], 2 [S], 3 [D], 4 [F], 5[G]'];
        
        DrawFormattedText(w, text, 'center', 'center', [255 255 255]);
        Screen('Flip', w);
        
        Response = false;
        
        validKeys = [KbName('a'), KbName('s'), KbName('d'), KbName('f'), KbName ('g')];
        vividnessValues = [1, 2, 3, 4, 5];   % map A,S,D,F to 1–4
        
        while ~Response
            [keyIsDown, ~, keyCode] = KbCheck;
        
            if keyIsDown
                key = find(keyCode, 1);  % get key index
        
                % Check if this key is one of (A,S,D,F)
                idx = find(validKeys == key);
        
                if ~isempty(idx)
                    vivid = vividnessValues(idx);  % convert to 1–4
                    vividness = [vividness vivid]; % store response
                    Response = true;
                end
        
                % Prevent multiple detections while key held down
                KbReleaseWait;
            end
        end

save(fullfile(output,saveName)); % save everything
save(fullfile(output, BEH_data_saveName), 'R', 'C', 'BEH_DATA', '-v7.3');


Screen('TextSize',w, 28);
DrawFormattedText(w, 'This is the end of the experiment!', 'center', 'center', [255 255 255]);
Screen('Flip', w);
WaitSecs(2);
Screen('CloseAll')
sca;
