function [volume] = soundCheck(orientations,deviceToUse)


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
    y2 = [y2,y2];
    y3 = [y3,y3];
    y0 = [y0,y0];
end
wavedata2 = y2';
wavedata3 = y3';
wavedata0 = y0';

% Open port
InitializePsychSound;
pahandle = PsychPortAudio('Open', deviceToUse, [], 1, freq1, 2);

% Open PTB window
[w, rect] = setWindow(0);
HideCursor;

% =========================================================================
% Stimuli
% =========================================================================
nOri = length(orientations);
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


%% Instructon screen
[~, yCenter] = RectCenter(rect);
[~, ~] = Screen('WindowSize', w);
HideCursor;

% explain finger placement
text = ['Before we start to the experiment we will ask you to adjust the volume to a level that you are comfortable with. \n ' ...
    'On the next screen, we will play a tone and you can adjust the volume by using up and down arrow keys. \n\n' ...
    '[Press [1] to continue]'];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.65, [255 255 255]);
Screen('Flip', w);
WaitSecs(2);
KbWait;

% Initial volume (0–1)
volume = 0.3;
minVol = 0.01;
maxVol = 0.99;
volStep = 0.02;

PsychPortAudio('Volume', pahandle, volume);

% Use a clearly audible reference sound
PsychPortAudio('FillBuffer', pahandle, wavedata2);
PsychPortAudio('Start', pahandle, 0, 0, 1); % loop indefinitely

adjusting = true;

while adjusting
    text = sprintf([ ...
        'Sound check\n\n' ...
        'Use UP / DOWN arrows to adjust volume\n' ...
        'Press SPACE when the volume is comfortable\n\n' ...
        'Current volume: %.2f'], volume);

    Screen('TextSize', w, 28);
    DrawFormattedText(w, text, 'center', 'center', [255 255 255]);
    Screen('Flip', w);
    


    [keyDown, ~, keyCode] = KbCheck;

    if keyDown
        if keyCode(KbName('UpArrow'))
            volume = min(volume + volStep, maxVol);
            PsychPortAudio('Volume', pahandle, volume);
            KbReleaseWait;

        elseif keyCode(KbName('DownArrow'))
            volume = max(volume - volStep, minVol);
            PsychPortAudio('Volume', pahandle, volume);
            KbReleaseWait;

        elseif keyCode(KbName('space'))
            adjusting = false;
            KbReleaseWait;
        end
    end
end

PsychPortAudio('Stop', pahandle);

% Optional confirmation screen
DrawFormattedText(w, 'Volume set.\n\n [Press any key to continue]', ...
    'center', 'center', [255 255 255]);
Screen('Flip', w);
WaitSecs(1);
KbWait;

% explain finger placement
text = ['Now, we will play two sounds consecutively and will ask you to report \n' ...
    'which sound is higher in pitch. \n \n' ...
    '[Press any key to listen to the sounds.]'];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.65, [255 255 255]);
Screen('Flip', w);
WaitSecs(1);
KbWait;

correctAnswer = 1;      % first sound is always correct
responseCorrect = false;

while ~responseCorrect

    % --- Play the two sounds again ---
    % Sound 1
    PsychPortAudio('FillBuffer', pahandle, wavedata3);
    PsychPortAudio('Start', pahandle, 1, 0, 1); % wait for finish
    WaitSecs(1);
    PsychPortAudio('Stop', pahandle);

    WaitSecs(2);

    % Sound 2
    PsychPortAudio('FillBuffer', pahandle, wavedata0);
    PsychPortAudio('Start', pahandle, 1, 0, 1); % wait for finish
     WaitSecs(1);
    PsychPortAudio('Stop', pahandle);

   

    % --- Ask discrimination question ---
    questionText = ['Which sound was higher in pitch?\n\n' ...
                    '1 = First sound    |    2 = Second sound\n\n' ...
                    '[Press 1 or 2]'];

    DrawFormattedText(w, questionText, 'center', 'center', [255 255 255]);
    Screen('Flip', w);

    % --- Get response ---
    validKeys = [KbName('1!'), KbName('2@')];
    responseGiven = false;

    while ~responseGiven
        [keyDown, ~, keyCode] = KbCheck;
        if keyDown
            key = find(keyCode, 1);

            if any(key == validKeys)
                if key == KbName('1!')
                    pitchChoice = 1;
                else
                    pitchChoice = 2;
                end
                responseGiven = true;
            end
            KbReleaseWait;
        end
    end

    % --- Evaluate response ---
    if pitchChoice == correctAnswer
        responseCorrect = true;
    else
        % Feedback screen for incorrect answer
        feedbackText = ['That was incorrect.\n\n' ...
                        'Try again.\n\n' ...
                        '[Press any key to hear the sounds again.]'];

        DrawFormattedText(w, feedbackText, 'center', 'center', [255 255 255]);
        Screen('Flip', w);
        KbWait;
        KbReleaseWait;
    end

end

Screen('TextSize',w, 28);
DrawFormattedText(w, 'Correct! This is the end of the sound check! \n\n', 'center', 'center', [255 255 255]);
Screen('Flip', w);
WaitSecs(3)
Screen('CloseAll')
sca;

