%% --- Parameters ---------------------------------------------------------
nPatches = 10000;                  % number of noise patches to generate
nSelect = 4;                      % number of low-energy patches to select
gratingSizeDegrees = 5;           
orientations = [45, 135];         % orientations used in the exp
contrast = 1;
phase = 0;
spatialFrequency = 0.7;           % cycles/degree
innerDegree = 0;
p = 0;                            % proportion of original image (0 = pure noise)

saveDir = fullfile(pwd, 'SelectedNoisePatches');
if ~exist(saveDir, 'dir')
    mkdir(saveDir);
end

fprintf('--- Generating all gratings  ---\n');
gaborBank = cell(1, numel(orientations));
for j = 1:numel(orientations)
    [gaborPatch, ~, ~] = makeGabor(contrast, gratingSizeDegrees, ...
        phase, spatialFrequency, innerDegree, orientations(j));
    gaborPatch = double(gaborPatch) - mean(gaborPatch(:));
    gaborBank{j} = gaborPatch ./ sqrt(sum(gaborPatch(:).^2) + eps);
end

imSize = size(gaborBank{1}, 1);

fprintf('--- Generating %d noise patches and computing mean orientation energy ---\n', nPatches);
meanEnergies = zeros(nPatches, 1);

for i = 1:nPatches
    NoiseNo = i;  
    
    % Create base image and mask
    dummyImage = zeros(imSize, imSize, 3);
    mask2D = ones(size(dummyImage,1), size(dummyImage,2));
    mask = repmat(mask2D, 1, 1, 3);
    
    % Generate noise patch
    noisePatch = addNoise_changed(dummyImage, p, mask, NoiseNo);
    noiseGray = mean(noisePatch, 3);             % convert to grayscale
    noiseGray = double(noiseGray);
    noiseGray = noiseGray - mean(noiseGray(:));  % zero-mean
    noiseGray = noiseGray / (std(noiseGray(:)) + eps);  % unit variance

    % Compute energy per orientation
    energiesPerOrientation = zeros(1, numel(orientations));
    for j = 1:numel(orientations)
        resp = conv2(noiseGray, gaborBank{j}, 'same');
        energiesPerOrientation(j) = mean(resp(:).^2);
    end

    % Average energy across orientations
    meanEnergies(i) = mean(energiesPerOrientation);
end

%% --- Select lowest-energy patches --------------------------------------
[~, idxSorted] = sort(meanEnergies, 'ascend');  % ascending = lowest energy first
selectedIdx = idxSorted(1:nSelect);

fprintf('Selected %d lowest-energy patches\n', nSelect);

%% --- Regenerate and save selected patches --------------------------------
fprintf('--- Saving selected low-energy noise patches ---\n');
for k = 1:nSelect
    NoiseNo = selectedIdx(k);
    dummyImage = zeros(imSize, imSize, 3);
    mask2D = ones(imSize, imSize);
    mask = repmat(mask2D, 1, 1, 3);
    
    noisePatch = addNoise_changed(dummyImage, p, mask, NoiseNo);
    noiseGray = mean(noisePatch, 3);
    
    save(fullfile(saveDir, sprintf('lowEnergyNoise_%02d.mat', k)), 'noiseGray');
end

fprintf('Done! %d patches saved to %s\n', nSelect, saveDir);

%% --- Optional visualization --------------------------------------------
figure;
for k = 1:nSelect
    load(fullfile(saveDir, sprintf('lowEnergyNoise_%02d.mat', k)), 'noiseGray');
    subplot(1,nSelect,k);
    imagesc(noiseGray); colormap gray; axis image off;
    title(sprintf('Patch %d', k));
end
