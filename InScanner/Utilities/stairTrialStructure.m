function [ trialMatrix ] = stairTrialStructure(nTrials, nEvalTrials)
% Trial structure
% 50% present/50% absent
nStairs = nTrials/nEvalTrials;

% Trial Matrix
trialMatrix = nan(nTrials, 2);
noiseArray = 1:4;
noiseArray = repmat(noiseArray, 1, 10);

for s = 1:nStairs
    
    % staircase indices
    sIdx = (s-1)*nEvalTrials+1:s*nEvalTrials;
    tmp  = nan(nEvalTrials,2);
    
    % 50/50 absence presence
    tmp(1:nEvalTrials/2,1) = 0; 
    tmp(nEvalTrials/2+1:nEvalTrials,1) = 1;
    tmp(1:nEvalTrials,2) = noiseArray(1:nEvalTrials);
    
    % shuffle within stairs
    trialMatrix(sIdx,:) = tmp(randperm(nEvalTrials),:);
end

end