<<<<<<< HEAD
function [genuinesNorm, impostorsNorm, genuinesAggr, impostorsAggr, genuinesBestRot, impostorsBestRot, fprNorm, fnrNorm, fprAggr, fnrAggr, fprBestRot, fnrBestRot] = ...
    computeVerificationPerformanceRot(numImagesTest, distMatrix, distMatrixBestRot, filenameTestPCA, stepPrint, param)

% distMatrix
% distMatrixBestRot
% 
% pause


%init
genuinesNorm = -1 .* ones(numImagesTest^2, 1);
impostorsNorm = -1 .* ones(numImagesTest^2, 1);
genuinesBestRot = -1 .* ones(numImagesTest^2, 1);
impostorsBestRot = -1 .* ones(numImagesTest^2, 1);
countGen = 1;
countImp = 1;

%wpca
if param.wpca
    ftestPCA_all = ftestPCA_Wpca_all;
end %if param.wpca

%time
tic

%assign scores from dist matrix to genuines/impostors
for i = 1 : numImagesTest
    
    %display progress
    if mod(i, stepPrint) == 0
        fprintf(1, ['\t\tRow ' num2str(i) ' processed\n'])
    end %if mod(i, 100) == 0
    %label
    label_1 = str2double(getIndName(filenameTestPCA{i}));
    
    %j
    for j = 1 : numImagesTest
        
        if i == j || i > j %cosi ignoriamo la metà triangolare sotto
            continue;
        end %if i==j
        
        %label
        label_2 = str2double(getIndName(filenameTestPCA{j}));
        
        scoreNormal = distMatrix(i, j);
        scoreBestRot = distMatrixBestRot(i, j);
        
        if label_1 == label_2
            genuinesNorm(countGen) = scoreNormal;
            genuinesBestRot(countGen) = scoreBestRot;
            countGen = countGen + 1;
        else %if label_1 == label_2
            impostorsNorm(countImp) = scoreNormal;
            impostorsBestRot(countImp) = scoreBestRot;
            countImp = countImp + 1;
        end %if label_1 == label_2
        
    end %for j
    
end %for i

%remove excess
genuinesNorm(countGen : end) = [];
impostorsNorm(countImp : end) = [];
genuinesBestRot(countGen : end) = [];
impostorsBestRot(countImp : end) = [];

% pause

%convert distance to similarity
maxgi = max([genuinesNorm; impostorsNorm]) + 10;
genuinesNorm = maxgi - genuinesNorm;
impostorsNorm = maxgi - impostorsNorm;
maxgi = max([genuinesBestRot; impostorsBestRot]) + 10;
genuinesBestRot = maxgi - genuinesBestRot;
impostorsBestRot = maxgi - impostorsBestRot;

%aggregate scores
genuinesAggr = movmax(genuinesNorm, param.numScoreAggregate);
impostorsAggr = movmax(impostorsNorm, param.numScoreAggregate);

%error metrics
%normal
[~, ~, ~, ~, ~, fprNorm, fnrNorm] = ...
    indiciStatisticiIncertezzaVLFEAT(genuinesNorm, impostorsNorm, [], [], [], 0, 0);
%aggreg
[~, ~, ~, ~, ~, fprAggr, fnrAggr] = ...
    indiciStatisticiIncertezzaVLFEAT(genuinesAggr, impostorsAggr, [], [], [], 0, 0);
%best rot
[~, ~, ~, ~, ~, fprBestRot, fnrBestRot] = ...
    indiciStatisticiIncertezzaVLFEAT(genuinesBestRot, impostorsBestRot, [], [], [], 0, 0);




=======
function [genuinesNorm, impostorsNorm, genuinesAggr, impostorsAggr, genuinesBestRot, impostorsBestRot, fprNorm, fnrNorm, fprAggr, fnrAggr, fprBestRot, fnrBestRot] = ...
    computeVerificationPerformanceRot(numImagesTest, distMatrix, distMatrixBestRot, filenameTestPCA, stepPrint, param)

% distMatrix
% distMatrixBestRot
% 
% pause


%init
genuinesNorm = -1 .* ones(numImagesTest^2, 1);
impostorsNorm = -1 .* ones(numImagesTest^2, 1);
genuinesBestRot = -1 .* ones(numImagesTest^2, 1);
impostorsBestRot = -1 .* ones(numImagesTest^2, 1);
countGen = 1;
countImp = 1;

%wpca
if param.wpca
    ftestPCA_all = ftestPCA_Wpca_all;
end %if param.wpca

%time
tic

%assign scores from dist matrix to genuines/impostors
for i = 1 : numImagesTest
    
    %display progress
    if mod(i, stepPrint) == 0
        fprintf(1, ['\t\tRow ' num2str(i) ' processed\n'])
    end %if mod(i, 100) == 0
    %label
    label_1 = str2double(getIndName(filenameTestPCA{i}));
    
    %j
    for j = 1 : numImagesTest
        
        if i == j || i > j %cosi ignoriamo la metà triangolare sotto
            continue;
        end %if i==j
        
        %label
        label_2 = str2double(getIndName(filenameTestPCA{j}));
        
        scoreNormal = distMatrix(i, j);
        scoreBestRot = distMatrixBestRot(i, j);
        
        if label_1 == label_2
            genuinesNorm(countGen) = scoreNormal;
            genuinesBestRot(countGen) = scoreBestRot;
            countGen = countGen + 1;
        else %if label_1 == label_2
            impostorsNorm(countImp) = scoreNormal;
            impostorsBestRot(countImp) = scoreBestRot;
            countImp = countImp + 1;
        end %if label_1 == label_2
        
    end %for j
    
end %for i

%remove excess
genuinesNorm(countGen : end) = [];
impostorsNorm(countImp : end) = [];
genuinesBestRot(countGen : end) = [];
impostorsBestRot(countImp : end) = [];

% pause

%convert distance to similarity
maxgi = max([genuinesNorm; impostorsNorm]) + 10;
genuinesNorm = maxgi - genuinesNorm;
impostorsNorm = maxgi - impostorsNorm;
maxgi = max([genuinesBestRot; impostorsBestRot]) + 10;
genuinesBestRot = maxgi - genuinesBestRot;
impostorsBestRot = maxgi - impostorsBestRot;

%aggregate scores
genuinesAggr = movmax(genuinesNorm, param.numScoreAggregate);
impostorsAggr = movmax(impostorsNorm, param.numScoreAggregate);

%error metrics
%normal
[~, ~, ~, ~, ~, fprNorm, fnrNorm] = ...
    indiciStatisticiIncertezzaVLFEAT(genuinesNorm, impostorsNorm, [], [], [], 0, 0);
%aggreg
[~, ~, ~, ~, ~, fprAggr, fnrAggr] = ...
    indiciStatisticiIncertezzaVLFEAT(genuinesAggr, impostorsAggr, [], [], [], 0, 0);
%best rot
[~, ~, ~, ~, ~, fprBestRot, fnrBestRot] = ...
    indiciStatisticiIncertezzaVLFEAT(genuinesBestRot, impostorsBestRot, [], [], [], 0, 0);




>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
