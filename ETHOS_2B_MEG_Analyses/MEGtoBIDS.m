bidsroot = 'C:\Users\aozsu\Desktop\ETHOS_EXP2';
raw_data_folder = 'C:\Users\aozsu\Desktop\RawMEGData';

for i = 1
    subjID = sprintf('%02d', i);  % '01', '02', ..., '30'
    dataset_name = sprintf('Subject%s.ds', subjID);
    dataset_path = fullfile(raw_data_folder, dataset_name);
    
    cfg = [];
    cfg.dataset = dataset_path;
    cfg.method = 'copy';  % Copy and rename dataset, then write BIDS sidecars

    cfg.bidsroot = bidsroot;
    cfg.sub = subjID;
    cfg.task = 'PerceptualRealityJudgment';
    cfg.suffix = 'meg';

    % Dataset description is only written once
    if i == 1
        cfg.dataset_description.Name    = 'ETHOS_EXP2';
        cfg.dataset_description.Authors = {'Ataol Burak Ozsu', 'Nadine Dijkstra'};
    else
        cfg.dataset_description.writesidecar = 'no';
    end

    % Participant metadata (can be individualized if needed)
    cfg.participants.age = 20 + mod(i, 5); % e.g., 20-24
    cfg.participants.sex = 'm';  % or randomize using e.g. mod(i,2)

    cfg.InstitutionName             = 'University College London';
    cfg.InstitutionAddress          = '12 Queen Square WC1N 3AR London, United Kingdom';
    cfg.InstitutionalDepartmentName = 'Human Neuroimaging';
    cfg.TaskName                    = 'PerceptualRealityJudgment';
    cfg.scans.acq_time = '2024-06-01T12:00:00'; % or any RFC3339 timestamp
   

    % Run the conversion
    try
        
        
        data2bids(cfg);
    catch ME
        fprintf('Error with subject %s: %s\n', subjID, ME.message);
    end
end

        