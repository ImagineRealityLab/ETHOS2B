function [PD,PA,V] = practiceDetection_Pilot(subID,orientations, volume, deviceToUse)

%% practice detection (PD) script
% Opens window -> defines trials -> makes gabors -> adds noise ->
% runs through trials.
% =========================================================================
% Setup
% =========================================================================
soundDir = strcat(cd, '\SoundFiles');
sound0Dir = strcat(soundDir, '\VeryLowPitch250_48000.wav');
sound1Dir = strcat(soundDir,'\LowPitch500_48000.wav');
sound2Dir = strcat(soundDir,'\MidPitch750_48000.wav');

% Import sounds
[y0, ~] = psychwavread(sound0Dir);

[y1, freq1] = psychwavread(sound1Dir);


[y2, ~] = psychwavread(sound2Dir);

if size(y1,2) == 1
    y2 = [y2,y2];
    y0 = [y0,y0];
end
wavedata2 = y2';
wavedata0 = y0';

% Open the port with the volume input
InitializePsychSound;

pahandle = PsychPortAudio('Open', deviceToUse, [], 1, freq1, 2);
PsychPortAudio('Volume', pahandle, volume);


% Import noise patterns
load('noiseSchedules.mat')
schedules = {schedule1, schedule2, schedule3, schedule4};

% output directory
output = fullfile(cd,'results',subID);
if ~exist(output,'dir'); mkdir(output); end
saveName = sprintf('PD_%s.mat',subID);

% Open PTB window
[w, rect] = setWindow(0);
HideCursor;

% Trial number and P/A
nOri    = length(orientations);
nTrials = 8; % per orientation
PA      = [ones(nTrials/2,1); zeros(nTrials/2,1)];
PA      = repmat(PA,1,2);
PA(:,1) = PA(randperm(nTrials),1); PA(:,2) = PA(randperm(nTrials),2);
PD      = nan(nOri,nTrials,2);

% Visibility settings
threshold = 0.8;                        % acc to continue

visibility = 0.12;     
% Start visibility
vis_scale = [0 logspace(log10(0.005),log10(0.2),299)]; % steps in log space
[~,visibility] = min(abs(vis_scale-visibility));  % scale idx



% responses
trialResponse = 1;
trialRT       = 2;
yesKey        = {'j','k'};
noKey         = {'k','j'};

% timings    
fixTime       = 0.2;
mITI          = 1; % mean ITI - randomly sample from norm
sITI          = 0.5; % SD for sampling
ITIs          = normrnd(mITI,sITI,nOri,nTrials);

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


% Sound timing setup, ensure consistency across practices if adjusted.
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

% explain finger placement
text = ['Thank you! During this experiment you will be looking for gratings in noise (see below). \n '...
    'Gratings are images of alternating black and white lines (left). \n'...
    'Noise is a collection of random black and white pixels (middle). \n'...
    'On every trial, your task it to decide whether a grating \n ' ...
    'was present in the noise or not (right). \n \n'...
    '[Press any key to continue] \n '];



Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.65, [255 255 255]);

% show gratings
[xCenter, yCenter] = RectCenter(rect);
Xpos     = [xCenter*(1/2) xCenter xCenter*(3/2)];
baseRect = [0 0 size(gaborPatch{1},1) size(gaborPatch{1},1)];
allRects = nan(4, 3);
for i = 1:3
    allRects(:, i) = CenterRectOnPointd(baseRect, Xpos(i), yCenter*1.4);
end

Screen('DrawTextures', w, gaborTextureFullVis{1}, [], allRects(:,1), [],[], 0.5);
DrawFormattedText(w, 'Grating', xCenter*(1/2)-50, yCenter*1.105, [255 255 255]);

Screen('DrawTextures', w, gaborTextureNoVis{2}, [], allRects(:,2), [],[], 0.5);
DrawFormattedText(w, 'Noise', xCenter-30, yCenter*1.105, [255 255 255]);

Screen('DrawTextures', w, gaborTexture{1}, [], allRects(:,3), [],[], 0.5);
DrawFormattedText(w, 'Combined', xCenter*(3/2)-75, yCenter*1.105, [255 255 255]);


Screen('Flip', w);
WaitSecs(1);
KbWait;

% explain finger placement
text = ['Please place your left hand over the [d],[f] keys, \n'...
    'with your left middle on the [d] and left index on the [f]. \n' ...
    'Place your right hand over the [j],[k] \n'...
    'with your right index on the [j] and your right middle on the [k]. \n \n'...
    '[Press any key to continue] \n '];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.65, [255 255 255]);
Screen('Flip', w);
WaitSecs(1);
KbWait;

% show instructions
text = ['In this practice, your job will be to decide if you saw any gratings in the noisy image (see below). \n ',...
    'The noisy image will only be shown very briefly, so you have to be ready! \n ',...
    'To help you know when the noisy image is about to be presented, we will provide a countdown with sounds. \n ',...
    'You will hear three beeps after each other. The noisy image will appear on the third beep. \n ' ,...
    'After that, you have to indicate whether a grating was presented or not. \n \n ',...
    '[Press any key to continue] \n '];


Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.65, [255 255 255]);

% show gratings
[xCenter, yCenter] = RectCenter(rect);
Xpos     = [x_pix*(1/3) x_pix*(2/3)];
baseRect = [0 0 size(gaborPatch{1},1) size(gaborPatch{1},1)];
allRects = nan(4, 3);
for i = 1:2
    allRects(:, i) = CenterRectOnPointd(baseRect, Xpos(i), yCenter*1.4);
end

Screen('DrawTextures', w, gaborTexture{1}, [], allRects(:,1), [],[], 0.5);
DrawFormattedText(w, 'Grating A', xCenter*(1.75/3), yCenter*1.105, [255 255 255]);

Screen('DrawTextures', w, gaborTexture{2}, [], allRects(:,2), [],[], 0.5);
DrawFormattedText(w, 'Grating B', xCenter*(3.75/3), yCenter*1.105, [255 255 255]);

Screen('Flip', w);
WaitSecs(1)
KbWait;

text = ['You will indicate whether a grating was presented using your right hand. \n' ...
    'Which key, ([j] and [k]) corresponds to [yes] versus [no] will change each block. \n ' ...
    'So please read the instructions carefully! \n' ...
    'Keep your eyes fixated on the fixation cross as much as possible. \n'...
    'We will practice this a few times now. \n \n ' ...
    '[Press any key to continue] \n '];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.65, [255 255 255]);

Screen('Flip', w);
WaitSecs(1)
KbWait;

%% Trials start
for iOri = 1:nOri   
    notYet = 1;
    while notYet % until enough correct
    
        WaitSecs(fixTime); % otherwise it doesn't work
        
    % instruction screen with gratings
    if iOri == 1
    text = sprintf('During this block, you will be detecting Grating %s (see below). \n After each trial, please indicate whether this grating was presented or not. \n \n [Press any key to continue] \n ',cues{iOri});
    else
    text = sprintf('During this block, you will be detecting Grating %s (see below). \n After each trial, please indicate whether this grating was presented or not. \n',cues{iOri});
    end
    if iOri ==2
        text = [text, 'Please press [k] to indicate that the grating was presented and [j] to indicate that no grating was presented during this block. \n \n [Press any key to continue] \n'];
    end
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);    
    
    Screen('DrawTextures', w, gaborTexture{1}, [], allRects(:,1), [],[], 0.5);
    DrawFormattedText(w, 'Grating A', xCenter*(1.75/3), yCenter*1.105, [255 255 255]);
    
    Screen('DrawTextures', w, gaborTexture{2}, [], allRects(:,2), [],[], 0.5);
    DrawFormattedText(w, 'Grating B', xCenter*(3.75/3), yCenter*1.105, [255 255 255]);
    
    Screen('Flip', w);
    KbWait;
    
    for iTrial = 1:nTrials
        
        % Fixation
        Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
            4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
        Screen('Flip', w);
        WaitSecs(0.2);
        
        if PA(iTrial,iOri) == 1 % present trial
            % schedule of visibility gradient (i.e how visible at each frame)
            % Increases till most visible at the end
            schedule = zeros(1, nSteps);
            schedule(onset_frame:offset_frame) = vis_scale(visibility);
        else % Pure noise trial
            % 0 for entire schedule
                schedule = zeros(1,nSteps);
                
        end
        
        % Make the texture for each frame by combining the gabor with noise.
        % Rotates the annulus mask to hide the rotated boundary box around the
        % grating.
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
        
        % =========================================================================
        % Presentation
        % =========================================================================
        
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
        
        % Decision
        if iOri == 1
        text = 'Was there a grating on the screen? \n Yes [j] or no [k]';
        else
        text = 'Was there a grating on the screen? \n No [j] or yes [k]';
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
                if any(strcmp(key, {yesKey{iOri},noKey{iOri}}))
                    
                    % fill in B
                    PD(iOri,iTrial,trialResponse) = strcmp(key,yesKey{iOri}); % 1 yes 0 no
                    PD(iOri,iTrial,trialRT) = keyTime-vbl;
                    
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
    end
    
    % check if the accuracy is high enough, otherwise go again
    acc = mean(squeeze(PD(iOri,:,trialResponse))'==PA(:,iOri));
    WaitSecs(0.2);
    if acc < threshold % too low
        visibility = visibility - round((acc-threshold)*100); % add visibility
        
        text = sprintf('You were only correct on %d out of %d trials. \n Please make sure to carefully read the instructions about which keys to use for your responses. \n So, let"s try this again! \n \n[Press any key to continue] \n ',sum(PD(iOri,:,trialResponse)'==PA(:,iOri)),nTrials);
        
        Screen('TextSize',w, 28);
        DrawFormattedText(w, text, 'center', 'center', 255);
        Screen('Flip', w);
        KbWait;
    else % good 
        notYet = 0; % we can continue
        text = sprintf('Well done! You were correct on %d out of %d trials. \n \n [Press any key to continue]',sum(PD(iOri,:,trialResponse)'==PA(:,iOri)),nTrials);
        %text = 'poop'; 
        Screen('TextSize',w, 28);
        DrawFormattedText(w, text, 'center', 'center', 255);
        Screen('Flip', w);
        KbWait;
    end   
    end
end

V = visibility; % use this for staircase and next practice 

% Lifeguard for invalid V
if V > 300
    V = 299;
end

save(fullfile(output,saveName)); % save everything

Screen('TextSize',w, 28);
DrawFormattedText(w, 'This is the end of the first practice task!', 'center', 'center', [255 255 255]);
Screen('Flip', w);
WaitSecs(2);
Screen('CloseAll')
sca;