function [ stimulus ] = addDifferentNoise(image, p, mask, noisePattern)
% ADDDIFFERENTNOISE - Adds evolving noise to a grayscale image with masking
% INPUTS:
%   image   - RGB input image
%   p       - proportion of pixels to retain from original image (0 to 1)
%   mask    - binary or grayscale mask (same size as image)
%   NoiseNo - integer from 1 to 4 (defines noise class/type)
%   frame   - frame number (optional, adds variability within each NoiseNo)
% OUTPUT:
%   stimulus - noisy RGB image

% Originally written by Nadine Dijkstra, adapted by Ataol Burak Ozsu,
% Imagine Reality Lab, 2025


% Convert image to contrast-normalized grayscale
bw_image = mean(image, 3);
[~, I] = sort(bw_image(:));
bw_image(I) = linspace(0, 255, numel(I));
image = bw_image;

% Create probability mask
p_mask = p * ones(size(image));
p_mask = p_mask .* mask(:, :, 1); % use 1st channel if 3D

take_image_value = rand(size(p_mask)) < p_mask;

% Combine image and noise
if nargin == 4
noisePattern(take_image_value) = image(take_image_value);
elseif nargin == 3
noisePattern = 255 * rand(size(image));
noisePattern(take_image_value) = image(take_image_value);
end

% Convert to RGB
stimulus = repmat(noisePattern, 1, 1, 3);