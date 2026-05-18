clear; close all; clc;
rng(32)


%% Alpha range

alpha = linspace(0.1,2.5,80);

% log(alpha)
la = log(alpha);
nTrials = 1000;
%% Evidence strengths

% Bottom-up evidence
BU_present = 1.0;
BU_absent  = 0.0;

% Top-down evidence
TD_highViv = 0.8;
TD_lowViv  = 0.3;
TD_noViv   = 0.0;

%% Noise magnitudes

sharedNoiseSD = 0.1;
buNoiseSD     = 0.1;
tdNoiseSD     = 0.1;

conditions = [
    BU_present TD_highViv;
    BU_present TD_lowViv;
    BU_present TD_noViv;
    BU_absent  TD_highViv;
    BU_absent  TD_lowViv;
    BU_absent  TD_noViv
];

conditionNames = {
    'Present + high vividness'
    'Present + low vividness'
    'Present + no imagery'
    'Absent + high vividness'
    'Absent + low vividness'
    'Absent + no imagery'
};


sigmoid = @(x) 1 ./ (1 + exp(-x));


nCond = size(conditions,1);

M1 = zeros(length(alpha),nCond);
M2 = zeros(length(alpha),nCond);
M3 = zeros(length(alpha),nCond);

for a = 1:length(alpha)

    currentLA = la(a);

    %% Loop over conditions

    for c = 1:nCond

        BU = conditions(c,1);
        TD = conditions(c,2);

        %% TRIALWISE SIMULATION

        detect_M1 = zeros(nTrials,1);
        detect_M2 = zeros(nTrials,1);
        detect_M3 = zeros(nTrials,1);

        for t = 1:nTrials

            %% ------------------------------------------------
            %% Noise terms
            %% ------------------------------------------------

            sharedNoise = normrnd(0,sharedNoiseSD);
            buNoise     = normrnd(0,buNoiseSD);
            tdNoise     = normrnd(0,tdNoiseSD);

            %% =================================================
            %% MODEL 1
            %% General gain model
            %%
            %% Low alpha amplifies everything
            %% =================================================

            DV_M1 = ...
                (-currentLA * BU) + ...
                (-currentLA * TD) + ...
                sharedNoise + ...
                buNoise + ...
                tdNoise;

            P_M1 = sigmoid(DV_M1);

            detect_M1(t) = rand < P_M1;

            %% =================================================
            %% MODEL 2
            %% High alpha favors TOP-DOWN signals
            %% =================================================

            DV_M2 = ...
                (-currentLA * BU) + ...
                ( currentLA * TD) + ...
                sharedNoise + ...
                buNoise + ...
                tdNoise;

            P_M2 = sigmoid(DV_M2);

            detect_M2(t) = rand < P_M2;

            %% =================================================
            %% MODEL 3
            %% Low alpha favors TOP-DOWN signals
            %% =================================================

            DV_M3 = ...
                ( currentLA * BU) + ...
                (-currentLA * TD) + ...
                sharedNoise + ...
                buNoise + ...
                tdNoise;

            P_M3 = sigmoid(DV_M3);

            detect_M3(t) = rand < P_M3;

        end

        %% ----------------------------------------------------
        %% Average detection probability
        %% ----------------------------------------------------

        M1(a,c) = mean(detect_M1);
        M2(a,c) = mean(detect_M2);
        M3(a,c) = mean(detect_M3);

    end
end

%% ============================================================
%% PLOTTING
%% ============================================================

figure('Color','w','Position',[100 100 1600 500]);

%% ============================================================
%% MODEL 1
%% ============================================================

subplot(1,3,1)

hold on

for c = 1:nCond
    plot(alpha,M1(:,c),'LineWidth',3)
end

xlabel('Alpha power')
ylabel('Detection probability')

title('Model 1: General Gain')

legend(conditionNames,'Location','best')

ylim([0 1])

set(gca,'FontSize',12)

%% ============================================================
%% MODEL 2
%% ============================================================

subplot(1,3,2)

hold on

for c = 1:nCond
    plot(alpha,M2(:,c),'LineWidth',3)
end

xlabel('Alpha power')
ylabel('Detection probability')

title('Model 2: High Alpha Favors Top-Down')

legend(conditionNames,'Location','best')

ylim([0 1])

set(gca,'FontSize',12)

%% ============================================================
%% MODEL 3
%% ============================================================

subplot(1,3,3)

hold on

for c = 1:nCond
    plot(alpha,M3(:,c),'LineWidth',3)
end

xlabel('Alpha power')
ylabel('Detection probability')

title('Model 3: Low Alpha Favors Top-Down')

legend(conditionNames,'Location','best')

ylim([0 1])

set(gca,'FontSize',12)
