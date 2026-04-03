function sound_association_training(orientations, volume, deviceToUse)

%% practice detection (PD) script
% Opens window -> defines trials -> makes gabors -> adds noise ->
% runs through trials.

% =========================================================================
% Setup
% =========================================================================

% Import sounds
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

% Open the port with the volume input
InitializePsychSound;

pahandle = PsychPortAudio('Open', deviceToUse, [], 1, freq1, 2);
PsychPortAudio('Volume', pahandle, volume);

% Import noise patterns
load('noiseSchedules.mat')
schedules = {schedule1, schedule2, schedule3, schedule4};

% Open PTB window
[w, rect] = setWindow(0);
HideCursor;

visibility = 0.12;     
% Start visibility
vis_scale = [0 logspace(log10(0.005),log10(0.2),299)]; % steps in log space
[~,visibility] = min(abs(vis_scale-visibility));  % scale idx

yesKey        = {'j','k'};

nOri = length(orientations);
% timings    
fixTime       = 0.2;


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


% Timing configuration, ensure consistency.
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
[~, yCenter] = RectCenter(rect);
[x_pix, ~] = Screen('WindowSize', w);
HideCursor;

% explain finger placement
text = ['During the experiment, we will also ask you to imagine the gratings, \n',...
    'while looking at the noise image. Importantly, the first beep tone indicates whether you should imagine a grating or not. \n',...
    'If the first beep is a high pitch tone, you should IMAGINE the gratings. \n',...
    'If the first beep is a low-pitch tone you should NOT imagine the gratings. \n',...
    'You must imagine the gratings exactly when you hear the third beep. \n \n',...
    '[Press any key to continue] \n '];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.65, [255 255 255]);
Screen('Flip', w);
WaitSecs(1)
KbWait;

% show instructions
text = ['You will be asked to imagine two different gratings that you previously detected. \n',...
    'Importantly, the second beep that you will hear will indicate which grating you should imagine. \n',...
    'If the second beep is a high pitch tone you should imagine Grating A (see below). \n',...
    'If the second beep is a low pitch tone you should imagine Grating B (see below). \n \n',...
        '[Press any key to start]'];

% show gratings
[xCenter, yCenter] = RectCenter(rect);
Xpos     = [x_pix*(1/3) x_pix*(2/3)];
baseRect = [0 0 size(gaborPatch{1},1) size(gaborPatch{1},1)];
allRects = nan(4, 3);
for i = 1:2
    allRects(:, i) = CenterRectOnPointd(baseRect, Xpos(i), yCenter*1.4);
end

Screen('TextSize',w, 28);
Screen('DrawTextures', w, gaborTextureFullVis{1}, [], allRects(:,1), [],[], 0.5);
DrawFormattedText(w, 'Grating A', xCenter*(1.80/3), yCenter*1.15, [255 255 255]);

Screen('DrawTextures', w, gaborTextureFullVis{2}, [], allRects(:,2), [],[], 0.5);
DrawFormattedText(w, 'Grating B', xCenter*(3.80/3), yCenter*1.15, [255 255 255]);

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.65, [255 255 255]);
Screen('Flip', w);
WaitSecs(1)
KbWait;

% explain finger placement
text = ['Now, we will play the sounds and show the grating that you should imagine with that sound a couple of times. \n '...,
    'Please do not imagine the gratings yet, and just pay attention to the sounds and the gratings shown on the screen. \n\n'...,
    '[Press any key to start]'];
DrawFormattedText(w, text, 'center', yCenter*0.65, [255 255 255]);
Screen('Flip', w);
WaitSecs(1)
KbWait;

observe_trials_1 = [0,1,2,0,1,2];
observe_trials_2 = repmat([1,2],1,8);
observe_trials_2 = observe_trials_2(randperm(length(observe_trials_2)));
observe_trials = [observe_trials_1, observe_trials_2];


%% Trials start
for iTrial = 1:length(observe_trials)

        % Fixation
        Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
            4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
        Screen('Flip', w);
        WaitSecs(0.2);
        
        tStart = GetSecs;

        while GetSecs - tStart < 0.2
        [~, ~, keyCode] = KbCheck(-3);
            if keyCode(KbName('ESCAPE'))
                Screen('TextSize',w, 28);
                DrawFormattedText(w, 'Experiment was aborted!', 'center', 'center', [255 255 255]);
                Screen('Flip',w);
                WaitSecs(0.5);
                ShowCursor;
                disp(' ');
                disp('Experiment aborted by user!');
                disp(' ');
                Screen('CloseAll');
            end
        end
        
        if observe_trials(iTrial) == 1 || observe_trials(iTrial) == 2  % present trial
            % schedule of visibility gradient (i.e how visible at each frame)
            % Increases till most visible at the end
            schedule = zeros(1, nSteps);
            schedule(onset_frame:offset_frame) = vis_scale(visibility);
            ori = observe_trials(iTrial);
        else % Pure noise trial;
            % 0 for entire schedule
                schedule = zeros(1,nSteps);
                ori = 1;
        end
        
        target = {};

            for i_frame = 1:nSteps
                idx = ((i_frame-1)*nStepSize)+1 : (i_frame*nStepSize);
                    tmp = Screen('MakeTexture', w, ...
                        make_stimulus_differentNoises( ...
                            orientations(ori), schedule(i_frame), schedules{1}{1, i_frame}));
                for i = 1:length(idx)
                    target{idx(i)} = tmp;
                end
            end
        
        % =========================================================================
        % Presentation
        % =========================================================================
        
        % 0 250 - 1 500 - 2 750 - 3 1000
        if observe_trials(iTrial) == 0
            sound1 = wavedata0;
            sound2 = wavedata0;
            sound3 = wavedata2;
        elseif observe_trials(iTrial) == 1
            sound1 = wavedata2;
            sound2 = wavedata3;
            sound3 = wavedata2;
        else
            sound1 = wavedata2;
            sound2 = wavedata1;
            sound3 = wavedata2;
        end


        % Present stimulus
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

            % if observe_trials(iTrial) == 0
            %     text = 'DO NOT IMAGINE';
            %     DrawFormattedText(w,text,xCenter*0.88, yCenter*0.75, [255 255 255]);
            % elseif observe_trials(iTrial) == 1
            %     text = 'IMAGINE GRATING A';
            %     DrawFormattedText(w,text,xCenter*0.85, yCenter*0.75, [255 255 255]);
            % else
            %     text = 'IMAGINE GRATING B';
            %     DrawFormattedText(w,text,xCenter*0.85, yCenter*0.75, [255 255 255]);
            % end
    
            fix_color = [0,0,0];
            Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], 4, fix_color, [rect(3)/2, rect(4)/2], 1);
            Screen('Flip', w);
        end % end frame loop
                         
        % Close all textures to free memory     
        tmp = unique(cell2mat(target));
        for i_tex = 1:length(tmp)
            Screen('Close', tmp(i_tex));
        end
end

%% No imagery vs. imagery test

DrawFormattedText(w, 'Thank you! Now, we will ask you whether you should have imagined the gratings after each trial. \n Remember, the first tone indicates if you should imagine the gratings on that trial. \n You need to give 3 correct responses in a row to finish this part. \n\n [Press any key to start]', 'center', yCenter*(2/3), [255 255 255]);

Screen('TextSize',w, 28);
Screen('DrawTextures', w, gaborTextureFullVis{1}, [], allRects(:,1), [],[], 0.5);
DrawFormattedText(w, 'Grating A', xCenter*(1.80/3), yCenter*1.15, [255 255 255]);

Screen('DrawTextures', w, gaborTextureFullVis{2}, [], allRects(:,2), [],[], 0.5);
DrawFormattedText(w, 'Grating B', xCenter*(3.80/3), yCenter*1.15, [255 255 255]);

Screen('TextSize',w, 28);
Screen('Flip', w);
WaitSecs(1)
KbWait;

max_trial_num = 39;

check_trials = repmat([0,0,1,2],1,10);

check_trials = check_trials(randperm(length(check_trials)));

confirmed = 0;

trial_no = 0;

correct_in_a_row = 0;

while ~confirmed
    trial_no = trial_no +1;
    condition = check_trials(trial_no);

    WaitSecs(fixTime); % otherwise it doesn't work

        % Fixation
        Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
            4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
        Screen('Flip', w);
        WaitSecs(0.2);
        
        %if condition == 1 || condition == 2  % present trial
            % schedule of visibility gradient (i.e how visible at each frame)
            % Increases till most visible at the end
            %schedule = zeros(1, nSteps);
            %schedule(onset_frame:offset_frame) = vis_scale(visibility);
            %ori = condition;
        %else % Pure noise trial;
            % 0 for entire schedule
                schedule = zeros(1,nSteps);
                ori = 1;
        %end
        
        target = {};

            for i_frame = 1:nSteps
                idx = ((i_frame-1)*nStepSize)+1 : (i_frame*nStepSize);
                    tmp = Screen('MakeTexture', w, ...
                        make_stimulus_differentNoises( ...
                            orientations(ori), schedule(i_frame), schedules{1}{1, i_frame}));
                for i = 1:length(idx)
                    target{idx(i)} = tmp;
                end
            end
        
        % =========================================================================
        % Presentation
        % =========================================================================
        
        % 0 250 - 1 500 - 2 750 - 3 1000
        if condition == 0
            sound1 = wavedata0;
            sound2 = wavedata0;
            sound3 = wavedata2;
        elseif condition == 1
            sound1 = wavedata2;
            sound2 = wavedata3;
            sound3 = wavedata2;
        else
            sound1 = wavedata2;
            sound2 = wavedata1;
            sound3 = wavedata2;
        end


        % Present stimulus
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
                         
        % Close all textures to free memory     
        tmp = unique(cell2mat(target));
        for i_tex = 1:length(tmp)
            Screen('Close', tmp(i_tex));
        end

        % Decision
        text = 'Should you have imagined the gratings? \n Yes [j] or No [k]';

        Screen('TextSize',w, 28);
        DrawFormattedText(w, text, 'center', yCenter, [255 255 255]);
        
        Screen('Flip', w);
        
        % Log response
        keyPressed = 0; % clear previous response
        while ~keyPressed
            
            [~, ~, keyCode] = KbCheck(-3);
            key = KbName(keyCode);
            
            if ~iscell(key) % only start a keypress if there is only one key being pressed
                if any(strcmp(key, yesKey))
                    
                    if strcmp(key,yesKey{1}) && condition == 1 || condition == 2 
                        correct_in_a_row = correct_in_a_row + 1;
                        text = sprintf('Correct, %d in a row!', correct_in_a_row);
                    elseif strcmp(key,yesKey{2}) && condition == 0
                        correct_in_a_row = correct_in_a_row + 1;
                        text = sprintf('Correct, %d in a row!', correct_in_a_row);
                    else
                        text = 'Incorrect!';
                        correct_in_a_row = 0;
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
                    return;
                end
            end
        end  
        
        

        Screen('TextSize',w, 28);
        DrawFormattedText(w, text, 'center', 'center', [255 255 255]);
        Screen('Flip', w);
        WaitSecs(0.5);

    if trial_no == max_trial_num || correct_in_a_row == 3
        confirmed = 1;
    end

end

%% Left ori vs right ori check.

DrawFormattedText(w, 'Thank you! Now, we will ask you to indicate which grating you should have imagined after each trial. \n You need to give 5 correct responses in a row to finish this part. \n Remember, if the second tone pitch is higher, you should imagine Grating A. \n If the second tone pitch is lower, you should imagine Grating B. \n\n [Press any key to start]', 'center', 'center', [255 255 255]);
Screen('TextSize',w, 28);
Screen('Flip', w);
WaitSecs(1)
KbWait;

max_trial_num = 49;

check_trials = repmat([1,2],1,25);

check_trials = check_trials(randperm(length(check_trials)));

confirmed = 0;

trial_no = 0;

correct_in_a_row = 0;

while ~confirmed
    trial_no = trial_no +1;
    condition = check_trials(trial_no);

    WaitSecs(fixTime); % otherwise it doesn't work
        % Fixation
        Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
            4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
        Screen('Flip', w);
        WaitSecs(0.2);
        
        %if condition == 1 || condition == 2  % present trial
            % schedule of visibility gradient (i.e how visible at each frame)
            % Increases till most visible at the end
            %schedule = zeros(1, nSteps);
            %schedule(onset_frame:offset_frame) = vis_scale(visibility);
            %ori = condition;
        %else % Pure noise trial;
            % 0 for entire schedule
                schedule = zeros(1,nSteps);
                ori = 1;
        %end
        
        target = {};

            for i_frame = 1:nSteps
                idx = ((i_frame-1)*nStepSize)+1 : (i_frame*nStepSize);
                    tmp = Screen('MakeTexture', w, ...
                        make_stimulus_differentNoises( ...
                            orientations(ori), schedule(i_frame), schedules{1}{1, i_frame}));
                for i = 1:length(idx)
                    target{idx(i)} = tmp;
                end
            end
        
        % =========================================================================
        % Presentation
        % =========================================================================
        
        % 0 250 - 1 500 - 2 750 - 3 1000
        if condition == 0
            sound1 = wavedata0;
            sound2 = wavedata0;
            sound3 = wavedata2;
        elseif condition == 1
            sound1 = wavedata2;
            sound2 = wavedata3;
            sound3 = wavedata2;
        else
            sound1 = wavedata2;
            sound2 = wavedata1;
            sound3 = wavedata2;
        end


        % Present stimulus
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
                         
        % Close all textures to free memory     
        tmp = unique(cell2mat(target));
        for i_tex = 1:length(tmp)
            Screen('Close', tmp(i_tex));
        end

        % Decision
        text = 'Which grating you should have imagined? \n\n Grating A [j] or Grating B [k]';

        Screen('TextSize',w, 28);
        DrawFormattedText(w, text, 'center', yCenter*2/3, [255 255 255]);

        Screen('DrawTextures', w, gaborTextureFullVis{1}, [], allRects(:,1), [],[], 0.5);
        DrawFormattedText(w, 'Grating A', xCenter*(1.80/3), yCenter*1.15, [255 255 255]);
        
        Screen('DrawTextures', w, gaborTextureFullVis{2}, [], allRects(:,2), [],[], 0.5);
        DrawFormattedText(w, 'Grating B', xCenter*(3.80/3), yCenter*1.15, [255 255 255]);
        


        Screen('Flip', w);
        
        % Log response
        keyPressed = 0; % clear previous response
        while ~keyPressed
            
            [~, ~, keyCode] = KbCheck(-3);
            key = KbName(keyCode);
            
            if ~iscell(key) % only start a keypress if there is only one key being pressed
                if any(strcmp(key, yesKey))
                    
                    if strcmp(key,yesKey{1}) && condition == 1
                        
                        correct_in_a_row = correct_in_a_row + 1;
                        text = sprintf('Correct, %d in a row!', correct_in_a_row);
                    elseif strcmp(key,yesKey{2}) && condition == 2
                        correct_in_a_row = correct_in_a_row + 1;
                        text = sprintf('Correct, %d in a row!', correct_in_a_row);
                    else
                        text = 'Incorrect!';
                        correct_in_a_row = 0;
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
                    return;
                end
            end
        end  
        
        

        Screen('TextSize',w, 28);
        DrawFormattedText(w, text, 'center', 'center', [255 255 255]);
        Screen('Flip', w);
        WaitSecs(0.5);

    if trial_no == max_trial_num || correct_in_a_row == 5
        confirmed = 1;
    end

end

Screen('TextSize',w, 28);
DrawFormattedText(w, 'This is the end of the association practice!', 'center', 'center', [255 255 255]);
Screen('Flip', w);
WaitSecs(2);
Screen('CloseAll')
sca;