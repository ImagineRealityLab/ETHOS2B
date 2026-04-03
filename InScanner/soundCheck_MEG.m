function [volume] = soundCheck_MEG(orientations,deviceToUse)


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

pahandle = PsychPortAudio('Open', deviceToUse, [], 1, freq1, 2);

[w, rect] = setWindow(1);
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
    gaborPatch{iOri} = make_stimulus(orientations(iOri),0.3,1);
    % texture
    gaborTexture{iOri} = Screen('MakeTexture',w,gaborPatch{iOri});
end

gaborPatchFullVis   = cell(nOri,1);
gaborTextureFullVis = cell(nOri,1);
for iOri = 1:nOri
    % stimulus
    gaborPatchFullVis{iOri} = make_stimulus(orientations(iOri),1,1);
    % texture
    gaborTextureFullVis{iOri} = Screen('MakeTexture',w,gaborPatchFullVis{iOri});
end

gaborPatchNoVis  = cell(nOri,1);
gaborTextureNoVis= cell(nOri,1);
for iOri = 1:nOri
    % stimulus
    gaborPatchNoVis{iOri} = make_stimulus(orientations(iOri),eps,1);
    % texture
    gaborTextureNoVis{iOri} = Screen('MakeTexture',w,gaborPatchNoVis{iOri});
end


%% Instructon screen
[~, yCenter] = RectCenter(rect);
[~, ~] = Screen('WindowSize', w);
HideCursor;

% explain finger placement
text = ['Welcome! Before we get started, we will do a final check on the key configuration. \n' ...
    'Please ensure that your left ring finger/right index finger are on the yellow buttons, \n' ...
    'your both middle fingers are on the green buttons, and your right ring and left index are on the red buttons. \n\n'...
    'Throughout the experiment, which buttons you will use will be described as hand + finger. \n' ...
    'For instance, LR refers to your left ring, RI refers to your right index, and RM refers your right middle. \n\n' ...
    '[Press any key to continue]'];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.65, [255 255 255]);
Screen('Flip', w);
WaitSecs(1);
KbWait;

% explain finger placement
text = ['As you have done before, you will hear some sounds during the experiment! \n' ...
    'Now, we will ask you to adjust the volume of the sounds to the level that you are comfortable with. \n' ...
    'Please let the experimenter know when you think the volume level is set! \n \n' ...
    '[Press any key to continue]'];

Screen('TextSize',w, 28);
DrawFormattedText(w, text, 'center', yCenter*0.65, [255 255 255]);
Screen('Flip', w);
WaitSecs(1);
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
        'Use [LR] / [LI] arrows to adjust volume\n' ...
        'Let the experimenter know when you are ready!\n\n' ...
        'Current volume: %.2f'], volume);

    Screen('TextSize', w, 28);
    DrawFormattedText(w, text, 'center', 'center', [255 255 255]);
    Screen('Flip', w);
    

    [keyDown, ~, keyCode] = KbCheck;

    if keyDown
        if keyCode(KbName('7&'))
            volume = min(volume + volStep, maxVol);
            PsychPortAudio('Volume', pahandle, volume);
            KbReleaseWait;

        elseif keyCode(KbName('9('))
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
DrawFormattedText(w, 'Volume set.\n\n[Press any key to continue]', ...
    'center', 'center', [255 255 255]);
Screen('Flip', w);
KbWait;


text = [
    'Now, we will play two sounds consecutively and will ask you to report' ...
    'which sound is higher in pitch. \n You should press [LR] if the first sound is higher in pitch, and [LI] if the second one is higher in pitch! \n \n' ...
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
                    '[LR] = First sound    |    [LI] = Second sound\n\n'];

    DrawFormattedText(w, questionText, 'center', 'center', [255 255 255]);
    Screen('Flip', w);

    % --- Get response ---
    validKeys = [KbName('7&'), KbName('9(')];
    responseGiven = false;

    while ~responseGiven
        [keyDown, ~, keyCode] = KbCheck;
        if keyDown
            key = find(keyCode, 1);

            if any(key == validKeys)
                if key == KbName('7&')
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
                        'Let’s try again.\n\n' ...
                        '[Press any key to hear the sounds again.]'];

        DrawFormattedText(w, feedbackText, 'center', 'center', [255 255 255]);
        Screen('Flip', w);
        KbWait;
        KbReleaseWait;
    end

end

Screen('TextSize',w, 28);
DrawFormattedText(w, 'Correct! This is the end of the sound check!', 'center', 'center', [255 255 255]);
vbl = Screen('Flip', w);
WaitSecs(2);
Screen('CloseAll')
sca;