function [rating, RT] = sliderRating_forNIMADET(w, questionText, screenXpixels, screenYpixels, RM, orientation, NoiseNo, nFrames,rect, V)
% Displays a live Gabor + noise stimulus that updates with slider input

% Set slider parameters
vis_scale = [0 logspace(log10(0.005),log10(0.2),299)]; % steps in log space
sliderMin = 0;
sliderMax = vis_scale(V);
sliderStart = (sliderMax-sliderMin) / 2;
sliderValue = sliderStart;

sliderLength = screenXpixels * 0.5;
sliderX0 = screenXpixels / 2 - sliderLength / 2;
sliderY = screenYpixels * 0.9;
handleRadius = 10;

% Key mapping
if RM == 2
    keyLeft = 'h'; keyRight = 'l';
else
    keyLeft = 'a'; keyRight = 'f';
end

% Prepare text
Screen('TextSize', w, 28);
DrawFormattedText(w, questionText, 'center', screenYpixels * 0.3, 255);
vbl = Screen('Flip', w);
tStart = vbl;

% Main loop
confirmed = false;
frame = 1;
ifi = Screen('GetFlipInterval', w);
vbl = Screen('Flip', w);  % initialize timing

while ~confirmed
    % --- Loop noise frames dynamically ---
    frameInLoop = mod(frame - 1, nFrames) + 1;
    
    % Generate stimulus
    stim = make_stimulus_differentNoises(orientation, sliderValue, NoiseNo, frameInLoop);
    tex = Screen('MakeTexture', w, stim);

    % Draw stimulus
    Screen('DrawTexture', w, tex, [], []);
    
    % Draw question
    DrawFormattedText(w, questionText, 'center', screenYpixels * 0.3, 255);

    % Draw slider
    Screen('DrawLine', w, 255, sliderX0, sliderY, sliderX0 + sliderLength, sliderY, 2);
    handleX = sliderX0 + (sliderValue / (sliderMax - sliderMin)) * sliderLength;
    Screen('FillOval', w, [255 0 0], ...
        [handleX - handleRadius, sliderY - handleRadius, handleX + handleRadius, sliderY + handleRadius]);

    Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], ...
                        4, 255, [rect(3)/2, rect(4)/2], 1);

    % Flip to screen
    vbl = Screen('Flip', w, vbl + 0.5 * ifi);
    Screen('Close', tex); % cleanup texture

    % Keyboard input
    [~, keyTime, keyCode] = KbCheck(-3);
    if any(keyCode)
        key = KbName(keyCode);
        if iscell(key), key = key{1}; end

        switch key
            case keyLeft
                sliderValue = max(sliderMin, sliderValue - vis_scale(V)/100);
            case keyRight
                sliderValue = min(sliderMax, sliderValue + vis_scale(V)/100);
            case 'space'
                confirmed = true;
                rating = sliderValue;
                RT = keyTime - tStart;
            case 'ESCAPE'
                Screen('CloseAll');
                error('Experiment aborted by user.');
        end
    end

    frame = frame + 1;  % increment for looping
end
end
