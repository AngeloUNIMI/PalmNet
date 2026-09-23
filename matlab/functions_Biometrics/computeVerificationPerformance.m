<<<<<<< HEAD
function [distMatrix, genuineInd, impostorInd, genuinesNorm, impostorsNorm, genuinesAggr, impostorsAggr, fprNorm, fnrNorm, fprAggr, fnrAggr, EERNorm, EERAggr, ...
    FMR1000Norm, FMR1000Aggr, genuineDist, impostorDist] = ...
    computeVerificationPerformance(numImagesTest, ftest_all, filenameTest, stepPrint, param)

%init
genuinesNorm = -1 .* ones(numImagesTest^2, 1);
impostorsNorm = -1 .* ones(numImagesTest^2, 1);
countGen = 1;
countImp = 1;
genuineInd = nan(numImagesTest, numImagesTest);
impostorInd = nan(numImagesTest, numImagesTest);

%%%
genuinesAggr = [];
impostorsAggr = [];
fprNorm = [];
fnrNorm = [];
fprAggr = [];
fnrAggr = [];
EERNorm = [];
EERAggr = [];
%%%


% assignin('base', 'ftestPCA_all', ftestPCA_all);
% pause

if strcmp(param.matchDistance, 'chisq')
    distMatrix = sc_pdist2(ftest_all, ftest_all, 'chisq');
elseif strcmp(param.matchDistance, 'euclidean')
    %fast Euclidean distance
    distMatrix = full(fastEuclideanDistance(ftest_all, ftest_all));
else %if strcmp
    distMatrix = pdist2(ftest_all', ftest_all', param.matchDistance);
end %if strcmp



%%%%%%%%%%%%%%%%%%%%%%%%%
% return
%%%%%%%%%%%%%%%%%%%%%%%%%

for i = 1 : numImagesTest
    
    %display progress
    if mod(i, stepPrint) == 0
        fprintf(1, ['\t\tRow ' num2str(i) ' processed\n'])
    end %if mod(i, 100) == 0
    %label
    %     label_1 = real(str2doubleq(getIndName(filenameTestPCA{i})));
    %     label_1 = str2double(getIndName(filenameTestPCA{i}));
%     label_1 = getIndName(filenameTestPCA{i});

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    label_1 = filenameTest{i}(1:4);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %j
    for j = 1 : numImagesTest
        if i == j
            continue;
        end %if i==j
        %         label_2 = real(str2doubleq(getIndName(filenameTestPCA{j})));
        %         label_2 = str2double(getIndName(filenameTestPCA{j}));
        %label_2 = getIndName(filenameTestPCA{j});
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        label_2 = filenameTest{j}(1:4);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        score = distMatrix(i, j);
        %         if label_1 == label_2
        if strcmp(label_1, label_2)
            genuinesNorm(countGen) = score;
            %calcoliamo mean genuine e impostor per individuo
            genuineInd(i,j) = score;
            countGen = countGen + 1;
        else %if label_1 == label_2
            impostorsNorm(countImp) = score;
            %calcoliamo mean genuine e impostor per individuo
            impostorInd(i,j) = score;
            countImp = countImp + 1;
        end %if label_1 == label_2
        

    end %for j
end %for i
%remove excess
genuinesNorm(countGen : end) = [];
impostorsNorm(countImp : end) = [];

%mantainDist
genuineDist = genuinesNorm;
impostorDist = impostorsNorm;

%convert distance to similarity
maxgi = max([genuinesNorm; impostorsNorm]) + 10;
genuinesNorm = maxgi - genuinesNorm;
impostorsNorm = maxgi - impostorsNorm;

%aggregate scores
genuinesAggr = movmax(genuinesNorm, param.numScoreAggregate);
impostorsAggr = movmax(impostorsNorm, param.numScoreAggregate);

%error metrics
%normal
[EERNorm, ~, ~, ~, FMR1000Norm, fprNorm, fnrNorm] = ...
    indiciStatisticiIncertezzaVLFEAT(genuinesNorm, impostorsNorm, [], [], [], 0, 0);
%Aggr
[EERAggr, ~, ~, ~, FMR1000Aggr, fprAggr, fnrAggr] = ...
    indiciStatisticiIncertezzaVLFEAT(genuinesAggr, impostorsAggr, [], [], [], 0, 0);

%calcoliamo mean genuine e impostor per individuo
% genuineInd(genuineInd == -1) = [];
% impostorInd(impostorInd == -1) = [];

% assignin('base', 'genuineInd', genuineInd);
% assignin('base', 'impostorInd', impostorInd);
% assignin('base', 'numImagesTest', numImagesTest);
% assignin('base', 'distMatrix', distMatrix);



% pause


=======
function [distMatrix, genuineInd, impostorInd, genuinesNorm, impostorsNorm, genuinesAggr, impostorsAggr, fprNorm, fnrNorm, fprAggr, fnrAggr, EERNorm, EERAggr, ...
    FMR1000Norm, FMR1000Aggr, genuineDist, impostorDist] = ...
    computeVerificationPerformance(numImagesTest, ftest_all, filenameTest, stepPrint, param)

%init
genuinesNorm = -1 .* ones(numImagesTest^2, 1);
impostorsNorm = -1 .* ones(numImagesTest^2, 1);
countGen = 1;
countImp = 1;
genuineInd = nan(numImagesTest, numImagesTest);
impostorInd = nan(numImagesTest, numImagesTest);

%%%
genuinesAggr = [];
impostorsAggr = [];
fprNorm = [];
fnrNorm = [];
fprAggr = [];
fnrAggr = [];
EERNorm = [];
EERAggr = [];
%%%


% assignin('base', 'ftestPCA_all', ftestPCA_all);
% pause

if strcmp(param.matchDistance, 'chisq')
    distMatrix = sc_pdist2(ftest_all, ftest_all, 'chisq');
elseif strcmp(param.matchDistance, 'euclidean')
    %fast Euclidean distance
    distMatrix = full(fastEuclideanDistance(ftest_all, ftest_all));
else %if strcmp
    distMatrix = pdist2(ftest_all', ftest_all', param.matchDistance);
end %if strcmp



%%%%%%%%%%%%%%%%%%%%%%%%%
% return
%%%%%%%%%%%%%%%%%%%%%%%%%

for i = 1 : numImagesTest
    
    %display progress
    if mod(i, stepPrint) == 0
        fprintf(1, ['\t\tRow ' num2str(i) ' processed\n'])
    end %if mod(i, 100) == 0
    %label
    %     label_1 = real(str2doubleq(getIndName(filenameTestPCA{i})));
    %     label_1 = str2double(getIndName(filenameTestPCA{i}));
%     label_1 = getIndName(filenameTestPCA{i});

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    label_1 = filenameTest{i}(1:4);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %j
    for j = 1 : numImagesTest
        if i == j
            continue;
        end %if i==j
        %         label_2 = real(str2doubleq(getIndName(filenameTestPCA{j})));
        %         label_2 = str2double(getIndName(filenameTestPCA{j}));
        %label_2 = getIndName(filenameTestPCA{j});
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        label_2 = filenameTest{j}(1:4);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        score = distMatrix(i, j);
        %         if label_1 == label_2
        if strcmp(label_1, label_2)
            genuinesNorm(countGen) = score;
            %calcoliamo mean genuine e impostor per individuo
            genuineInd(i,j) = score;
            countGen = countGen + 1;
        else %if label_1 == label_2
            impostorsNorm(countImp) = score;
            %calcoliamo mean genuine e impostor per individuo
            impostorInd(i,j) = score;
            countImp = countImp + 1;
        end %if label_1 == label_2
        

    end %for j
end %for i
%remove excess
genuinesNorm(countGen : end) = [];
impostorsNorm(countImp : end) = [];

%mantainDist
genuineDist = genuinesNorm;
impostorDist = impostorsNorm;

%convert distance to similarity
maxgi = max([genuinesNorm; impostorsNorm]) + 10;
genuinesNorm = maxgi - genuinesNorm;
impostorsNorm = maxgi - impostorsNorm;

%aggregate scores
genuinesAggr = movmax(genuinesNorm, param.numScoreAggregate);
impostorsAggr = movmax(impostorsNorm, param.numScoreAggregate);

%error metrics
%normal
[EERNorm, ~, ~, ~, FMR1000Norm, fprNorm, fnrNorm] = ...
    indiciStatisticiIncertezzaVLFEAT(genuinesNorm, impostorsNorm, [], [], [], 0, 0);
%Aggr
[EERAggr, ~, ~, ~, FMR1000Aggr, fprAggr, fnrAggr] = ...
    indiciStatisticiIncertezzaVLFEAT(genuinesAggr, impostorsAggr, [], [], [], 0, 0);

%calcoliamo mean genuine e impostor per individuo
% genuineInd(genuineInd == -1) = [];
% impostorInd(impostorInd == -1) = [];

% assignin('base', 'genuineInd', genuineInd);
% assignin('base', 'impostorInd', impostorInd);
% assignin('base', 'numImagesTest', numImagesTest);
% assignin('base', 'distMatrix', distMatrix);



% pause


>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
