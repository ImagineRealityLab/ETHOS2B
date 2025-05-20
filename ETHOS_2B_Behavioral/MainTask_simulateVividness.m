%% practice the main task
% contains all components and set at a relatively high visibility level,
% determined by the detection practice to lead to > 0.7 accuracy

function [R,C] = MainTask_simulateVividness(subID,orientations,vivDet,V)

% =========================================================================
% Setup
% =========================================================================
[w, rect] = setWindow(0);
HideCursor;




% output
output = fullfile(cd,'results',subID);
if ~exist(output,'dir'); mkdir(output); end
saveName = sprintf('PMT_%s.mat',subID);

% Trial numbers and order
nOri    = length(orientations);
% nMB     = 2; % mini-blocks

% [blocks,miniblocks] = blockStructure(nOri,nMB,nRep);
nBlocks = 4; % must be at least 4 to illustrate all possibilities!
nRep    = nBlocks/2;
trialsPerBlock = 24;
trials = zeros(nBlocks, trialsPerBlock); 
for iBlock = 1:nBlocks
    blockTrials = [ones(1,trialsPerBlock/2), zeros(1,trialsPerBlock/2)];
    trials(iBlock, :) = blockTrials(randperm(trialsPerBlock));
end

imaOri = [ones(1,nBlocks/4), ones(1,nBlocks/4)+1];
imaOri = [imaOri, imaOri];
blocks = imaOri';

NoiseLevels = [1 2 3 4];
NoiseLevels = repmat(NoiseLevels,1,nBlocks/4);
ImaginedVOnlyPerception = [zeros(1,nBlocks/2),ones(1,nBlocks/2)];

% ImaginedVOnlyPerception = ImaginedVOnlyPerception(randperm(numel(ImaginedVOnlyPerception)));

blocks(:,2)= ImaginedVOnlyPerception';
blocks(:,3)= NoiseLevels';


blocks = blocks(randperm(size(blocks,1)),:);

baseBlock = [ones(1, trialsPerBlock), ones(1, trialsPerBlock)*2];
perOri = repmat(baseBlock, 1, nBlocks / 2); % total length = 288



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

yesKey        = {'h','f'};
noKey         = {'j','d'};
vividnessKeys = {'a','s','d','f';'l','k','j','h'};
checkKeys     = {'k','l';'a','s'};

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

% Noise stimulus info
displayDuration = 2;                     % Duration of the stimulus in seconds
hz = Screen('NominalFrameRate', w);
ifi = 1/hz;                              % Refresh rate
nStepSize = 1;                           % 2 frames per step
nSteps = (displayDuration/ifi)/nStepSize;


frame_duration = ifi * nStepSize;

onset_time = 1.2;  
offset_time = 1.3; % onset + 0.1 seconds = 100 ms duration
onset_frame = round(onset_time / frame_duration);
offset_frame = round(offset_time / frame_duration);

cues = {'A','B'};

%% Instructon screen
[xCenter, yCenter] = RectCenter(rect);
[x_pix, ~] = Screen('WindowSize', w);
HideCursor;
% show instructions 1.
text = ['Now  for the main task, we will combine rating and detection together. \n ',...
    ['During half of the blocks you will only detect a grating WITHOUT imagining it \n' ...
    ' In these blocks, you have to indicate how clearly you could see the grating on each trial. \n '],...
    'During the other half of the blocks, you will also simultaneously imagine the grating that you are detecting in those blocks.  \n \n',...
    'In those blocks, you have to indicate how clear your mental image was. \n '];

if vivDet == 1 % first vividness
    text = [text 'After each trial, you will first indicate how vivid/visible your imagery/perception was \n and then whether the to-be-detected grating was presented.']
elseif vivDet == 2 % first detection
    text = [text 'After each trial, you will first indicate whether the to-be-detected grating was presented \n and then how vivid/visible your imagery/perception was.']
end

text = [text '\n \n ',...
    '[Press any key to continue] \n '];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);

vbl=Screen('Flip', w);
WaitSecs(1);
KbWait;

% show instructions 2.

text = ['One other important change is that each block, which hand you will use \n'...
    'to indicate imagery vividness\perception visibility and which hand to indicate presence, switches. \n'...
    'You will be informed at the start of each block which hand to use for what. \n'...
    'Your index finger will always indicate yes and high vividness. \n \n '];

text = [text '[Press any key to continue] \n '];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.75, [255 255 255]);

vbl=Screen('Flip', w);
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

%% Trials start

total_trial_counter = 1;

for iBlock = 1:nBlocks
    
    WaitSecs(fixTime);
    
    % instruction screen with gratings
    text = sprintf('This is block %d out of %d. \n \n',iBlock,nBlocks);
    if blocks(iBlock,2) == 1 %if it is an imagination block
    text = [text sprintf('During this block, you will be imagining grating %s (see below). \n',cues{blocks(iBlock,1)})];
    text = [text 'Please imagine this grating as vividly as possible during each trial, \n as if it was actually presented. \n \n'];
    else
    text = [text sprintf('During this block you will detect grating %s without imagining it. \n \n', cues{blocks(iBlock,1)})];
    text = [text 'Please do NOT imagine the grating during this block. \n \n'];
    end
    if responseMappings(iBlock) == 1 && blocks(iBlock,2) == 1 %if it is an imagination block
        text = [text 'You will use your left hand to indicate vividness \n and your right to indicate whether a stimulus was presented.'];
        RM = 1;
    elseif responseMappings(iBlock) == 2 && blocks(iBlock,2) == 1 %if it is an imagination block
        text = [text 'You will use your right hand to indicate vividness \n and your left to indicate whether a stimulus was presented.'];
        RM = 2;
    elseif responseMappings(iBlock) == 1 && blocks(iBlock,2) == 0 %if it is a perception-only block
        text = [text 'You will use your left hand to indicate visibility \n and right hand to indicate whether a stimulus was presented.'];
        RM = 1;
    elseif responseMappings(iBlock) == 2 && blocks(iBlock,2) == 0 %if it is a perception-only block
        text = [text 'You will use your right hand to indicate visibility \n and left hand to indicate whether a stimulus was presented.'];
        RM = 2;

    end
    text = [text '\n \n [Press any key to start] \n '];
    
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter*0.6, [255 255 255]);
    
    
    Screen('DrawTextures', w, gaborTexture{blocks(iBlock)}, [], centerRect, [],[], 0.5);
    DrawFormattedText(w, sprintf('Grating %s',cues{blocks(iBlock)}), xCenter*0.95, yCenter*1.2, [255 255 255]);
    

    vbl=Screen('Flip', w);
    WaitSecs(1);
    KbWait;
    
    % loop over miniblocks
    for iTrial = 1:trialsPerBlock
        
            % Fixation
            Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
                4, [0,0,0], [rect(3)/2, rect(4)/2], 1);
            vbl=Screen('Flip', w);
            WaitSecs(fixTime);
            
            if trials(iBlock,iTrial) == 1 % present trial
                % schedule of visibility gradient (i.e how visible at each frame)
                % Increases till most visible at the end
            schedule = zeros(1, nSteps);
%             schedule(onset_frame:offset_frame) = max(vis_scale(round(linspace(1,visibility,nSteps))));
                schedule(onset_frame:offset_frame) = vis_scale(visibility);
            else % Pure noise trial
                % 0 for entire schedule
                schedule = zeros(1,nSteps);
                schedule(onset_frame:offset_frame) = eps;
            end
            
            % Make the texture for each frame by combining the gabor with noise.
            % Rotates the annulus mask to hide the rotated boundary box around the
            % grating.
            target = {};
            for i_frame = 1:nSteps
                idx = ((i_frame-1)*nStepSize)+1:(i_frame*nStepSize);
                tmp = Screen('MakeTexture', w, ...
                 make_stimulus_differentNoises(orientations(blocks(iBlock,1)), schedule(i_frame), blocks(iBlock,3), i_frame));
                for i = 1:length(idx); target{idx(i)} = tmp; end
            end
            
            % =========================================================================
            % Presentation
            % =========================================================================
            
            % Present stimulus
            tini = GetSecs;
            for i_frame = 1:length(target)
                step_idx = ceil(i_frame / nStepSize);  % get current visibility step
                while GetSecs - tini < ifi * i_frame
            
                    Screen('DrawTextures', w, target{i_frame});
            
                    if schedule(step_idx) > 0
                        fix_color = [255, 255, 255];  % white fixation when stimulus visible
                    else
                        fix_color = [0, 0, 0];        % black fixation when stimulus invisible
                    end
            
                    Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], ...
                        4, fix_color, [rect(3)/2, rect(4)/2], 1);
            
                    vbl = Screen('Flip', w);
                end
            end

            
            if vivDet == 1 
                
                % Vividness rating first
                if blocks(iBlock,2) == 1
                text = 'How vividly did you imagine the grating? \n';
                else
                text = 'How vividly did you see the grating? \n';    
                end
                if RM == 2   % right hand 
                    text = [text '\n Less Vivid [RI] - More Vivid [RL]'];
                elseif RM == 1 
                    text = [text '\n Less Vivid [LL] - More Vivid [LI]'];
                end
                frames = 60;
                [rating, rt] = sliderRating_forNIMADET(w, text, xCenter*2, yCenter*2,RM,orientations(blocks(iBlock,1)), blocks(iBlock,3),frames,rect,visibility );

                R(iBlock, iTrial, vivRating) = rating;
                R(iBlock, iTrial, vivRT) = rt;
                
                
                % Detection
                text = 'Was there a grating on the screen? \n';
                if RM == 1 % right hand
                    text = [text 'Yes [RI] or no [RM]'];
                else
                    text = [text 'No [LM] or yes [LI]'];
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
                            WaitSecs(0.5);u
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
            
                
            elseif vivDet == 2 
                
                % Detection first
                text = 'Was there a grating on the screen? \n';
                if RM == 1 % right hand
                    text = [text 'Yes [RI] or no [RM]'];
                else
                    text = [text 'No [LM] or yes [LI]'];
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
                                % Vividness rating first
                if blocks(iBlock,2) == 1
                text = 'How vividly did you imagine the grating? \n';
                else
                text = 'How vividly did you see the grating? \n';    
                end
                if RM == 2   % right hand 
                    text = [text '\n Less Vivid [RI] - More Vivid [RL]'];
                elseif RM == 1 
                    text = [text '\n Less Vivid [LL] - More Vivid [LI]'];
                end
                 frames = 60;
                [rating, rt] = sliderRating_forNIMADET(w, text, xCenter*2, yCenter*2,RM,orientations(blocks(iBlock,1)), blocks(iBlock,3),frames,rect, visibility );

                R(iBlock, iTrial, vivRating) = rating;
                R(iBlock, iTrial, vivRT) = rt;
            end
            
            % Inter trial interval
            Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0],...
                4, [255,255,255], [rect(3)/2, rect(4)/2], 1);
            Screen('Flip', w);
            WaitSecs(ITIs(total_trial_counter,iTrial));
            
            % Close all textures to free memory
            tmp = unique(cell2mat(target));
            for i_tex = 1:length(tmp)
                Screen('Close', tmp(i_tex));
            end
            
        end
        
        % update miniblock counter
        total_trial_counter = total_trial_counter+1;
    
    
    if blocks(iBlock,2) == 1
        % Imagery check
        text = 'CHECK! Which grating did you imagine this block? \n';
        if RM == 1 % Right hand
            text = [text 'Grating A [RR] or Grating B [RP]'];
        else
            text = [text 'Grating A [LP] or Grating B [LR]'];
        end
    Screen('TextSize',w, 28);
    DrawFormattedText(w, text, 'center', yCenter, [255 255 255]);
    
    Screen('DrawTextures', w, gaborTexture{1}, [], allRects(:,1), [],[], 0.5);
    DrawFormattedText(w, 'Grating A', xCenter*(1.8/3), yCenter*1.2, [255 255 255]);
    
    Screen('DrawTextures', w, gaborTexture{2}, [], allRects(:,2), [],[], 0.5);
    DrawFormattedText(w, 'Grating B', xCenter*(3.8/3), yCenter*1.2, [255 255 255]);
    
    vbl=Screen('Flip', w);
    
    
    % log response
    keyPressed = 0; % clear previous response
    while ~keyPressed
        
        [~, keyTime, keyCode] = KbCheck(-3);
        key = KbName(keyCode);
        
        if ~iscell(key) % only start a keypress if there is only one key being pressed
            if any(strcmp(key, checkKeys(RM,:)))
                
                % fill in response
                checkResponse = find(strcmp(key,checkKeys(RM,:))); % 1 to 2
                if checkResponse == blocks(iBlock) % correct
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
    vbl = Screen('Flip', w);
    KbWait;
    end
end

save(fullfile(output,saveName)); % save everything


Screen('TextSize',w, 28);
DrawFormattedText(w, 'This is the end of the experiment!', 'center', 'center', [255 255 255]);
vbl = Screen('Flip', w);
WaitSecs(2);
Screen('CloseAll')
sca;
