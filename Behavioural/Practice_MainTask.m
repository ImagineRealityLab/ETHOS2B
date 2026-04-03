function [R,C] = Practice_MainTask(subID,orientations,V, volume, deviceToUse)

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

load('noiseSchedules.mat')
schedules = {schedule1, schedule2, schedule3, schedule4};

% output
output = fullfile(cd,'results',subID);
if ~exist(output,'dir'); mkdir(output); end
saveName = sprintf('PMTPractice_%s.mat',subID);

% Trial numbers and order
nOri    = length(orientations);
% nMB     = 2; % mini-blocks

nBlocks = 4; % must be at least 3 to illustrate all possibilities!
trialsPerBlock = 8;
NoiseLevelsTrial = [1 2 3 4];
trials = zeros(nBlocks, trialsPerBlock,2); 
for iBlock = 1:nBlocks
    blockTrials = [ones(1,trialsPerBlock/2), zeros(1,trialsPerBlock/2)];
    blockNoises = repmat(NoiseLevelsTrial,1,trialsPerBlock/4);
    TrialAndNoise = [blockTrials',blockNoises'];
    nRows = size(TrialAndNoise,1);
    shuffledIdx = randperm(nRows);
    TrialAndNoiseShuffled = TrialAndNoise(shuffledIdx, :);
    trials(iBlock, :,1) = TrialAndNoiseShuffled(:,1);
    trials(iBlock, :,2) = TrialAndNoiseShuffled(:,2);
end

imaOri = [ones(1,nBlocks/4), ones(1,nBlocks/4)+1];
imaOri = [imaOri, imaOri];
blocks = imaOri';

ImaginedVOnlyPerception = [zeros(1,nBlocks/2),ones(1,nBlocks/2)];

blocks(:,2)= ImaginedVOnlyPerception';

blocks = blocks(randperm(size(blocks,1)),:);


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
responseMappings = repmat(1:2,1,nBlocks/2);
responseMappings = responseMappings(randperm(nBlocks));
vividnessMappings = repmat(1:2,1,nBlocks/2);
vividnessMappings = vividnessMappings(randperm(nBlocks));

yesKey        = {'j','k'};
noKey         = {'k','j'};
attentionCheckKeys = {'h','j','k'};

% timing
mITI    = 1; % mean ITI - randomly sample from norm
sITI    = 0.5; % SD for sampling
ITIs    = normrnd(mITI,sITI,nBlocks*trialsPerBlock,trialsPerBlock);
fixTime = 0.2;

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


cues = {'A','B'};

%% Instructon screen
[~, yCenter] = RectCenter(rect);
[x_pix, ~] = Screen('WindowSize', w);
HideCursor;
% show instructions 1.
text = ['This is the main practice section. \n' ...
    'This section is identical to the main experiment in terms of its procedure. \n' ...
    'Now, we will combine all practiced elements together. \n ',...
    'In one third of the blocks, you will detect a grating WITHOUT imagining it. \n' ...
    'In these blocks, you will use the slider to indicate how vivid the gratings you saw were.']

text = [text '\n \n ',...
    '[Press any key to continue] \n '];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);

Screen('Flip', w);
WaitSecs(1);
KbWait;

text =   ['In the other blocks, you will also imagine a grating and in these blocks, \n ' ...
    'you will use the sliders to indicate how vivid your imagery of the grating was. \n',...
    'The grating you will imagine will always be the same as the one you will imagine, \n ' ...
    'You will be informed which grating you should imagine and detect at the beginning of each block.'];

text = [text '\n \n ',...
    '[Press any key to continue] \n '];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);

Screen('Flip', w);
WaitSecs(1);
KbWait;


text = [text 'Remember that you should imagine the grating exactly on the third beep sound. \n' ...
    'After each trial, you will first indicate whether the to-be-detected grating was presented' ...
       '\n and then how vivid your imagery/perception was.'];



% show instructions 2.

text = ['Remember, the pitch of the first tone you hear on each trial indicates whether you should imagine the gratings or not \n'...,
    '(High pitch - Imagine, Low pitch - Do not imagine) \n\n' ...,
    'If you should imagine the grating on that trial; the second tone indicates which grating you should imagine: \n' ...,
    '(High pitch - Grating A, Low pitch - Grating B) \n\n'...,
    'At the beginning of each block you will also be informed whether you should imagine the gratings, and if so, which one you should imagine. \n'];

text = [text '[Press any key to continue] \n '];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);

Screen('Flip', w);
WaitSecs(1);
KbWait;

% show instructions 3.
text = 'The finger you use to respond yes/no to the presence question will change in each block. \n\n';

text = [text '[Press any key to continue] \n '];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);

Screen('Flip', w);
WaitSecs(1);
KbWait;

% grating info
% show gratings
[xCenter, yCenter] = RectCenter(rect);
Xpos     = [x_pix*(1/3) x_pix*(2/3)];
baseRect = [0 0 size(gaborPatch{1},1) size(gaborPatch{1},1)];
allRects = nan(4, 3);
for i = 1:2
    allRects(:, i) = CenterRectOnPointd(baseRect, Xpos(i), yCenter*1.4);
end
centerRect = CenterRectOnPointd(baseRect, xCenter, yCenter*1.4);
centerRect1 = CenterRectOnPointd(baseRect, xCenter*0.8, yCenter*1.4);
centerRect2 = CenterRectOnPointd(baseRect, xCenter*1.2, yCenter*1.4);

%% Trials start

total_trial_counter = 1;

for iBlock = 1:nBlocks
    
    WaitSecs(fixTime);
  
   % instruction screen with gratings
    text = sprintf('This is block %d out of %d. \n \n',iBlock,nBlocks);
    if blocks(iBlock,2) == 1 %if it is an congruent imagination block
    text = [text sprintf('During this block, you will IMAGINE grating %s and detect grating %s (see below). \n',cues{blocks(iBlock,1)}, cues{blocks(iBlock,1)})];
    text = [text sprintf('Please IMAGINE grating %s as vividly as possible during each trial, \n as if it was actually presented. \n',cues{blocks(iBlock,1)}) ];
    text = [text, 'Remember to always IMAGINE the grating on the last beep! \n \n'];
    elseif blocks(iBlock,2) == 2 %if it is an incongruent imagination block
        if blocks(iBlock,1)==1
            toImagine =2;
        else
            toImagine =1;
        end
    text = [text sprintf('During this block, you will IMAGINE grating %s and detect grating %s (see below). \n',cues{toImagine}, cues{blocks(iBlock,1)})];
    text = [text sprintf('Please IMAGINE grating %s as vividly as possible during each trial, \n as if it was actually presented. \n \n',cues{toImagine}) ];
    text = [text, 'Remember to always IMAGINE the grating on the last beep! \n \n'];
    else
    text = [text sprintf('During this block you will detect grating %s WITHOUT imagining it. \n \n', cues{blocks(iBlock,1)})];
    text = [text 'Please do NOT imagine the grating during this block. \n \n'];
    end
    if responseMappings(iBlock) == 1 && vividnessMappings (iBlock) == 1
        text = [text 'Please press [j] when you see a grating, and [k] when you do not. \n Left side of the slider will be low vividness, and right side of the slider will be high vividness.'];
        RM = 1;
        VM = 1;
        
    elseif responseMappings(iBlock) == 2 && vividnessMappings (iBlock) == 1
        text = [text 'Please press [k] when you see a grating, and [j] when you do not. \n Left side of the slider will be low vividness, and right side of the slider will be high vividness.'];
        RM = 2;
        VM = 1;
    elseif responseMappings(iBlock) == 1 && vividnessMappings (iBlock) == 2
        text = [text 'Please press [j] when you see a grating, and [k] when you do not. \n Left side of the slider will be high vividness, and right side of the slider will be low vividness.'];
        RM = 1;
        VM = 2;
    elseif responseMappings(iBlock) == 2 && vividnessMappings (iBlock) == 2
        text = [text 'Please press [k] when you see a grating, and [j] when you do not. \n Left side of the slider will be high vividness, and right side of the slider will be low vividness.'];
        RM = 2; 
        VM = 2;

    end
    text = [text '\n \n [Press any key to start] \n '];
    
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter*0.6, [255 255 255]);
    
    
    
    
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

    % loop over miniblocks
    for iTrial = 1:trialsPerBlock
            
            % Inter trial interval
            Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
                4, [255,255,255], [rect(3)/2, rect(4)/2], 1);
            Screen('Flip', w);
            WaitSecs(ITIs(total_trial_counter,iTrial));

            %Fixation 
                        Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
                4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
            Screen('Flip', w);
            WaitSecs(0.2);
                
            % update miniblock counter
            total_trial_counter = total_trial_counter+1;

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
     end

    
    % Imagery check
    text = 'CHECK! Did you imagine the gratings this block, if so which one did you imagine? \n \n';

    text = [text '[I did not imagine [h] imagined Grating A [j] imagined Grating B [k]]'];

    Screen('DrawTextures', w, gaborTexture{1}, [], allRects(:,1), [],[], 0.5);
    DrawFormattedText(w, 'Grating A', xCenter*(1.8/3), yCenter*1.2, [255 255 255]);
    
    Screen('DrawTextures', w, gaborTexture{2}, [], allRects(:,2), [],[], 0.5);
    DrawFormattedText(w, 'Grating B', xCenter*(3.8/3), yCenter*1.2, [255 255 255]);
        
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
end

save(fullfile(output,saveName)); % save everything

Screen('TextSize',w, 28);
DrawFormattedText(w, 'This is the end of practice!', 'center', 'center', [255 255 255]);
Screen('Flip', w);
WaitSecs(2);
Screen('CloseAll')
sca;
