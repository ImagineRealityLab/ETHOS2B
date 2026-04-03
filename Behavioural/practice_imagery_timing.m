function [vividness] = practice_imagery_timing(V, orientations, ori, volume, deviceToUse)

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

for iSchedule = 1:length(schedules)
    schedules{iSchedule} = [schedules{iSchedule}, schedules{iSchedule}];
end

[w, rect] = setWindow(0);
[x_pix, ~] = Screen('WindowSize', w);
HideCursor;

% Trial number and P/A

nTrials = 20; % per orientation
vis_scale = [0 logspace(log10(0.005),log10(0.2),299)]; % steps in log space

nOri = length(orientations);
% timings    
fixTime       = 1;
mITI          = 1; % mean ITI - randomly sample from norm
sITI          = 0.5; % SD for sampling
ITIs          = normrnd(mITI,sITI,nTrials,1);

% =========================================================================
% Stimuli
% =========================================================================

% Makes the gabors to show for instruction
gaborPatch   = cell(nOri,1);
gaborTexture = cell(nOri,1);
for iOri = 1:nOri
    % stimulus
    gaborPatch{iOri} = make_stimulus(orientations(iOri),0.3);
    % texture
    gaborTexture{iOri} = Screen('MakeTexture',w,gaborPatch{iOri});
end

gaborPatchFullVis   = cell(nOri,1);
gaborTextureFullVis = cell(nOri,1);
for iOri = 1:nOri
    % stimulus
    gaborPatchFullVis{iOri} = make_stimulus(orientations(iOri),1);
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
nStepSize = 1;   

[xCenter, yCenter] = RectCenter(rect);
Xpos     = [x_pix*(1/3) x_pix*(2/3)];
baseRect = [0 0 size(gaborPatch{1},1) size(gaborPatch{1},1)];
allRects = nan(4, 3);
for i = 1:2
    allRects(:, i) = CenterRectOnPointd(baseRect, Xpos(i), yCenter*1.5);
end

displayDuration = 3.1;  % 2 frames per step
nSteps = round((displayDuration/ifi)/nStepSize);
frame_duration = ifi * nStepSize;

onset_time = 2.3;  
offset_time = 2.5; 
onset_frame = round(onset_time / frame_duration);
offset_frame = round(offset_time / frame_duration);

timePoint0 = 0.05; % a brief buffer to ensure the display is done properly
timePoint1 = 0.2;
timePoint2 = 1.1;
timePoint3 = 1.3;
TP0_frame = round(timePoint0 / frame_duration);
TP1_frame = round(timePoint1 / frame_duration);
TP2_frame = round(timePoint2 / frame_duration);
TP3_frame = round(timePoint3 / frame_duration);




cues = {'A','B'}; 
confirmed = false;
maxAttempts = 3;
attempt = 1;
blockTrials = 16;      
repeatTrials = 8;     
correctKey = 'D';      % correct answer = third beep (D)
acceptedKeys = {'A','S','D'}; % first, second, third
vividness = [];
% main attempt loop
while ~confirmed && attempt <= maxAttempts
    if attempt == 1
        nTrialsThisAttempt = blockTrials;
    else
        nTrialsThisAttempt = repeatTrials;
    end
        
    if attempt == 1
        
        text = sprintf(['In another part of the study, we will also ask you \n' ...
            'to imagine a grating while you are looking at the noise patterns.\n' ...
            'It is important that you imagine at exactly the same time that the image is shown, so during the final beep. \n'...
            'First, we will show you an example trial with the grating appearing on screen. \n \n [Press any key to start] \n '],cues{ori});
        Screen('TextSize',w, 28);
        DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);    
        Screen('Flip', w);
        WaitSecs(1);
        KbWait;

        
    else
    text = sprintf(['We will do a couple of more practice trials. \n\n ' ...
        'Remember, you should imagine the grating exactly at the same time when you will hear the third beep sound. \n' ...'
        'Keep your eyes fixated on the fixation cross as much as possible. \n \n [Press any key to start] \n '],cues{ori});

    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);    
    Screen('DrawTextures', w, gaborTextureFullVis{1}, [], allRects(:,1), [],[], 0.5);
    DrawFormattedText(w, 'Grating A', xCenter*(1.8/3), yCenter*1.2, [255 255 255]);
    Screen('DrawTextures', w, gaborTextureFullVis{2}, [], allRects(:,2), [],[], 0.5);
    DrawFormattedText(w, 'Grating B', xCenter*(3.8/3), yCenter*1.2, [255 255 255]);
    Screen('Flip', w);
    WaitSecs(1);
    KbWait;
    end
    
    %% Phase 1 - Observation
    text = ['During this trial we will show you when you should imagine the grating. \n ' ...
        'Please do not imagine any gratings at this stage but just watch carefully. \n \n '...
        '[Press any key to continue]'
        ];
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);    
    Screen('Flip', w);
    WaitSecs(1);
    KbWait;    
    Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], 4, [255,255,255], [rect(3)/2, rect(4)/2], 1);
    Screen('Flip', w);
    tStart = GetSecs;
    while (GetSecs - tStart) < fixTime
        [keyIsDown, ~, keyCode] = KbCheck;
    
        if keyIsDown
            if keyCode(KbName('ESCAPE'))
                % Clean shutdown of audio + window
                PsychPortAudio('Stop', pahandle);
                PsychPortAudio('Close', pahandle);
                Screen('CloseAll');
                sca;
                error('Experiment manually aborted by user (ESC).');
            end
        end
    end
    
    schedule = zeros(1,nSteps);
    schedule(onset_frame:offset_frame) = vis_scale(299);
    
    createdTextures = [];
    target = cell(1,nSteps);
    for i_frame = 1:nSteps
            tmp = Screen('MakeTexture', w, ...
                make_stimulus_differentNoises(orientations(ori), schedule(i_frame), schedules{1}{1, i_frame}));
            createdTextures(end+1) = tmp; 
        target{i_frame} = tmp;
    end
    
    if ori == 1
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
        

        if i_frame < onset_frame
            displayText = 'Prepare';
        elseif i_frame >= onset_frame && i_frame < offset_frame
            displayText = 'IMAGINE!';
        else
            displayText = ' ';  % safe
        end
        
        if strcmp(displayText,'Prepare')
            DrawFormattedText(w, displayText, xCenter*0.94, yCenter*0.75, [255 255 255]);
        elseif strcmp(displayText,'IMAGINE!')
            DrawFormattedText(w, displayText, xCenter*0.94, yCenter*0.75, [255 0 0]);
        end

        fix_color = [0,0,0];
        Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], 4, fix_color, [rect(3)/2, rect(4)/2], 1);
        Screen('Flip', w);
    end % end frame loop
    if ~isempty(createdTextures)
        createdTextures = unique(createdTextures);
        for itx = 1:length(createdTextures)
            try Screen('Close', createdTextures(itx)); catch; end
        end
    end
    Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], 4, [255,255,255], [rect(3)/2, rect(4)/2], 1);
    Screen('Flip', w);
    WaitSecs(mITI);
    
    %% Phase - 2
    text = sprintf(['Thank you! During the next trials, please imagine Grating %s (see below) \n' ...
            'exactly at the time of the third beep. Remember, the beeps reflect a countdown \n ' ...
            'for when you should imagine to help with getting your timing right. \n' ...
            'Please imagine as vividly as possible, as if the grating was actually shown on the screen. \n \n ' ...
            '[Press any key to start] \n '],cues{ori});

    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter*0.85, [255 255 255]);    
    Screen('DrawTextures', w, gaborTextureFullVis{1}, [], allRects(:,1), [],[], 0.5);
    DrawFormattedText(w, 'Grating A', xCenter*(1.8/3), yCenter*1.25, [255 255 255]);
    Screen('DrawTextures', w, gaborTextureFullVis{2}, [], allRects(:,2), [],[], 0.5);
    DrawFormattedText(w, 'Grating B', xCenter*(3.8/3), yCenter*1.25, [255 255 255]);
    Screen('Flip', w);
    WaitSecs(1);
    KbWait;    
    
    text = sprintf(['In the next trials, we will present a faint grating at the same time to help you practice the timing of your imagery. \n'...
        'After each trial, we will ask you to evaluate the vividness of your imagery on a scale of 1-4 with your left hand [A-S-D-F]. \n'...
        'Keep your eyes fixated on the fixation cross as much as possible throughout the trial. \n \n [Press any key to start] \n '],cues{ori});

    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter*0.85, [255 255 255]);    
    Screen('DrawTextures', w, gaborTextureFullVis{1}, [], allRects(:,1), [],[], 0.5);
    DrawFormattedText(w, 'Grating A', xCenter*(1.8/3), yCenter*1.25, [255 255 255]);
    Screen('DrawTextures', w, gaborTextureFullVis{2}, [], allRects(:,2), [],[], 0.5);
    DrawFormattedText(w, 'Grating B', xCenter*(3.8/3), yCenter*1.25, [255 255 255]);
    Screen('Flip', w);
    WaitSecs(1);
    KbWait;    

    % run the trials for this attempt
    for t = 1:nTrialsThisAttempt
        if (nTrialsThisAttempt/4) + 1 == t
            text = sprintf(['Thank you! During the next trials, we will not show the gratings. \n ' ...
            'Please still imagine Grating %s (see below) as vividly as possible, as if it was actually shown in the noise. \n \n ' ...
            'Remember, the beeps reflect a countdown for when the grating will appear. \n ' ...
            'You should imagine the grating exactly at the same time when you will hear the third beep sound. \n' ...
            'Again, after each trial, we will ask you to evaluate the vividness of your imagery on a scale of 1-4 with your left hand. \n'...
            'Keep your eyes fixated on the fixation cross as much as possible. \n \n [Press any key to start] \n '],cues{ori});

            Screen('TextSize',w, 28);
            DrawFormattedText(w, text, 'center', yCenter*0.65, [255 255 255]);    
            Screen('DrawTextures', w, gaborTextureFullVis{1}, [], allRects(:,1), [],[], 0.5);
            DrawFormattedText(w, 'Grating A', xCenter*(1.8/3), yCenter*1.25, [255 255 255]);
            Screen('DrawTextures', w, gaborTextureFullVis{2}, [], allRects(:,2), [],[], 0.5);
            DrawFormattedText(w, 'Grating B', xCenter*(3.8/3), yCenter*1.25, [255 255 255]);
            Screen('Flip', w);
            WaitSecs(1);
            KbWait;      

        elseif ((nTrialsThisAttempt/4)*2)+1 == t

             text = sprintf(['Thank you! During the next trials, we will ask you to imagine the gratings slightly faster. \n ' ...
                             'Remember, the beeps reflect a countdown for when the grating will appear to help you get your timing exactly right. \n ' ...
                             'You should again imagine the grating exactly at the same time when you will hear the third beep sound. \n' ...
            'You should still imagine Grating %s (see below) as vividly as possible, as if it was actually shown in the noise. \n \n ' ...
            'Keep your eyes fixated on the fixation cross as much as possible. \n \n [Press any key to start] \n '],cues{ori});

            Screen('TextSize',w, 28);
            DrawFormattedText(w, text, 'center', yCenter*0.65, [255 255 255]);    
            Screen('DrawTextures', w, gaborTextureFullVis{1}, [], allRects(:,1), [],[], 0.5);
            DrawFormattedText(w, 'Grating A', xCenter*(1.8/3), yCenter*1.25, [255 255 255]);
            Screen('DrawTextures', w, gaborTextureFullVis{2}, [], allRects(:,2), [],[], 0.5);
            DrawFormattedText(w, 'Grating B', xCenter*(3.8/3), yCenter*1.25, [255 255 255]);
            Screen('Flip', w);
            WaitSecs(1);
            KbWait;  

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

        end

        trialIndexGlobal = t; % index within this attempt's mini-block
        showGrating = (trialIndexGlobal <= nTrialsThisAttempt/4);
        % Per-trial setup
        Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], 4, [255,255,255], [rect(3)/2, rect(4)/2], 1);
        Screen('Flip', w);
        tStart = GetSecs;
        while (GetSecs - tStart) < fixTime
            [keyIsDown, ~, keyCode] = KbCheck;
        
            if keyIsDown
                if keyCode(KbName('ESCAPE'))
                    % Clean shutdown of audio + window
                    PsychPortAudio('Stop', pahandle);
                    PsychPortAudio('Close', pahandle);
                    Screen('CloseAll');
                    sca;
                    error('Experiment manually aborted by user (ESC).');
                end
            end
        end

        % prepare schedule for frames
        schedule = zeros(1,nSteps);
        if showGrating
            schedule(onset_frame:offset_frame) = vis_scale(V); 
        else
        end

        createdTextures = [];
        target = cell(1,nSteps);
        for i_frame = 1:nSteps
                tmp = Screen('MakeTexture', w, ...
                    make_stimulus_differentNoises(orientations(ori), schedule(i_frame), schedules{1}{1, i_frame}));
                createdTextures(end+1) = tmp; 
            target{i_frame} = tmp;
        end
        

        if ori == 1
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
            
            if i_frame < onset_frame
                displayText = 'Prepare';
            elseif i_frame >= onset_frame && i_frame < offset_frame
                displayText = 'IMAGINE!';
            else
                displayText = ' ';  % safe
            end
            
            if strcmp(displayText,'Prepare')
                DrawFormattedText(w, displayText, xCenter*0.94, yCenter*0.75, [255 255 255]);
            elseif strcmp(displayText,'IMAGINE!')
                DrawFormattedText(w, displayText, xCenter*0.94, yCenter*0.75, [255 0 0]);
            end

            fix_color = [0,0,0];
            Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], 4, fix_color, [rect(3)/2, rect(4)/2], 1);
            Screen('Flip', w);
        end % end frame loop

        if ~isempty(createdTextures)
            createdTextures = unique(createdTextures);
            for itx = 1:length(createdTextures)
                try Screen('Close', createdTextures(itx)); catch; end
            end
        end

        try
            thisITI = ITIs(iTrial);
        catch
            thisITI = mITI;
        end

        text = ['How vividly did you imagine the grating? (1-4)\n\n' ...
                '1 [A], 2 [S], 3 [D], 4 [F]'];
        
        DrawFormattedText(w, text, 'center', 'center', [255 255 255]);
        Screen('Flip', w);
        
        Response = false;
        
        validKeys = [KbName('a'), KbName('s'), KbName('d'), KbName('f')];
        vividnessValues = [1, 2, 3, 4];   % map A,S,D,F to 1–4
        
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

        

        Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], 4, [255,255,255], [rect(3)/2, rect(4)/2], 1);
        Screen('Flip', w);
        WaitSecs(thisITI);

    end 

    text = 'On which beep did you imagine the gratings? \n\n First [A], Second [S], Third [D]';
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter, [255 255 255]);
    Screen('Flip', w);

    % Get response
    responseGiven = false;
    responseCorrect = false;
    while ~responseGiven
        [~, ~, keyCode] = KbCheck(-3);
        if any(keyCode)
            keyNames = KbName(keyCode);
            % KbName sometimes returns cell array if multiple keys; we guard against that
            if iscell(keyNames)
                keyNames = keyNames{1};
            end
            if any(strcmpi(keyNames, acceptedKeys))
                responseGiven = true;
                if strcmpi(keyNames, correctKey)
                    responseCorrect = true;
                else
                    responseCorrect = false;
                end
            end
            % small pause to avoid multiple detections
            WaitSecs(0.05);
        end
    end
    if responseCorrect
        % Ask confirmation question (A = OK, B = need more practice)
        text = ['Correct! \n\n Were you able to imagine the gratings exactly when you heard the last beep or do you need more practice? \n\n' ...
                'I imagined the gratings exactly at the same time I heard the beep [A], A couple of more practices would help [S]'];
        Screen('TextSize', w, 28);
        DrawFormattedText(w, text, 'center', 'center', 255);
        Screen('Flip', w);

        followUpGiven = false;
        followUpAcceptedKeys = {'a','s','A','S'}; % allow upper/lower case
        while ~followUpGiven
            [~, ~, keyCode2] = KbCheck(-3);
            if any(keyCode2)
                keyNames2 = KbName(keyCode2);
                if iscell(keyNames2)
                    keyNames2 = keyNames2{1};
                end
                if any(strcmpi(keyNames2, followUpAcceptedKeys))
                    followUpGiven = true;
                    if strcmpi(keyNames2, 'a')
                        confirmed = true;
                        Screen('TextSize', w, 28);
                        DrawFormattedText(w, 'Thanks!. \n\n[Press any key to continue]', 'center', 'center', 255);
                        Screen('Flip', w);
                        KbWait;
                        break; 
                    else
    
                        attempt = attempt + 1;
                        Screen('TextSize', w, 28);
                        DrawFormattedText(w, 'Okay — we will do a couple more practice trials. \n\n[Press any key to continue]', 'center', 'center', 255);
                        Screen('Flip', w);
                        KbWait;
                        break; 
                    end
                end
                WaitSecs(0.05); 
            end
        end
        if confirmed
            break; 
        end
    else
        text = 'That is incorrect, please read the block instructions carefully! \n \n [Press any key to continue]';
        Screen('TextSize',w, 28);
        DrawFormattedText(w, text, 'center', 'center', 255);
        Screen('Flip', w);
        KbWait;
        attempt = attempt + 1;
    end

end % end while ~confirmed

if ~confirmed
    text = 'We will move on now. If you need more practice later, tell the experimenter.';
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', 'center', 255);
    Screen('Flip', w);
    WaitSecs(2);
end



% final cleanup: stop audio
PsychPortAudio('Stop', pahandle);
PsychPortAudio('Close', pahandle);
Screen('TextSize',w, 28);
DrawFormattedText(w, 'This is the end of the timing practice!', 'center', 'center', [255 255 255]);
Screen('Flip', w);
WaitSecs(2);
Screen('CloseAll')
sca;