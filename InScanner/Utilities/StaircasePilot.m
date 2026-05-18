
%% outside staircase detection (SD) script
% Opens window -> defines trials -> makes gabors -> adds noise ->
% runs through trials.

function [V,acc] = StaircasePilot(subID,orientation,gratingName,V,~,config)

% =========================================================================
% Setup
% =========================================================================

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

pahandle = PsychPortAudio('Open', 2, [], 1, freq1, 2);

HideCursor;

load('noiseSchedules.mat')
schedules = {schedule1, schedule2, schedule3, schedule4};

% threshold value
threshold = 0.7; % accuracy to staircase to

% output
output = fullfile(cd,'results',subID);
if ~exist(output,'dir'); mkdir(output); end
saveName = sprintf('SC_%d_%s.mat',orientation,subID);

[w, rect] = setWindow(0);
ShowCursor;

% Trial numbers
nEvalTrials = 6;                       % Determine detection accuracy for this many trials
nStairs = 8;
nTrials = nStairs*nEvalTrials;



% Get the trial structure
trials = stairTrialStructure(nTrials, nEvalTrials);

% Visibility settings

vis_scale = [0 logspace(log10(0.005),log10(0.2),299)]; % steps in log space
visibility = V;

lower_bound = 0.6;                      % Go up around here
upper_bound = 0.8;                      % Go down around here
V = zeros(nStairs,1);                   % Track visibility
acc = zeros(nStairs,1);                 % Track detection acc

% responses
B = zeros(nTrials,2); 
trialResponse = 1;
trialRT       = 2;
if config == 1
    yesKey        = 'j';
    noKey         = 'k';
else
    yesKey        = 'k';
    noKey         = 'j';
end




% timing
fixTime       = 0.2;
mITI    = 1; % mean ITI - randomly sample from norm
sITI    = 0.5; % SD for sampling
ITIs          = normrnd(mITI,sITI,1,nTrials);

% =========================================================================
% Stimuli
% =========================================================================

% Makes the gabors to show for instruction
gaborPatch = make_stimulus(orientation,1); % full visibility
gaborTexture = Screen('MakeTexture',w,gaborPatch);

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
if config == 1
text = ['We will now do a calibration on the visibility of the gratings in noise. \n ',...
    'Your task is simply to indicate whether the grating below is presented (Yes [j] or No [k]) \n ',...
    'The grating will be presented in 50% of the trials. Over the course of the block it \n ',...
    'will become harder to see the gratings. Try to focus as best as you can. \n \n',...
    'Do not worry if you become unsure about whether you saw something or not, \n ' ...
    'that is supposed to happen. Just give your best guess on every trial. \n'...
    'Keep your eyes fixated on the fixation cross as much as possible. \n'...
    'Each block will take about 5 minutes. Good luck! \n',...
    '[Press any key to start] \n '];
else
text = ['Now we’ll do the same thing with Grating B! \n ',...
    'The procedure will exactly be the same as Grating A \n',...
    'This will take about 5 minutes, Good luck! \n',...
    '[Press any key to start] \n '];    
end

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);

% show gratings
Xpos     = x_pix*(1/2);
baseRect = [0 0 size(gaborPatch,1) size(gaborPatch,1)];
allRect  = CenterRectOnPointd(baseRect,Xpos,yCenter*1.5);

Screen('DrawTextures', w, gaborTexture, [], allRect, [],[], 0.5);
DrawFormattedText(w, sprintf('Grating %s',gratingName), xCenter*0.94, yCenter*1.3, [255 255 255]);

Screen('Flip', w);
WaitSecs(1);
KbWait;
    
%% Trials start
stairCount = 0; stairStep = 1;
for iTrial = 1:nTrials
    % Fixation
    Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
        4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
    Screen('Flip', w);
    WaitSecs(fixTime);
    
    % Grating noise frames
    if trials(iTrial,1) == 1 % present trial
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

    for i_frame = 1:nSteps
        idx = ((i_frame-1)*nStepSize)+1 : (i_frame*nStepSize);
            tmp = Screen('MakeTexture', w, ...
                make_stimulus_differentNoises( ...
                    orientation, schedule(i_frame), ...
                    schedules{1}{1, i_frame}));
                for i = 1:length(idx)
                    target{idx(i)} = tmp;
                end
    end
    % =========================================================================
    % Presentation
    % =========================================================================
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
    stairCount = stairCount + 1;
    if config == 1
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
            if any(strcmp(key, {yesKey,noKey}))
                
                % fill in B
                B(iTrial,trialResponse) = strcmp(key,yesKey); % 1 yes 0 no
                B(iTrial,trialRT) = keyTime-vbl;
                
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
    
    % determine visibility next trial after every n trials
    if stairCount==nEvalTrials
        
        % trials to evaluate
        idx = (stairStep-1)*nEvalTrials+1:stairStep*nEvalTrials;
        
        V(stairStep) = visibility; % track
        acc(stairStep) = sum(trials(idx,1)==B(idx,trialResponse))/nEvalTrials;
        
        % update visibility based on accuracy
        if (acc(stairStep) > upper_bound) || (acc(stairStep) < lower_bound)
            visibility = visibility - round((acc(stairStep)-threshold)*120);
           
        end
        
        % update counters
        stairStep = stairStep+1;
        stairCount = 0; % reset
    end    
    
    % Inter trial interval
    Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
        4, [255,255,255], [rect(3)/2, rect(4)/2], 1);
    Screen('Flip', w);
    WaitSecs(ITIs(iTrial));
    
    % Close all textures to free memory
    tmp = unique(cell2mat(target));
    for i_tex = 1:length(tmp)
        Screen('Close', tmp(i_tex));
    end
end
save(fullfile(output,saveName)); % save everything

Screen('TextSize',w, 28);
DrawFormattedText(w, 'This is the end of this calibration!', 'center', 'center', [255 255 255]);
Screen('Flip', w);
WaitSecs(2);
Screen('CloseAll')
sca; 