function [ stimulus ] = addDifferentNoise(image, p, mask, NoiseNo, frame)
% ADDDIFFERENTNOISE - Adds evolving noise to a grayscale image with masking
% INPUTS:
%   image   - RGB input image
%   p       - proportion of pixels to retain from original image (0 to 1)
%   mask    - binary or grayscale mask (same size as image)
%   NoiseNo - integer from 1 to 4 (defines noise class/type)
%   frame   - frame number (optional, adds variability within each NoiseNo)
% OUTPUT:
%   stimulus - noisy RGB image

    % Convert image to contrast-normalized grayscale
    if nargin < 5
        frame = 1; % Default to first frame if not provided
    end

    % Convert image to contrast-normalized grayscale
    bw_image = mean(image, 3);
    [~, I] = sort(bw_image(:));
    bw_image(I) = linspace(0, 255, numel(I));
    image = bw_image;

    % Set RNG seed based on NoiseNo and frame
    seed = NoiseNo * 1000 + frame;  % Ensures different noise per frame but tied to NoiseNo
    rng(seed);

    % Generate evolving noise based on seeded RNG
    staticNoise = 255 * rand(size(image));

    % Create probability mask
    p_mask = p * ones(size(image));
    p_mask = p_mask .* mask(:, :, 1); % use 1st channel if 3D

    % Binary mask for retaining original image
    take_image_value = binornd(1, p_mask) > 0;

    % Combine image and noise
    staticNoise(take_image_value) = image(take_image_value);

    % Convert to RGB
    stimulus = repmat(staticNoise, 1, 1, 3);