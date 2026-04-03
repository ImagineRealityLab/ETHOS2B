function OrientationDiscriminationTraining(orientations, volume,deviceToUse)

% =========================================================================
% Setup
% =========================================================================
soundDir = strcat(cd, '\SoundFiles');
sound1Dir = strcat(soundDir,'\LowPitch500_48000.wav');
sound2Dir = strcat(soundDir,'\MidPitch750_48000.wav');
sound3Dir = strcat(soundDir, '\HighPitch1000_48000.wav');


[y1, freq1] = psychwavread(sound1Dir);


[y2, ~] = psychwavread(sound2Dir);


[y3, ~] = psychwavread(sound3Dir);

if size(y1,2) == 1
    y1 = [y1 y1]; % ensure stereo
    y2 = [y2,y2];
    y3 = [y3,y3];
end
wavedata1 = y1';
wavedata2 = y2';
wavedata3 = y3';

InitializePsychSound;

pahandle = PsychPortAudio('Open', deviceToUse, [], 1, freq1, 2);
PsychPortAudio('Volume', pahandle, volume);


load('noiseSchedules.mat')
schedules = {schedule1, schedule2, schedule3, schedule4};

[w, rect] = setWindow(0);
HideCursor;





nOri = length(orientations);

gaborPatch   = cell(nOri,1);
gaborTexture = cell(nOri,1);
for iOri = 1:nOri
    % stimulus
    gaborPatch{iOri} = make_stimulus(orientations(iOri),0.3);
    % texture
    gaborTexture{iOri} = Screen('MakeTexture',w,gaborPatch{iOri});
end

full_oris = [orientations, orientations-20, orientations+20];
len_full_oris = length(full_oris);
gaborPatchFullVis   = cell(len_full_oris,1);
gaborTextureFullVis = cell(len_full_oris,1);
for iOri = 1:len_full_oris
    % stimulus
    gaborPatchFullVis{iOri} = make_stimulus(full_oris(iOri),1);
    % texture
    gaborTextureFullVis{iOri} = Screen('MakeTexture',w,gaborPatchFullVis{iOri});
end

gaborPatchNoVis  = cell(nOri,1);
gaborTextureNoVis= cell(nOri,1);
for iOri = 1:nOri
    % stimulus
    gaborPatchNoVis{iOri} = make_stimulus(orientations(iOri),eps);
    % texture
    gaborTextureNoVis{iOri} = Screen('MakeTexture',w,gaborPatchNoVis{iOri});
end


                    % Duration of the stimulus in seconds
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

% show instructions (screen 2)
text = ['Great! Now we will ask you to actually imagine the gratings when you hear the third beep, \n', ...
    'Please imagine the grating associated with the second beep as vividly as possible during the third beep.  \n',...
    'After each trial, another grating will be presented which could be tilted\n ', ...
    'clockwise or counterclockwise with respect to the one you should have imagined \n \n',...
    '[Press any key to continue] \n'];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);

% show gratings
Xpos     = [x_pix*(1/3) x_pix*(2/3)];
baseRect = [0 0 size(gaborPatch{1},1) size(gaborPatch{1},1)];

allRects = nan(4, 3);
for i = 1:2
    allRects(:, i) = CenterRectOnPointd(baseRect, Xpos(i), yCenter*1.4);
end

Screen('DrawTextures', w, gaborTextureFullVis{1}, [], allRects(:,1), [],[], 0.5);
DrawFormattedText(w, 'Grating A', xCenter*(1.80/3), yCenter*1.15, [255 255 255]);

Screen('DrawTextures', w, gaborTextureFullVis{2}, [], allRects(:,2), [],[], 0.5);
DrawFormattedText(w, 'Grating B', xCenter*(3.80/3), yCenter*1.15, [255 255 255]);


Screen('Flip', w);
WaitSecs(1);
KbWait;

text = ['You have to indicate whether the tilt is counter-clockwise (leftward) [j] \n'...
    'or clockwise (rightward) [k] with respect to grating you imagined during that trial. \n',...
    'The gratings you have to imagine in this part are shown below. \n ',...
    'You will practice imagining each orientation until you have 5 correct responses in a row. \n \n ',...
    '[Press any key to continue] \n '];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);

Screen('DrawTextures', w, gaborTextureFullVis{1}, [], allRects(:,1), [],[], 0.5);
DrawFormattedText(w, 'Grating A', xCenter*(1.80/3), yCenter*1.15, [255 255 255]);

Screen('DrawTextures', w, gaborTextureFullVis{2}, [], allRects(:,2), [],[], 0.5);
DrawFormattedText(w, 'Grating B', xCenter*(3.80/3), yCenter*1.15, [255 255 255]);


Screen('Flip', w);
WaitSecs(1);
KbWait;

orientationsNeutral = [orientations, 90];
% Trial number and percentage of catch trials
nOri        = length(orientationsNeutral);
nTrialsC    = 5; % how many correct in a row?
nRemind     = 6; % show gratings every N trials
nTrials     = 50;
offsets     = nan(nOri,nTrials);
tmp         = normrnd(0,10,nTrials*100,1); tmp = tmp(abs(tmp) > 7.5); % otherwise it is too small
offsets(1,:) = tmp(1:nTrials); offsets(2,:) = tmp(end-nTrials+1:end);
cues = {'A','B'};

% keys
ccKey = 'j';
cwKey = 'k';

% responses
R_P = zeros(nOri,nTrials,3);

% timing
probeTime = 0.5;
fixTime   = 0.2;
mITI    = 1; % mean ITI - randomly sample from norm
sITI    = 0.5; % SD for sampling
ITIs    = normrnd(mITI,sITI,nOri,nTrials);

gaborPatch   = cell(nOri,1);
gaborTexture = cell(nOri,1);
for iOri = 1:nOri
    % stimulus
    gaborPatch{iOri} = make_stimulus(orientationsNeutral(iOri),1); % full visibility
    % texture
    gaborTexture{iOri} = Screen('MakeTexture',w,gaborPatch{iOri});
end


%% Trials start
for iOri = 1:2
    
    WaitSecs(fixTime);

    % instruction screen with gratings
    text = sprintf('During the next trials, please imagine Grating %s (see below) \n as vividly as possible, as if it was actually shown in the noise. \n \n Keep your eyes fixated on the fixation cross as much as possible. \n \n [Press any key to continue] \n ',cues{iOri});
    
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);    
    
    if iOri == 1
    Screen('DrawTextures', w, gaborTextureFullVis{1}, [], CenterRectOnPointd(baseRect, xCenter*(1.8/3), yCenter*1.4), [],[], 0.5);
    DrawFormattedText(w, 'Grating A', xCenter*(1.6/3), yCenter*1.2, [255 255 255]);

    Screen('DrawTextures', w, gaborTextureFullVis{5}, [], CenterRectOnPointd(baseRect, xCenter, yCenter*1.4), [],[], 0.5);
    DrawFormattedText(w, 'Clockwise tilted', xCenter*(2.7/3), yCenter*1.2, [255 255 255]);

    Screen('DrawTextures', w, gaborTextureFullVis{3}, [], CenterRectOnPointd(baseRect, xCenter*(4.2/3), yCenter*1.4), [],[], 0.5);
    DrawFormattedText(w, 'Counter-clockwise tilted', xCenter*(3.8/3), yCenter*1.2, [255 255 255]);

    else
    Screen('DrawTextures', w, gaborTextureFullVis{2}, [], CenterRectOnPointd(baseRect, xCenter*(1.8/3), yCenter*1.4), [],[], 0.5);
    DrawFormattedText(w, 'Grating B', xCenter*(1.6/3), yCenter*1.2, [255 255 255]);

    Screen('DrawTextures', w, gaborTextureFullVis{6}, [], CenterRectOnPointd(baseRect, xCenter, yCenter*1.4), [],[], 0.5);
    DrawFormattedText(w, 'Clockwise tilted', xCenter*(2.7/3), yCenter*1.2, [255 255 255]);

    Screen('DrawTextures', w, gaborTextureFullVis{4}, [], CenterRectOnPointd(baseRect, xCenter*(4.2/3), yCenter*1.4), [],[], 0.5);
    DrawFormattedText(w, 'Counter-clockwise tilted', xCenter*(3.8/3), yCenter*1.2, [255 255 255]);
    end
    
    Screen('Flip', w);
    WaitSecs(1);
    KbWait;
    
    count = 0; iTrial = 0;
    while count < nTrialsC && iTrial < nTrials
        iTrial = iTrial + 1;

        % Fixation
        Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
            4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
        Screen('Flip', w);
        WaitSecs(fixTime);
        
        % Make the textures for dynamic noise
        schedule = zeros(1,nSteps);
        target = {};

            for i_frame = 1:nSteps
                idx = ((i_frame-1)*nStepSize)+1 : (i_frame*nStepSize);
            
                    tmp = Screen('MakeTexture', w, ...
                        make_stimulus_differentNoises( ...
                            orientations(iOri), schedule(i_frame), schedules{1}{1, i_frame}));

                for i = 1:length(idx)
                    target{idx(i)} = tmp;
                end
            end
           
        if iOri == 1
            sound1 = wavedata2;
            sound2 = wavedata3;
            sound3 = wavedata2;
        else
            sound1 = wavedata2;
            sound2 = wavedata1;
            sound3 = wavedata2;
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
        
        
        % Present probe
        Screen('DrawTextures', w, gaborTexture{iOri}, [], [], offsets(iOri,iTrial),[], 0.5);
        
        Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
            4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
        
        Screen('Flip', w);
        WaitSecs(probeTime);
        
        % Probe discrimination
        text = 'Counter-clockwise [j] or clockwise [k]?';
        Screen('TextSize',w, 28);
        DrawFormattedText(w, text, 'center', 'center', 255);
        vbl = Screen('Flip', w);
        
        keyPressed = 0; % clear previous response
        while ~keyPressed
            
            [~, keyTime, keyCode] = KbCheck(-3);
            key = KbName(keyCode);
            
            if ~iscell(key) % only start a keypress if there is only one key being pressed
                if any(strcmp(key, {cwKey,ccKey}))
                    
                    % fill in B
                    R_P(iOri,iTrial,1) = find(strcmp(key,{cwKey,ccKey})); % 1 cc 2 cw
                    R_P(iOri,iTrial,2) = keyTime-vbl;
                    
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
                    
                    return;
                end
            end
        end
        
        % Feedback
        if (offsets(iOri,iTrial) > 0) == (R_P(iOri,iTrial,1)==1)
            R_P(iOri,iTrial,3) = 1;
            count = count+1;
            text = sprintf('Correct! %d in a row!',count);
        elseif (offsets(iOri,iTrial) > 0) ~= (R_P(iOri,iTrial,1)==1)
            text = 'Incorrect';
            count = 0;
        end
        Screen('TextSize',w, 28);
        DrawFormattedText(w, text, 'center', 'center', 255);
        Screen('Flip', w);
        WaitSecs(0.5)
        
        % Inter trial interval 
        Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
            4, [255,255,255], [rect(3)/2, rect(4)/2], 1);
        Screen('Flip', w);
        WaitSecs(ITIs(iOri,iTrial));  
        
        % Close all textures to free memory
        tmp = unique(cell2mat(target));
        for i_tex = 1:length(tmp)
            Screen('Close', tmp(i_tex));
        end
        
        % show gratings as a reminder
        if mod(iTrial,nRemind) == 0 && count < nTrialsC
            
            text = sprintf('Just a reminder of what the gratings look like! \n You should imagine Grating %s during this block. \n \n [Press any key to continue] \n ',cues{iOri});
    
            Screen('TextSize',w, 28);
            DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);
            
            if iOri == 1
            Screen('DrawTextures', w, gaborTextureFullVis{1}, [], CenterRectOnPointd(baseRect, xCenter*(1.8/3), yCenter*1.4), [],[], 0.5);
            DrawFormattedText(w, 'Grating A', xCenter*(1.6/3), yCenter*1.2, [255 255 255]);

            Screen('DrawTextures', w, gaborTextureFullVis{5}, [], CenterRectOnPointd(baseRect, xCenter, yCenter*1.4), [],[], 0.5);
            DrawFormattedText(w, 'Clockwise tilted', xCenter*(2.7/3), yCenter*1.2, [255 255 255]);

            Screen('DrawTextures', w, gaborTextureFullVis{3}, [], CenterRectOnPointd(baseRect, xCenter*(4.2/3), yCenter*1.4), [],[], 0.5);
            DrawFormattedText(w, 'Counter-clockwise tilted', xCenter*(3.8/3), yCenter*1.2, [255 255 255]);

            else
            Screen('DrawTextures', w, gaborTextureFullVis{2}, [], CenterRectOnPointd(baseRect, xCenter*(1.8/3), yCenter*1.4), [],[], 0.5);
            DrawFormattedText(w, 'Grating B', xCenter*(1.6/3), yCenter*1.2, [255 255 255]);

            Screen('DrawTextures', w, gaborTextureFullVis{6}, [], CenterRectOnPointd(baseRect, xCenter, yCenter*1.4), [],[], 0.5);
            DrawFormattedText(w, 'Clockwise tilted', xCenter*(2.7/3), yCenter*1.2, [255 255 255]);

            Screen('DrawTextures', w, gaborTextureFullVis{4}, [], CenterRectOnPointd(baseRect, xCenter*(4.2/3), yCenter*1.4), [],[], 0.5);
            DrawFormattedText(w, 'Counter-clockwise tilted', xCenter*(3.8/3), yCenter*1.2, [255 255 255]);
            end
            
            Screen('Flip', w);
            KbWait;
        end
        
    end
end

Screen('TextSize',w, 28);
DrawFormattedText(w, 'This is the end of the discrimination practice!', 'center', 'center', [255 255 255]);
Screen('Flip', w);
WaitSecs(2);
Screen('CloseAll')
sca;