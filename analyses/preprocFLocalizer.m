clear
clc
close all

subjects = {'subj-5'};
nRuns = 8;


resultsDir = "results";
addpath("Utilities")
trialsPerRun = 80;


for iSubj = 1:length(subjects)
    
    rejection_log = struct();
    subjID = subjects{iSubj};
    subjDir = fullfile(resultsDir, subjID);

    data_all_runs = cell(1, nRuns);
    goodChannels_per_run = cell(1, nRuns);

    for iRun = 1:nRuns

        fprintf('Processing %s Run %d\n', subjID, iRun);

        dataset = fullfile(subjDir, ...
            sprintf('MG08281_ND001_20260429_0%d.ds', iRun));
        
        %% Trigger info
        % noiseOnset_trigger = 1;          
        % gratingOnset_trigger = 2;           
        % responseOnset_trigger = 3;   
        % responseOffset_trigger = 4;
        % reproductionOnset_trigger = 5;
        % reproductionOffset_trigger = 6;
        % localizerStimOnset_trigger = 7;

        %% 1. LOAD + EPOCH RAW DATA

        cfg = [];
        cfg.dataset            = dataset;
        cfg.trialfun           = 'ft_trialfun_general';
        cfg.trialdef.eventtype = 'UPPT001';
        cfg.trialdef.eventvalue= 7;
        cfg.trialdef.prestim   = 0.3;
        cfg.trialdef.poststim  = 0.5;
        cfg = ft_definetrial(cfg);
        
        trl = cfg.trl;
        
        % Apply bandstop filter to remove line noise to continuous MEG
        % recording
        cfg = [];
        cfg.dataset    = dataset;
        cfg.continuous = 'yes';
        cfg.bsfilter   = 'yes';
        cfg.bsfreq     = [49 51; 99 101; 149 151];

        data_meg = ft_preprocessing(cfg);

        % Epoch the data based on defined trials
        cfg = [];
        cfg.trl = trl;
        data_stim = ft_redefinetrial(cfg, data_meg);
       
        
        %% 2. Realign with photodiode
        photoIdx       = strcmp(data_stim.label, 'UADC004');
        PHOTO_THR_V    = -0.01;
        stim_onset_idx = find(data_stim.time{1} >= 0, 1, 'first');
        photo_onsets   = nan(1, length(data_stim.trial));

        for t = 1:length(data_stim.trial)
            sig     = data_stim.trial{t}(photoIdx, stim_onset_idx:end);
            rel_idx = find(diff(sig) < PHOTO_THR_V, 1, 'first');

            if ~isempty(rel_idx)
                full_idx = rel_idx + stim_onset_idx - 1;
                photo_onsets(t)  = data_stim.time{t}(full_idx);
            else
                warning('Run %d Stim Trial %d: no photodiode detected.', iRun, t);
                photo_onsets(t) = 0;
            end
        end

        for t = 1:length(data_stim.trial)

            shift = photo_onsets(t);
        
            if ~isnan(shift)
                data_stim.time{t} = ...
                    data_stim.time{t} - shift;
            end
        
        end
        
        % Crop the data to ensure consistency
        cfg = [];
        cfg.latency = [-0.2 0.4];
        data_stim = ft_selectdata(cfg, data_stim);
        
        % Baseline correction
        cfg                  = [];
        cfg.demean           = 'yes';
        cfg.baselinewindow   = [-0.2 0];
        data_stim             = ft_preprocessing(cfg, data_stim);

        %% 3. Manuel artifact rejection
        % Visualize the unfiltered trials
        cfg = [];
        cfg.viewmode = 'vertical';
        cfg.channel  = 'MEG';
        cfg.continuous = 'no';
        ft_databrowser(cfg, data_stim);

        % MEG high-frequency envelope for muscle artefacts
        cfg = [];
        cfg.channel  = 'MEG';
        cfg.bpfilter = 'yes';
        cfg.bpfreq   = [110 140];
        cfg.rectify  = 'yes';
        cfg.boxcar   = 0.2;
        meg_vis = ft_preprocessing(cfg, data_stim);
        data_vis = meg_vis;

        % EOG low-frequency envelope for eye artefacts
        cfg = [];
        cfg.channel = {'UADC001','UADC002'};
        cfg.bpfilter = 'yes';
        cfg.bpfreq   = [1 10];
        cfg.rectify  = 'yes';
        cfg.boxcar   = 0.2;
        eog_vis = ft_preprocessing(cfg, data_stim);

        %% 4. MANUAL REJECTION ON FILTERED DATA

        cfg = [];
        cfg.method   = 'summary';
        cfg.megscale = 1;
        data_vis = ft_rejectvisual(cfg, data_vis);

        cfg = [];
        cfg.method   = 'summary';
        cfg.megscale = 1;
        eog_vis = ft_rejectvisual(cfg, eog_vis);


        %% 5. APPLY TRIAL REJECTION BACK TO RAW DATA

        goodTrials = intersect(data_vis.cfg.trials, eog_vis.cfg.trials);

        cfg = [];
        cfg.trials = goodTrials;
        data_clean = ft_selectdata(cfg, data_stim);

        poss_trials = (1:trialsPerRun) + (trialsPerRun*(iRun - 1));
        goodTrials = goodTrials + (trialsPerRun*(iRun - 1));

        %% 6. STORE RUN
        data_all_runs{iRun} = data_clean;
    
        rejection_log(iRun).subjID       = subjID;
        rejection_log(iRun).run          = iRun;
        rejection_log(iRun).nTrials_orig = length(data_stim.trial);
        rejection_log(iRun).nTrials_kept = length(goodTrials);
        rejection_log(iRun).trials_removed = setdiff(poss_trials, goodTrials);
    end % iRun


    %% 7. CONCATENATE RUNS

    data_stim = ft_appenddata([], data_all_runs{:});

    %% 8. ICA

    cfg = [];
    cfg.resamplefs = 300;
    data_down = ft_resampledata(cfg, data_stim);

    cfg = [];
    cfg.hpfilter = 'yes';
    cfg.hpfreq = 1;
    data_down_filtered = ft_preprocessing(cfg, data_down);

    cfg = [];
    cfg.method = 'runica';
    cfg.channel = 'MEG';
    comp = ft_componentanalysis(cfg, data_down_filtered);

    cfg = [];
    cfg.layout   = 'CTF275.lay';
    cfg.viewmode = 'component';
    ft_databrowser(cfg, comp);

    figure;
    cfg = [];
    cfg.component = 1:25;
    cfg.layout    = 'CTF275.lay';
    ft_topoplotIC(cfg, comp);

    ET = cell2mat(data_down_filtered.trial);
    ET = ET(ismember(data_down_filtered.label, {'UADC001','UADC002'}), :);
    
    r = corr(cell2mat(comp.trial)', ET');
    [ro, idx] = sort(abs(r),'descend');
    
    fprintf('Highest correlations: \n \t X: comp %d [%.4f] \n \t Y: comp %d [%.4f] \n \t ',idx(1,1),r(idx(1,1),1),idx(1,2),r(idx(1,2),2))

    % Visualize the compontents with highest correlation to eye-tracking
    % data
    figure;
    cfg                = [];
    cfg.component      = idx(1:4,:);
    cfg.layout         = 'CTF275.lay';
    ft_topoplotIC(cfg,comp)

    %% ---- MANUAL COMPONENT REJECTION ----
    badComps = input('Components to reject (e.g. [1 3 7]): ');

    %% 11. PROJECT ICA SOLUTION BACK ONTO FULL-RATE DATA

    cfg = [];
    cfg.component = badComps;
    data_ica_clean = ft_rejectcomponent(cfg, comp, data_stim);

    save(fullfile(subjDir, 'preProcLocalizer.mat'), ...
        'data_ica_clean', '-v7.3');

    fprintf('Done with subject %s.\n', subjID);

    save(fullfile(subjDir, 'rejection_log_localizer.mat'), 'rejection_log');

end % iSubj

