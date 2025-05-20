clear
clc

%% Computes a neural RDM per time point (nCond x nCond) 

for iSubject = 1 %loop through participants

    %% 1 Pre-processing
    
    cfg.dataset     = strcat("Subject0", string(iSubject), ".ds");

    cfg.trialdef.eventtype  = 'backpanel trigger';
    cfg.trialdef.eventvalue = [3 5 9]; 
    cfg.channel             = {'MEG' 'EOG'};
    cfg.continuous          = 'yes'; 

    % Get raw event structure
    cfg_temp = cfg;
    cfg_temp = ft_definetrial(cfg_temp); % Needed to get the events
    event = cfg_temp.event;

    % Add pseudodata, here I simualted adding vividness ratings and
    % detection, others can be added
    for i = 1:length(event)
        event(i).viv = rand();
        event(i).det = randi([0,1]);
    end

    for i = 1:length(event)
    val = event(i).value;
    viv = event(i).viv;
    det = event(i).det;

    if isscalar(val) && any(val == [3, 5, 9])
        if val == 3
            offset = 10;
        elseif val == 5
            offset = 20;
        elseif val == 9
            offset = 30;
        end

        if viv > 0.5 && det == 1
            event(i).value = offset + 1;
        elseif viv <= 0.5 && det == 1
            event(i).value = offset + 2;
        elseif viv > 0.5 && det == 0
            event(i).value = offset + 3;
        elseif viv <= 0.5 && det == 0
            event(i).value = offset + 4;
        end
    end
    end

    %% Additional events with the behavioral data
    cfg = [];
    cfg.dataset     = strcat("Subject0", string(iSubject), ".ds");
    cfg.event = event;
    cfg.trialdef.eventtype  = 'backpanel trigger';
    cfg.trialdef.eventvalue = [11 12 13 14 21 22 23 24 31 32 33 34]; 
    cfg.trialdef.prestim    = 0.2; %pre-reg values
    cfg.trialdef.poststim   = 0.8; %what is left in the trial
    cfg.channel             = {'MEG' 'EOG'}; % will we use EOG??
    cfg.continuous          = 'yes';
    cfg = ft_definetrial(cfg); 


    % Now preprocess with updated trial structure
    data_all = ft_preprocessing(cfg);

    %% 2 Filtering (de-sampling + line filter + band-pass filter)

    % Settings to diminish muscle and ocular artifects
    
      cfg          = [];  
      cfg.preproc.bpfilter    = 'yes';
      cfg.preproc.bpfilttype  = 'but';
      cfg.preproc.bpfreq      = [1 15];
      cfg.preproc.bpfiltord   = 4;
      cfg.preproc.rectify     = 'yes';
    
      cfg.preproc.bpfilter    = 'yes';
      cfg.preproc.bpfreq      = [110 140];
      cfg.preproc.bpfiltord   =  8;
      cfg.preproc.bpfilttype  = 'but';
      cfg.preproc.rectify     = 'yes';
      cfg.preproc.boxcar      = 0.2;  
    
      data_all = ft_preprocessing(cfg,data_all);


    % De-sampling, slow drifts retained
    cfg = [];
    cfg.resamplefs = 300; %resampling for computational efficency
    cfg.detrend = 'no';  % Keeping slow drifts or not? 
    data = ft_resampledata(cfg, data_all);

    % removing the 50 Hz line noise (and the harmonics at 100 and 150 Hz).
    cfg = [];
    cfg.dftfilter = 'yes'; % Discrete fourier transform
    cfg.padding = 10;
    data = ft_preprocessing(cfg, data);
    
    %% 3 Artifect removal (trial / channel / summary)
    cfg = []; %Trial elimination based on kurtosis
    cfg.method = 'trial'; 
    cfg.metric = "kurtosis";
    cfg.ylim     = [-1e-12 1e-12];
    cfg.megscale = 1;
    cfg.eogscale = 5e-8;
    data_clean = ft_rejectvisual(cfg, data);

     cfg = []; %Channel elimination based on kurtosis
    cfg.method = 'channel'; 
    cfg.metric = "kurtosis";
    cfg.ylim     = [-1e-12 1e-12];
    cfg.megscale = 1;
    cfg.eogscale = 5e-8;
    data_clean = ft_rejectvisual(cfg, data_clean);

    cfg          = []; %A general look
    cfg.method   = 'summary';
    cfg.ylim     = [-1e-12 1e-12];
    cfg.megscale = 1;
    cfg.eogscale = 5e-8;
    data_clean        = ft_rejectvisual(cfg, data_clean);

      
  


    %% 4 Independent Component Analysis


    cfg=[]; 
    cfg.resamplefs = 200;   
    data_resamp = ft_resampledata(cfg, data_clean); %computational efficiency desampling for ICA

    cfg=[];
    cfg.hpfreq=1;
    cfg.lpfreq=40;
    cfg.padding=10.5;
    cfg.padtype='zero';
    data_filt=ft_preprocessing(cfg, data_resamp); %high/low pass filtering for ICA

    cfg              = [];
    cfg.method       = 'runica';
    cfg.channel      = {'MEG', 'MEGREF'};
    cfg.numcomponent = 20; %for simplicity, delete this later.
    data_comp = ft_componentanalysis(cfg, data_filt);

    % The configuration should contain
%   cfg.method       = 'runica', 'fastica', 'binica', 'pca', 'svd', 'jader',
%                      'varimax', 'dss', 'cca', 'sobi', 'white' or 'csp'
%                      (default = 'runica')
%   cfg.channel      = cell-array with channel selection (default = 'all'),
%                      see FT_CHANNELSELECTION for details
%   cfg.split        = cell-array of channel types between which covariance
%                      is split, it can also be 'all' or 'no' (default = 'no')
%   cfg.trials       = 'all' or a selection given as a 1xN vector (default = 'all')
%   cfg.numcomponent = 'all' or number (default = 'all')
%   cfg.demean       = 'no' or 'yes', whether to demean the input data (default = 'yes')
%   cfg.updatesens   = 'no' or 'yes' (default = 'yes')
%   cfg.feedback     = 'no', 'text', 'textbar', 'gui' (default = 'text')

    cfg           = [];
    cfg.layout    = 'CTF151.lay';
    cfg.marker    = 'off';
    ft_topoplotIC(cfg, data_comp)

    cfg = [];
    cfg.component = [10 12]; % to be removed after inspection/ arbitrary values were given
    data_ica = ft_rejectcomponent(cfg, data_comp, data_clean);

        cfg          = []; %Re-check after ICA
    cfg.method   = 'summary';
    cfg.ylim     = [-1e-12 1e-12];
    cfg.megscale = 1;
    cfg.eogscale = 5e-8;
    dummy        = ft_rejectvisual(cfg, data_clean);
  

%% 5 RSA Implementation - to create one RDM per time point per participant

allLabels = unique(data_all.trialinfo); %unique event codes
nCond = length(allLabels);  % should be 32
labelToIndex = containers.Map(allLabels, 1:nCond); %convert codes to indices

nTrials = length(data_all.trial);
designMatrix = zeros(nTrials, nCond); %providing the conditios for the regression
for i = 1:nTrials
    originalLabel = data_all.trialinfo(i);
    mappedIndex = labelToIndex(originalLabel);
    designMatrix(i, mappedIndex) = 1;
end

cfg = [];
cfg.keeptrials = 'yes';
cfg.channel = 'MEG';
data_timelock = ft_timelockanalysis(cfg, data_all);  % gives: trials x sensors x time
%   cfg.channel            = Nx1 cell-array with selection of channels (default = 'all'), see FT_CHANNELSELECTION for details
%   cfg.latency            = [begin end] in seconds, or 'all', 'minperiod', 'maxperiod', 'prestim', 'poststim' (default = 'all')
%   cfg.trials             = 'all' or a selection given as a 1xN vector (default = 'all')
%   cfg.keeptrials         = 'yes' or 'no', return individual trials or average (default = 'no')
%   cfg.nanmean            = string, can be 'yes' or 'no' (default = 'yes')
%   cfg.normalizevar       = 'N' or 'N-1' (default = 'N-1')
%   cfg.covariance         = 'no' or 'yes' (default = 'no')
%   cfg.covariancewindow   = [begin end] in seconds, or 'all', 'minperiod', 'maxperiod', 'prestim', 'poststim' (default = 'all')
%   cfg.removemean         = 'yes' or 'no', for the covariance computation (default = 'yes')

nTrials = size(data_timelock.trial, 1);
nChans = size(data_timelock.trial, 2);
nTime = size(data_timelock.trial, 3);
betas = nan(nCond, nChans, nTime);  % [conditions x channels x time]

for t = 1:nTime
    for ch = 1:nChans
        y = squeeze(data_timelock.trial(:, ch, t));  % trial vector for 1 sensor at a time
        b = regress(y, designMatrix);  % Ncond x 1
        betas(:, ch, t) = b;
    end
end

neuralRDMs = nan(nCond, nCond, nTime);
for t = 1:nTime
    patterns = squeeze(betas(:, :, t));  % [conditions x sensors]
    if any(isnan(patterns(:)))
        warning("NaNs found at time %d", t);
        continue;
    end
    patterns = zscore(patterns, 0, 2);  % normalize patterns 
    R = corr(patterns');               % similarity across condition patterns
    D = 1 - R;                          % dissimilarity
    neuralRDMs(:, :, t) = D;
end

end

%% 6 Theory Examination


% Set seed for reproducibility
rng(123);

% Parameters
nCond = 32;                % number of conditions
nPairs = nchoosek(nCond, 2);  % number of unique condition pairs (RDM size)
nTime = 300;               % number of time points (could represent different brain states)

% Generate pseudodata for 3 theory RDMs
RDM_t1 = randn(nCond, nCond);  % Theory 1 RDM
RDM_t2 = randn(nCond, nCond);  % Theory 2 RDM
RDM_t3 = randn(nCond, nCond);  % Theory 3 RDM

% Symmetrize the matrices
RDM_t1 = (RDM_t1 + RDM_t1') / 2;
RDM_t2 = (RDM_t2 + RDM_t2') / 2;
RDM_t3 = (RDM_t3 + RDM_t3') / 2;

% Remove diagonal elements (self-similarity)
RDM_t1(logical(eye(nCond))) = 0;
RDM_t2(logical(eye(nCond))) = 0;
RDM_t3(logical(eye(nCond))) = 0;

% Create mask for upper triangle (excluding diagonal)
mask = triu(true(nCond), 1);

% Vectorize (flatten the upper triangle of the matrix, excluding diagonal)
v_t1 = RDM_t1(mask);
v_t2 = RDM_t2(mask);
v_t3 = RDM_t3(mask);

% Generate brain RDMs with noise (a weighted combination of the theories + random noise)
logBF_matrix = zeros(nTime, 3);
brain_RDMs = zeros(nTime, nPairs);

for t = 1:nTime
    % Generate noise and create brain RDM as a weighted sum of theories
    noise = randn(nCond, nCond) * 0.5;
    RDM_brain = 0.3 * RDM_t1 + 0.2 * RDM_t2 + 0.15 * RDM_t3 + noise;
    RDM_brain = (RDM_brain + RDM_brain') / 2;  % symmetrize
    RDM_brain(logical(eye(nCond))) = 0;  % Remove diagonal
    
    % Vectorize the upper triangle (no diagonal) and assign to brain_RDMs
    brain_RDMs(t, :) = RDM_brain(mask);
end

% Perform Bayesian regression for each time point
% Using BIC approximation to compare models
for t = 1:nTime
    brain_RDM_t = brain_RDMs(t, :)';
    
    % Create design matrix
    X = [v_t1, v_t2, v_t3];
    
    % Full model
    mdl_full = fitlm(X, brain_RDM_t);
    BIC_full = mdl_full.ModelCriterion.BIC;
    
    % Reduced models (excluding one theory at a time)
    mdl_minus_t1 = fitlm([v_t2, v_t3], brain_RDM_t);
    mdl_minus_t2 = fitlm([v_t1, v_t3], brain_RDM_t);
    mdl_minus_t3 = fitlm([v_t1, v_t2], brain_RDM_t);
    
    BIC_minus_t1 = mdl_minus_t1.ModelCriterion.BIC;
    BIC_minus_t2 = mdl_minus_t2.ModelCriterion.BIC;
    BIC_minus_t3 = mdl_minus_t3.ModelCriterion.BIC;
    
    % Calculate BIC differences
    delta_BIC_t1 = BIC_minus_t1 - BIC_full;
    delta_BIC_t2 = BIC_minus_t2 - BIC_full;
    delta_BIC_t3 = BIC_minus_t3 - BIC_full;
    
    % Convert BIC differences to log Bayes factors
    % BF ≈ exp(delta_BIC / 2), so log10(BF) ≈ delta_BIC / (2 * ln(10))
    logBF_matrix(t, 1) = delta_BIC_t1 / (2 * log(10));  % Unique effect of Theory 1
    logBF_matrix(t, 2) = delta_BIC_t2 / (2 * log(10));  % Unique effect of Theory 2
    logBF_matrix(t, 3) = delta_BIC_t3 / (2 * log(10));  % Unique effect of Theory 3
end

% Plot Bayes factors over time
figure;
plot(1:nTime, log10(logBF_matrix(:, 1)), 'b-', 'LineWidth', 2);
hold on;
plot(1:nTime, log10(logBF_matrix(:, 2)), 'r-', 'LineWidth', 2);
plot(1:nTime, log10(logBF_matrix(:, 3)), 'g-', 'LineWidth', 2);
yline(0, 'k--', 'No Evidence', 'LineWidth', 1);
ylim([-5, 5]);
xlabel('Time Point');
ylabel('Log₁₀ Bayes Factor');
title('Bayesian Model Comparison over Time');
legend('Theory 1', 'Theory 2', 'Theory 3', 'Location', 'northeast');
grid on;
hold off;


