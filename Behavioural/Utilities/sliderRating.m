function [rating, RT] = sliderRating(w, questionText, screenXpixels, screenYpixels, RM)
% SLIDERRATING Displays a slider rating scale and returns user input
%
% Inputs:
%   - w: Psychtoolbox window pointer
%   - questionText: text prompt to display
%   - screenXpixels, screenYpixels: screen dimensions
%   - RM: response mapping (1 = left-hand: 'a'/'f', 2 = right-hand: 'h'/'l')
%
% Outputs:
%   - rating: selected value from 0 to 100
%   - RT: reaction time in seconds

% Set slider parameters
sliderMin = 0;
sliderMax = 100;
sliderStart = 50;
sliderValue = sliderStart;

sliderLength = screenXpixels * 0.5;
sliderX0 = screenXpixels / 2 - sliderLength / 2;
sliderY = screenYpixels * 0.6;
handleRadius = 10;

% Determine control keys based on RM
if RM == 2
    keyLeft = 'h'; % lower judgment
    keyRight = 'l'; % increase judgment
else
    keyLeft = 'a';
    keyRight = 'f';
end

% Set text size
Screen('TextSize', w, 28);

% Initial draw
DrawFormattedText(w, questionText, 'center', screenYpixels * 0.3, 255);
vbl = Screen('Flip', w);
tStart = vbl;

% Wait for confirmed input
confirmed = false;
while ~confirmed
    % Draw question and slider
    DrawFormattedText(w, questionText, 'center', screenYpixels * 0.3, 255);
    Screen('DrawLine', w, 255, sliderX0, sliderY, sliderX0 + sliderLength, sliderY, 2);
    handleX = sliderX0 + (sliderValue / (sliderMax - sliderMin)) * sliderLength;
    Screen('FillOval', w, [255 0 0], ...
        [handleX - handleRadius, sliderY - handleRadius, handleX + handleRadius, sliderY + handleRadius]);

    Screen('Flip', w);

    

    % Keyboard input
    [~, keyTime, keyCode] = KbCheck(-3);
    if any(keyCode)
        key = KbName(keyCode);
        if iscell(key), key = key{1}; end

        switch key
            case keyLeft
                sliderValue = max(sliderMin, sliderValue - 1);
            case keyRight
                sliderValue = min(sliderMax, sliderValue + 1);
            case 'space'
                confirmed = true;
                rating = sliderValue;
                RT = keyTime - tStart;
            case 'ESCAPE'
                Screen('TextSize', w, 28);
                DrawFormattedText(w, 'Experiment was aborted!', 'center', 'center', [255 255 255]);
                Screen('Flip', w);
                WaitSecs(0.5);
                ShowCursor;
                Screen('CloseAll');
                error('Experiment aborted by user.');
        end
    end
end
end
