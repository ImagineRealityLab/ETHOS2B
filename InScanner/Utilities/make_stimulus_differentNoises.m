function stimulus = make_stimulus_differentNoises(orientation,vis_level,noise_pattern)

% orientation = Orientation of the grating that you want to use
% vis_level = visibility that you want to use
% noiseNo = particular noise pattern that you want to put (default is
% between 1-4 but you can create more/less via addDifferentNoise function)
% frame = frame per second based on the experiment monitor
% Originally written by Nadine Dijkstra, adapted by Ataol Burak Ozsu,
% Imagine Reality Lab, 2025

%%% --- Create the basic Gabors --- %%%
% rotation
rotAngle = -1 * (orientation+90);

% Gabor grating details
contrast = 1;
phase = 0;
spatialFrequency = 0.7;
gratingSizeDegrees = 5;
innerDegree = 0; %gratingSizeDegrees/15;

% Makes square gabor then masks with an outer and inner annulus to create a
% circular gabor with a hole for a fixation cross. Rotates the gabor to the
% desired angle.
[gaborPatch,~,annulusMatrix] = makeGabor(contrast, gratingSizeDegrees,...
    phase,spatialFrequency,innerDegree, rotAngle);

%%% --- Add noise to gabor --- %%%
if vis_level < 1 && nargin <3
    stimulus = addDifferentNoise(gaborPatch, vis_level, annulusMatrix);
elseif vis_level <1 && nargin == 3
    stimulus = addDifferentNoise(gaborPatch, vis_level, annulusMatrix,noise_pattern);
else
    stimulus = gaborPatch;
end
