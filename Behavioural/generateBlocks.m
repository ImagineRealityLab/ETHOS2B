function [blocks, trials, ITIs, responseMappings,vividnessMappings] = generateBlocks(nBlocks, trialsPerBlock)

assert(mod(nBlocks,2)==0, 'nBlocks must be even (2 blocks per run)');

NoiseLevelsTrial = [1 2 3 4];

trials = zeros(nBlocks, trialsPerBlock, 2);

baseTrials = [ones(trialsPerBlock/2,1); zeros(trialsPerBlock/2,1)];
baseNoise  = repmat(NoiseLevelsTrial', trialsPerBlock/numel(NoiseLevelsTrial), 1);

for iBlock = 1:nBlocks
    idx = randperm(trialsPerBlock);
    trials(iBlock,:,1) = baseTrials(idx);
    trials(iBlock,:,2) = baseNoise(idx);
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
        pair = pair(randperm(2), :);
    
    blocks(row:row+1, :) = pair;
    row = row + 2;
end

% timing
ITIs = 0.8 + 0.4 * rand(nBlocks*trialsPerBlock, 1);


responseMappings = repmat(1:2,1,nBlocks/2);
responseMappings = responseMappings(randperm(nBlocks));
vividnessMappings = repmat(1:2,1,nBlocks/2);
vividnessMappings = vividnessMappings(randperm(nBlocks));



    

