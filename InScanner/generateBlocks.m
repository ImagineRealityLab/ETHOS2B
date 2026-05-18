function [blocks, trials, ITIs, responseMappings, vividnessMappings] = generateBlocks(nBlocks, trialsPerBlock)

assert(mod(nBlocks,2)==0, 'nBlocks must be even (2 blocks per run)');

NoiseLevelsTrial = [1 2 3 4];
nNoise   = numel(NoiseLevelsTrial);
nPerCond = trialsPerBlock/2;            % trials per stimulus condition
repsPerLevel = nPerCond/nNoise;         % times each noise level appears per condition

assert(mod(nPerCond, nNoise) == 0, ...
    'trialsPerBlock/2 must be divisible by numel(NoiseLevelsTrial) for full counterbalancing.');

trials = zeros(nBlocks, trialsPerBlock, 2);

for iBlock = 1:nBlocks
    noisePresent = repmat(NoiseLevelsTrial', repsPerLevel, 1);
    noiseAbsent  = repmat(NoiseLevelsTrial', repsPerLevel, 1);

    noisePresent = noisePresent(randperm(nPerCond));
    noiseAbsent  = noiseAbsent(randperm(nPerCond));

    stim  = [ones(nPerCond,1);  zeros(nPerCond,1)];
    noise = [noisePresent;       noiseAbsent];

    idx = randperm(trialsPerBlock);
    trials(iBlock,:,1) = stim(idx);
    trials(iBlock,:,2) = noise(idx);
end

nRuns = nBlocks/2;
blocks = zeros(nBlocks,2);

runTemplates = repmat([1; 2], nRuns/2, 1);  % 1 = template A, 2 = template B
runTemplates = runTemplates(randperm(nRuns));

row = 1;
for iRun = 1:nRuns
    if runTemplates(iRun) == 1
        pair = [1 1;  
                2 0];  
    else
        pair = [1 0;   
                2 1]; 
    end
    
    % randomize order within run
    pair = pair(randperm(2), :);
    
    blocks(row:row+1, :) = pair;
    row = row + 2;
end

ITIs = 0.8 + 0.4 * rand(nBlocks*trialsPerBlock, 1);

mappings = zeros(nBlocks,2);


vivRespPairs = [1,1; 2,2; 1,2; 2,1];

cond1 = blocks(:,1) == 1 & blocks(:,2) ==0;
cond2 = blocks(:,1) == 1 & blocks(:,2) ==1;

cond3 = blocks(:,1) == 2 & blocks(:,2) ==0;
cond4 = blocks(:,1) == 2 & blocks(:,2) ==1; 

mappings(cond1,:) = vivRespPairs(randperm(length(vivRespPairs)), :);
mappings(cond2, :) = vivRespPairs(randperm(length(vivRespPairs)), :);
mappings(cond3, :) = vivRespPairs(randperm(length(vivRespPairs)), :);
mappings(cond4, :) = vivRespPairs(randperm(length(vivRespPairs)), :);

vividnessMappings = mappings(:,1);
responseMappings = mappings(:,2);





% % imagery condition
% rmImg = [ones(nImg/2,1); 2*ones(nImg/2,1)];
% rmImg = rmImg(randperm(nImg));
% 
% % perception condition
% rmPerc = [ones(nPerc/2,1); 2*ones(nPerc/2,1)];
% rmPerc = rmPerc(randperm(nPerc));
% 
% responseMappings(imgIdx) = rmImg;
% responseMappings(percIdx) = rmPerc;
% 
% vividnessMappings = zeros(nBlocks,1);
% 
% vmImg = [ones(nImg/2,1); 2*ones(nImg/2,1)];
% vmImg = vmImg(randperm(nImg));
% 
% vmPerc = [ones(nPerc/2,1); 2*ones(nPerc/2,1)];
% vmPerc = vmPerc(randperm(nPerc));
% 
% vividnessMappings(imgIdx) = vmImg;
% vividnessMappings(percIdx) = vmPerc;