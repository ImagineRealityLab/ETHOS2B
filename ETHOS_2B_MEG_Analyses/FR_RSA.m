%% Step 1: Pseudodata
nCond = 32;
nPairs = nchoosek(nCond,2);
nTime = 300;

% Generate base theory RDMs
RDM_t1 = squareform(pdist(rand(nCond,1)));
RDM_t2 = squareform(pdist(rand(nCond,1)));
RDM_t3 = squareform(pdist(rand(nCond,1)));

% Vectorize RDMs
v_t1 = squareform(RDM_t1);
v_t2 = squareform(RDM_t2);
v_t3 = squareform(RDM_t3);

% Bundle
theories = {v_t1, v_t2, v_t3};
theory_names = {'Theory 1', 'Theory 2', 'Theory 3'};

% Generate pairwise weights
pair_weights = rand(3, nPairs);
pair_weights = pair_weights ./ max(pair_weights, [], 2);

% Create time-varying brain RDMs
v_brain_time = zeros(nTime, nPairs);
for t = 1:nTime
    RDM_brain = 0.3 * RDM_t1 + 0.2 * RDM_t2 + 0.1 * RDM_t3 + 0.4 * randn(nCond);
    RDM_brain = (RDM_brain + RDM_brain') / 2;
    RDM_brain(1:nCond+1:end) = 0;
    v_brain_time(t,:) = squareform(RDM_brain);
end

%% Step 2: FR-RSA with Standard Ridge Regression and CV
lambda_vals = logspace(-3, 3, 30);
K = 5;  % Number of CV folds
R2s = zeros(nTime, length(theories));

for t = 1:nTime
    y = zscore(v_brain_time(t, :)');  % brain dissimilarity vector

    for i = 1:3
        x = zscore(theories{i}');           % theory vector
        w = pair_weights(i,:)';             % pairwise importance
        xw = w .* x;                        % weighted predictor
        X = xw;                             % design matrix: nPairs x 1

        % Cross-validation to choose lambda
        indices = crossvalind('Kfold', nPairs, K);
        mse_lambdas = zeros(length(lambda_vals), 1);

        for l = 1:length(lambda_vals)
            mse_fold = zeros(K, 1);

            for k = 1:K
                test_idx = (indices == k);
                train_idx = ~test_idx;

                X_train = X(train_idx);
                y_train = y(train_idx);
                X_test = X(test_idx);
                y_test = y(test_idx);

                % Fit ridge regression
                beta = ridge(y_train, X_train, lambda_vals(l), 0);  % no constant term
                y_pred = X_test * beta(2);

                mse_fold(k) = mean((y_test - y_pred).^2);
            end

            mse_lambdas(l) = mean(mse_fold);
        end

        % Choose best lambda and retrain on full data
        [~, best_idx] = min(mse_lambdas);
        best_lambda = lambda_vals(best_idx);

        beta = ridge(y, X, best_lambda, 0);
        y_hat = X * beta(2);

        % Compute R^2
        R2s(t, i) = 1 - sum((y - y_hat).^2) / sum((y - mean(y)).^2);
    end
end

%% Step 3: Plot Results
figure;
plot(1:nTime, R2s, 'LineWidth', 2);
legend(theory_names, 'Location', 'best');
xlabel('Time Points');
ylabel('FR-RSA R^2');
title('Feature-Reweighted RSA (Clean Ridge Version with CV)');
grid on;
