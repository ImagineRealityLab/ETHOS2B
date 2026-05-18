clear
clc
close all

addpath("Utilities")
addpath(genpath("MVPA-Light-master"))
addpath("behavioural\")

seed = 42;
rng(seed)

%% Load MEG
meg_data = load("results\subj-1\Preprocessed_ICAclean_realigned.mat");
meg_data = meg_data.data_ica_clean;

cfg = [];
cfg.channel = 'MEG';
meg_all = ft_selectdata(cfg, meg_data);

%% Rejected trials
rejection_hist = load("results\subj-1\rejection_log.mat");
rejection_hist = rejection_hist.rejection_log;

allRejectedTrials = [];
for iRun = 1:8
    allRejectedTrials = [allRejectedTrials, rejection_hist(1,iRun).trials_removed];
end

%% Behavioural data
beh_data = load("PMT_10.mat");

block_info    = beh_data.blocks;
trial_info    = beh_data.trials;
response_info = beh_data.R;

cond         = block_info(:,2);     % imagery/perception
presence     = trial_info(:,:,1);
detection    = response_info(:,:,3);
reproduction = response_info(:,:,1);   % vividness / reproduction measure
grating      = block_info(:,1);

nRuns  = size(block_info,1) / 2;
nTrial = size(presence,2);

% Expand block variables to trial level
conditionPerTrial = repmat(cond,1,nTrial);
oriPerTrial       = repmat(grating,1,nTrial);
runPerTrial       = repmat((1:nRuns)',1,nTrial);

allRuns = [];
for iRun = 1:nRuns
    allRuns = [allRuns; runPerTrial(iRun,:); runPerTrial(iRun,:)];
end

% Flatten
meta.condition    = reshape(conditionPerTrial',[],1);
meta.orientation  = reshape(oriPerTrial',[],1);
meta.presence     = reshape(presence',[],1);
meta.detection    = reshape(detection',[],1);
meta.reproduction = reshape(reproduction',[],1);
meta.run          = reshape(allRuns',[],1);

% Remove rejected trials
nTotalTrials = length(meta.condition);
keepMask = true(nTotalTrials,1);
keepMask(allRejectedTrials) = false;

meta.condition    = meta.condition(keepMask);
meta.orientation  = meta.orientation(keepMask);
meta.presence     = meta.presence(keepMask);
meta.detection    = meta.detection(keepMask);
meta.reproduction = meta.reproduction(keepMask);
meta.run          = meta.run(keepMask);

%% Time-frequency decomposition
cfg = [];
cfg.output     = 'pow';
cfg.channel    = 'MEG';
cfg.method     = 'mtmconvol';
cfg.taper      = 'hanning';
cfg.keeptrials = 'yes';

cfg.foi        = 1:1:80;
cfg.toi        = -0.95:0.05:0.4;      % extend if you want figure like the example
cfg.t_ftimwin  = 5 ./ cfg.foi;        % 5 cycles/frequency

freq = ft_freqanalysis(cfg, meg_all);


%% Check trial count alignment
nMegTrials  = size(freq.powspctrm, 1);
nMetaTrials = length(meta.condition);

fprintf('MEG trials: %d\n', nMegTrials);
fprintf('Meta trials: %d\n', nMetaTrials);

if nMegTrials ~= nMetaTrials
    error('Number of MEG trials and metadata trials do not match after rejection handling.');
end

%% Select imagery trials only
% Replace ==1 with the correct imagery code if needed
imgMask = meta.condition == 1;

imgVividness = meta.reproduction(imgMask);

% Percentile split WITHIN imagery trials
hvThresh = prctile(imgVividness, 75);
lvThresh = prctile(imgVividness, 25);

trialsHVIMG = imgMask & meta.reproduction >= hvThresh;
trialsLVIMG = imgMask & meta.reproduction <= lvThresh;

trialsPresent = meta.detection == 1;
trialsAbsent = meta.detection == 0;

imgFalseAlarms = imgMask & meta.detection == 1 & meta.presence == 0;
imgCR = imgMask & meta.detection == 0 & meta.presence == 0;


fprintf('High-vividness imagery trials: %d\n', sum(trialsHVIMG));
fprintf('Low-vividness imagery trials: %d\n', sum(trialsLVIMG));

%% Choose channels
% Option 1: average across all MEG channels
chanIdx = 1:length(freq.label);

% Option 2: choose a subset manually, e.g. posterior sensors
% chanIdx = match_str(freq.label, {'MLO11','MLO12','MRO11','MRO12'});

%% Extract data
pow = freq.powspctrm;   % trials x channels x freqs x time

powHV = pow(trialsHVIMG, chanIdx, :, :);
powLV = pow(trialsLVIMG, chanIdx, :, :);

% Average over trials (dim 1) and channels (dim 2), keep freq x time
powHV_mean = squeeze(mean(mean(powHV, 1), 2));   % should be freqs x time
powLV_mean = squeeze(mean(mean(powLV, 1), 2));

powPresent = pow(trialsPresent, chanIdx, :, :);
powAbsent = pow(trialsAbsent, chanIdx, :, :);

powPresent_mean = squeeze(mean(mean(powPresent, 1), 2));
powAbsent_mean = squeeze(mean(mean(powAbsent, 1), 2));

powImgFA = pow(imgFalseAlarms, chanIdx, :, :);
powImgCR = pow(imgCR, chanIdx, :, :);

powImgFA_mean = squeeze(mean(mean(powImgFA, 1), 2));
powImgCR_mean = squeeze(mean(mean(powImgCR, 1), 2));

% --- Safety check: ensure orientation is freqs x time ---
if size(powHV_mean, 1) == length(freq.time) && size(powHV_mean, 2) == length(freq.freq)
    warning('powHV_mean appears transposed — fixing automatically.');
    powHV_mean = powHV_mean';
    powLV_mean = powLV_mean';
end

fprintf('powHV_mean size: %d x %d (should be %d freqs x %d times)\n', ...
    size(powHV_mean,1), size(powHV_mean,2), length(freq.freq), length(freq.time));

alphaCond = freq.freq > 8 & freq.freq < 13 ; 

alphaPowHV_mean = powHV_mean(alphaCond, :);
alphaPowLV_mean = powLV_mean(alphaCond, :);
powDiffAlphaViv = alphaPowHV_mean - alphaPowLV_mean;   % freqs x time

alphaPresent_mean = powPresent_mean(alphaCond, :);
alphaAbsent_mean = powAbsent_mean(alphaCond, :);
powDiffAlphaResp = alphaPresent_mean - alphaAbsent_mean;   % freqs x time

alphaImgFA_mean = powImgFA_mean(alphaCond, :);
alphaImgCR_mean = powImgCR_mean(alphaCond, :);
powDiffAlphaImgResp = alphaImgFA_mean - alphaImgCR_mean; 

%% High vs. low vividness
figure('Color','w','Position',[100 100 900 700])

subplot(3,1,1)
imagesc(freq.time, freq.freq(alphaCond), alphaPowHV_mean)
axis xy
xlim([freq.time(1) freq.time(end)])
ylim([freq.freq(find(freq.freq>8, 1)) freq.freq(find(freq.freq<13, 1, 'last'))])
xlabel('Time (s)'); ylabel('Frequency (Hz)')
title('High vividness imagery'); colorbar
clim([min(min(alphaPowLV_mean, [], 'all'), min(alphaPowHV_mean, [], 'all')), max(max(alphaPowLV_mean, [], 'all'), max(alphaPowHV_mean, [], 'all'))])

subplot(3,1,2)
imagesc(freq.time, freq.freq(alphaCond), alphaPowLV_mean)
axis xy
xlim([freq.time(1) freq.time(end)])
ylim([freq.freq(find(freq.freq>8, 1)) freq.freq(find(freq.freq<13, 1, 'last'))])
xlabel('Time (s)'); ylabel('Frequency (Hz)')
title('Low vividness imagery'); colorbar
clim([min(min(alphaPowLV_mean, [], 'all'), min(alphaPowHV_mean, [], 'all')), max(max(alphaPowLV_mean, [], 'all'), max(alphaPowHV_mean, [], 'all'))])


subplot(3,1,3)
imagesc(freq.time, freq.freq(alphaCond), powDiffAlphaViv)
axis xy
xlim([freq.time(1) freq.time(end)])
ylim([freq.freq(find(freq.freq>8, 1)) freq.freq(find(freq.freq<13, 1, 'last'))])
xlabel('Time (s)'); ylabel('Frequency (Hz)')
title('High vividness - Low vividness'); colorbar
xline(0,'k--','LineWidth',1.5)

%% Present vs. Absent judgments
figure('Color','w','Position',[100 100 900 700])

subplot(3,1,1)
imagesc(freq.time, freq.freq(alphaCond), alphaPresent_mean)
axis xy
xlim([freq.time(1) freq.time(end)])
ylim([freq.freq(find(freq.freq>8, 1)) freq.freq(find(freq.freq<13, 1, 'last'))])
xlabel('Time (s)'); ylabel('Frequency (Hz)')
title('Response: Present'); colorbar
clim([min(min(alphaAbsent_mean, [], 'all'), min(alphaPresent_mean, [], 'all')), max(max(alphaAbsent_mean, [], 'all'), max(alphaPresent_mean, [], 'all'))])

subplot(3,1,2)
imagesc(freq.time, freq.freq(alphaCond), alphaAbsent_mean)
axis xy
xlim([freq.time(1) freq.time(end)])
ylim([freq.freq(find(freq.freq>8, 1)) freq.freq(find(freq.freq<13, 1, 'last'))])
xlabel('Time (s)'); ylabel('Frequency (Hz)')
title('Response: Absent'); colorbar
clim([min(min(alphaAbsent_mean, [], 'all'), min(alphaPresent_mean, [], 'all')), max(max(alphaAbsent_mean, [], 'all'), max(alphaPresent_mean, [], 'all'))])


subplot(3,1,3)
imagesc(freq.time, freq.freq(alphaCond), powDiffAlphaResp)
axis xy
xlim([freq.time(1) freq.time(end)])
ylim([freq.freq(find(freq.freq>8, 1)) freq.freq(find(freq.freq<13, 1, 'last'))])
xlabel('Time (s)'); ylabel('Frequency (Hz)')
title('Present - Absent'); colorbar
xline(0,'k--','LineWidth',1.5)


%% Imagery False Alarms v Correct Rejections

%% Plot
figure('Color','w','Position',[100 100 900 700])

subplot(3,1,1)
imagesc(freq.time, freq.freq(alphaCond), alphaImgFA_mean)
axis xy
xlim([freq.time(1) freq.time(end)])
ylim([freq.freq(find(freq.freq>8, 1)) freq.freq(find(freq.freq<13, 1, 'last'))])
xlabel('Time (s)'); ylabel('Frequency (Hz)')
title('Imagery, False Alarms'); colorbar
clim([min(min(alphaImgCR_mean, [], 'all'), min(alphaImgFA_mean, [], 'all')), max(max(alphaImgCR_mean, [], 'all'), max(alphaImgFA_mean, [], 'all'))])

subplot(3,1,2)
imagesc(freq.time, freq.freq(alphaCond), alphaImgCR_mean)
axis xy
xlim([freq.time(1) freq.time(end)])
ylim([freq.freq(find(freq.freq>8, 1)) freq.freq(find(freq.freq<13, 1, 'last'))])
xlabel('Time (s)'); ylabel('Frequency (Hz)')
title('Imagery, Correct Rejections'); colorbar
clim([min(min(alphaImgCR_mean, [], 'all'), min(alphaImgFA_mean, [], 'all')), max(max(alphaImgCR_mean, [], 'all'), max(alphaImgFA_mean, [], 'all'))])


subplot(3,1,3)
imagesc(freq.time, freq.freq(alphaCond), powDiffAlphaImgResp)
axis xy
xlim([freq.time(1) freq.time(end)])
ylim([freq.freq(find(freq.freq>8, 1)) freq.freq(find(freq.freq<13, 1, 'last'))])
xlabel('Time (s)'); ylabel('Frequency (Hz)')
title('FA - CR'); colorbar
xline(0,'k--','LineWidth',1.5)

cfg = [];
cfg.xlim         = [-0.95, 0.4];
cfg.ylim         = [8 13];
cfg.marker       = 'on';
cfg.layout       = 'CTF275_helmet.mat';
cfg.colorbar     = 'yes';
cfg.trials       = imgMask & meta.reproduction >= hvThresh;
figure
ft_topoplotTFR(cfg, freq);

cfg = [];
cfg.xlim         = [-0.95, 0.4];
cfg.ylim         = [8 13];
cfg.marker       = 'on';
cfg.layout       = 'CTF275_helmet.mat';
cfg.colorbar     = 'yes';
cfg.trials       = imgMask & meta.reproduction <= lvThresh;
figure
ft_topoplotTFR(cfg, freq);

%% Imagery vs. Perception - all bands

powImg  = pow(imgMask,  chanIdx, :, :);
powPerc = pow(~imgMask, chanIdx, :, :);

% Average across trials and channels (adjust dimensions if needed)
powImg_mean  = squeeze(mean(mean(powImg, 1), 2));    % freq x time
powPerc_mean = squeeze(mean(mean(powPerc, 1), 2));   % freq x time

%% Define bands
bands = {
    'Delta', [1 4];
    'Theta', [4 8];
    'Alpha', [8 13];
    'Beta',  [13 30];
    'Gamma', [30 80];
};

nBands = size(bands,1);

for b = 1:nBands
    
    bandName = bands{b,1};
    bandRange = bands{b,2};
    
    bandCond = freq.freq > bandRange(1) & freq.freq < bandRange(2);
    
    bandFreqs = freq.freq(bandCond);
    bandImg   = powImg_mean(bandCond, :);
    bandPerc  = powPerc_mean(bandCond, :);
    bandDiff  = bandImg - bandPerc;
    
    % Shared color scale for Imagery and No imagery
    commonMin = min([bandImg(:); bandPerc(:)]);
    commonMax = max([bandImg(:); bandPerc(:)]);
    
    figure('Color','w','Position',[100 100 900 700])
    
    subplot(3,1,1)
    imagesc(freq.time, bandFreqs, bandImg)
    axis xy
    xlim([freq.time(1) freq.time(end)])
    ylim([bandFreqs(1) bandFreqs(end)])
    xlabel('Time (s)')
    ylabel('Frequency (Hz)')
    title([bandName ' - Imagery'])
    colorbar
    clim([commonMin commonMax])
    xline(0,'k--','LineWidth',1.5)
    
    subplot(3,1,2)
    imagesc(freq.time, bandFreqs, bandPerc)
    axis xy
    xlim([freq.time(1) freq.time(end)])
    ylim([bandFreqs(1) bandFreqs(end)])
    xlabel('Time (s)')
    ylabel('Frequency (Hz)')
    title([bandName ' - No imagery'])
    colorbar
    clim([commonMin commonMax])
    xline(0,'k--','LineWidth',1.5)
    
    subplot(3,1,3)
    imagesc(freq.time, bandFreqs, bandDiff)
    axis xy
    xlim([freq.time(1) freq.time(end)])
    ylim([bandFreqs(1) bandFreqs(end)])
    xlabel('Time (s)')
    ylabel('Frequency (Hz)')
    title([bandName ' - Imagery minus No Imagery'])
    colorbar
    xline(0,'k--','LineWidth',1.5)
end