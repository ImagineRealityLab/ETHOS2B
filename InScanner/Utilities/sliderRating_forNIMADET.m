function [rating, RT] = sliderRating_forNIMADET(w, questionText, screenXpixels, screenYpixels, RM, orientation, rect, V, lowerBoundText, upperBoundText)
% Displays a live Gabor + noise stimulus that updates with slider input
% w = the active window in PTB
% questionText = a string that you want to display on the screen
% screenXpixels = length of your screen, x axis, can be acquired via PTB functions
% screenYpixels = length of your screen, y axis, can be acquired via PTB functions
% RM = which keys to be used, adjust according to your project: (see
% between line 24-28)
% orientation = orientation of the grating to be reproduced 
% NoiseNo = the particular noise pattern that you want to put onto the
% grating
% nFrames = number of frames per second
% rect = a rectangular area that you want your slider to appear
% V = visibility of the grating
% Ataol Burak Ozsu, Imagine Reality Lab, 2025

% Set slider parameters

V = max(V,299);
vis_scale = [0 logspace(log10(0.005),log10(0.2),299)]; % steps in log space
sliderMin = 0;
sliderMax = vis_scale(V);
rng('shuffle');
sliderValue = (sliderMax - sliderMin) / 2;
visualValue = sliderValue;

sliderLength = screenXpixels * 0.5;
sliderX0 = screenXpixels / 2 - sliderLength / 2;
sliderY = screenYpixels * 0.65;
handleRadius = 10;

% Key mapping

keyLeft = 'd'; keyRight = 'f';





% Main loop
confirmed = false;
frame = 1;
ifi = Screen('GetFlipInterval', w);
vbl = Screen('Flip', w);  % initialize timing
tStart = vbl;

while ~confirmed
  
    % Generate stimulus
    stim = make_stimulus_differentNoises(orientation, sliderValue);
    tex = Screen('MakeTexture', w, stim);

    % Draw stimulus
    Screen('DrawTexture', w, tex, [], []);
    
    % Draw question
    DrawFormattedText(w, questionText, 'center', screenYpixels * 0.35, 255);
    DrawFormattedText(w, lowerBoundText, sliderX0, (screenYpixels * 0.65)-20, 255);
    DrawFormattedText(w, upperBoundText, sliderX0 + sliderLength - 130, (screenYpixels * 0.65) - 20, 255);

    % Draw slider
    Screen('DrawLine', w, 255, sliderX0, sliderY, sliderX0 + sliderLength, sliderY, 2);
    handleX = sliderX0 + (visualValue / (sliderMax - sliderMin)) * sliderLength;
    Screen('FillOval', w, [255 0 0], ...
        [handleX - handleRadius, sliderY - handleRadius, handleX + handleRadius, sliderY + handleRadius]);

    Screen('DrawLines', w, [0 0 -10 10; -10 10 0 0], ...
                        4, 0, [rect(3)/2, rect(4)/2], 1);
    tickHeight = 10; % pixels (adjust for your display)
    Screen('DrawLine', w, 255, ...
        sliderX0, sliderY - tickHeight / 2, sliderX0, sliderY + tickHeight / 2, 2); % Left tick
    Screen('DrawLine', w, 255, ...
        sliderX0 + sliderLength, sliderY - tickHeight / 2, ...
        sliderX0 + sliderLength, sliderY + tickHeight / 2, 2); % Right tick
    vbl = Screen('Flip',w,vbl+0.5 *ifi);
    Screen('Close',tex)
   

    % Keyboard input
    [~, keyTime, keyCode] = KbCheck(-3);
    if any(keyCode)
        key = KbName(keyCode);
        if iscell(key), key = key{1}; end

    switch key
    case keyLeft
        % Always move handle visually left
        visualValue = max(sliderMin, visualValue - vis_scale(V)/50);

        % Adjust vividness meaning (sliderValue) depending on RM
        if RM == 1
            sliderValue = visualValue;  % normal mapping
        else
            sliderValue = sliderMax - visualValue;  % reversed meaning
        end

    case keyRight
        % Always move handle visually right
        visualValue = min(sliderMax, visualValue + vis_scale(V)/50);

        % Adjust vividness meaning depending on RM
        if RM == 1
            sliderValue = visualValue;  % normal mapping
        else
            sliderValue = sliderMax - visualValue;  % reversed meaning
        end

    case 'space'
        WaitSecs(0.0020);

        confirmed = true;
        rating = sliderValue;   % this now encodes vividness correctly
        RT = keyTime - tStart;

    case 'ESCAPE'
        Screen('CloseAll');
        error('Experiment aborted by user.');
    end
    end

    frame = frame + 1;  % increment for looping
end
end
