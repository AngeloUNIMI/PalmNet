clc
close all
clear variables
%delete(gcp('nocreate'));
fclose('all');
warning('on', 'all')
warning('off', 'MATLAB:mir_warning_maybe_uninitialized_temporary');
warning('off', 'MATLAB:dispatcher:nameConflict');
warning('off', 'MATLAB:plot:IgnoreImaginaryXYPart');
addpath(genpath('./functions_DBProc'));
addpath(genpath('./functions_Biometrics'));
addpath(genpath('./functions_Classifiers'));
addpath(genpath('./histogram_distance'));
addpath(genpath('./functions_Kovesi'));
addpath(genpath('./functions_Gabor'));
addpath(genpath('./functions_Orient'));
addpath(genpath('./functions_Freq'));
addpath(genpath('./functions_FeatExtr'));
addpath(genpath('./util'));

%--------------------------------------
%General parameters
plot = 0; %plot figures
savefile = 1; %saves data
logS = 1; %output logs
fidLogs{1} = 1; %stdoutput
numCoresFeatExtr = 2; %number of cores used for feature extraction
numCoresKnn = 2; %number of cores used for knn classification
stepPrint = 100;
%PCA Params
run('./params/paramsPalmNet.m'); %parameter file


%--------------------------------------
%Directory of DBs
ext = 'bmp'; %extension of images
dbname = 'Tongji_Contactless_Palmprint_Dataset';
dirDB = ['./images/' dbname '/'];


%--------------------------------------
%Folder creation
%RESULTS: dirs net
dirResults = ['./Results/' dbname '/'];
mkdir_pers(dirResults, savefile);
fileSaveTest = [dirResults 'PalmNet_test.mat'];
fileSaveResults = [dirResults 'PalmNet_results.mat'];
%RESULTS: log file
timeStampRaw = datestr(datetime);
timeStamp = strrep(timeStampRaw, ':', '-');
if savefile && logS
    logFile = [dirResults dbname '_log_' timeStamp '.txt'];
    fidLog = fopen(logFile, 'w');
    fidLogs{2} = fidLog;
end %if savefile && log


%--------------------------------------
%Display
fprintf_pers(fidLogs, '\n');
fprintf_pers(fidLogs, '---------------\n');
fprintf_pers(fidLogs, 'PalmNet\n');
fprintf_pers(fidLogs, [dbname '\n']);
fprintf_pers(fidLogs, '---------------\n');
fprintf_pers(fidLogs, '\n');


%--------------------------------------
%DB processing
%Extract samples
files = dir([dirDB '*.' ext]);
%Check that there is at least one sample for each individual
files = checkMinNumSamplePerInd(files);
%Compute labels
[labels, numImagesAll] = computeLabels(files);
%Compute number of individuals
numInd = numel(unique(labels));
%compute number of sample per individual
numSamplePerInd = getNumSamplePerInd(files);


%--------------------------------------
%Display
fprintf_pers(fidLogs, 'Extracting samples...\n');
fprintf_pers(fidLogs, ['\t' num2str(numInd) ' individuals\n']);
fprintf_pers(fidLogs, ['\t' num2str(round(mean(numSamplePerInd))) ' samples per individual, on average\n']);
fprintf_pers(fidLogs, ['\t' num2str(numImagesAll) ' images in total\n']);
fprintf_pers(fidLogs, '\n');


%--------------------------------------
%LOOP ON ITERATIONS
%Init
genuinesNorm_iter = cell(param.numIterations, 1);
impostorsNorm_iter = cell(param.numIterations, 1);
fprNorm_iter = cell(param.numIterations, 1);
fnrNorm_iter = cell(param.numIterations, 1);
genuinesAggr_iter = cell(param.numIterations, 1);
impostorsAggr_iter = cell(param.numIterations, 1);
fprAggr_iter = cell(param.numIterations, 1);
fnrAggr_iter = cell(param.numIterations, 1);
accuracy_knnAll = zeros(param.numIterations, 1);
EERNormIter = zeros(param.numIterations, 1);
EERAggrIter = zeros(param.numIterations, 1);
FMR1000NormIter = zeros(param.numIterations, 1);
FMR1000AggrIter = zeros(param.numIterations, 1);

%Loop on iterations (e.g., 5)
for r = 1 : param.numIterations
    
    
    %--------------------------------------
    %Display
    fprintf_pers(fidLogs, ['Iteration N. ' num2str(r) '\n']);
    
    
    %--------------------------------------
    %File save info
    [C, indC] = strsplit(fileSaveTest, '.');
    fileSaveTest_iter = [indC{1} C{1:end-1} '_iter_' num2str(r) '.mat'];
    
    
    %--------------------------------------
    %Compute random person-fold indexes
    [indexesFold, allIndexes, indImagesTrain, indImagesTest, numImagesTrain, numImagesTest] = computeIndexesPersonFold(numImagesAll, labels, param);
    %Corresponding labels
    TrnLabels = labels(indImagesTrain);
    TestLabels = labels(indImagesTest);
    
    
    %--------------------------------------
    %Display output number of images
    fprintf_pers(fidLogs, ['\t' num2str(numImagesTrain) ' images are chosen for training \n']);
    fprintf_pers(fidLogs, ['\t\t' num2str(numel(unique(TrnLabels))) ' individuals for training \n']);
    fprintf_pers(fidLogs, ['\t' num2str(numImagesTest) ' images are chosen for testing \n']);
    fprintf_pers(fidLogs, ['\t\t' num2str(numel(unique(TestLabels))) ' individuals for testing \n']);
    
    
    
    %%%%%%%%%%%%%%  TRAINING  %%%%%%%%%%%%%
    start_pool(numCoresFeatExtr);
    
    %--------------------------------------
    fprintf_pers(fidLogs, '\tTraining... \n')
    
    %--------------------------------------
    %Load images for training
    fprintf_pers(fidLogs, '\t\tLoading images for training... \n')
    [imagesCellTrain, filenameTrn] = loadImages(files, dirDB, allIndexes, indImagesTrain, numImagesTrain, plot);
    
    
    %--------------------------------------
    %Adjusting format
    fprintf_pers(fidLogs, '\t\tAdjusting format...\n');
    [imagesCellTrain, imageSize] = adjustFormat(imagesCellTrain);
    
    
    %--------------------------------------
    %Compute average spectrum of training images
    %fprintf_pers(fidLogs, '\t\tComputing average image spectrum... \n')
    %Fimgdisp_all = computeAverageSpectrum(imagesCellTrain, plotta);
    
    
    %--------------------------------------
    %Search for orientations
    fprintf_pers(fidLogs, '\t\tSearching for best orientations... \n')
    %default orientations by sampling
    orient_default = 0 : (180/param.divTheta) : 180-(180/param.divTheta);
    %adaptive orientations by gradient
    orient_best = searchGaborOrientation(imagesCellTrain, param, plot);
    %merge
    %orient_chosen = unique([orient_default orient_best]);
    %orient_chosen = orient_default;
    %orient_chosen = orient_best;
    
    
    %--------------------------------------
    %Gabor analysis
    fprintf_pers(fidLogs, '\t\tGabor analysis... \n')
    tic
    [bestWaveletsAll, PalmNet] = findBestWaveletsTesting(imagesCellTrain, orient_default, orient_best, PalmNet, numImagesTrain, imageSize, param, stepPrint, plot);
    t = toc;
    fprintf_pers(fidLogs, ['\t\t\tGabor analysis time: ' num2str(t) '\n']);
    fprintf_pers(fidLogs, ['\t\t\tTotal number of Gabor wavelets: ' num2str(PalmNet.NumFilters(end)) '\n']);
    
    
    
    
    
    %%%%%%%%%%%%%%  TESTING  %%%%%%%%%%%%%
    %--------------------------------------
    fprintf_pers(fidLogs, '\tTesting... \n')
    
    
    %--------------------------------------
    %Load images for testing
    fprintf_pers(fidLogs, '\t\tLoading images for testing... \n')
    [imagesCellTest, filenameTest] = loadImages(files, dirDB, allIndexes, indImagesTest, numImagesTest, plot);
    
    
    %--------------------------------------
    %Adjusting format
    fprintf_pers(fidLogs, '\t\tAdjusting format...\n');
    [imagesCellTest, imageSize] = adjustFormat(imagesCellTest);
    
    
    
    
    %--------------------------------------
    %Feature extraction
    fprintf_pers(fidLogs, '\t\tFeature extraction... \n')
    [ftest_all, numFeatures] = featExtrGaborAdapt(imagesCellTest, PalmNet, bestWaveletsAll, param, numImagesTest, stepPrint, numCoresFeatExtr);
    sizeTest = size(ftest_all, 2);
    
    
    %--------------------------------------
    %Save features
    if savefile
        save(fileSaveTest_iter, 'TrnLabels', 'TestLabels', 'filenameTrn', 'filenameTest', 'ftest_all');
    end %if savefile
    %Puliamo
    clear imagesCellTest
    
    
    %--------------------------------------
    %Verification performance
    %EER computation
    fprintf_pers(fidLogs, '\tFPR and FNR computation\n');
    %time
    tic
    [distMatrix, genuineInd, impostorInd, genuinesNorm, impostorsNorm, genuinesAggr, impostorsAggr, fprNorm, fnrNorm, fprAggr, fnrAggr, ...
        EERNorm, EERAggr, FMR1000Norm, FMR1000Aggr] = ...
        computeVerificationPerformance(numImagesTest, ftest_all, filenameTest, stepPrint, param);
    %put in iteration data struct
    genuinesNorm_iter{r} = genuinesNorm;
    impostorsNorm_iter{r} = impostorsNorm;
    fprNorm_iter{r} = fprNorm;
    fnrNorm_iter{r} = fnrNorm;
    genuinesAggr_iter{r} = genuinesAggr;
    impostorsAggr_iter{r} = impostorsAggr;
    fprAggr_iter{r} = fprAggr;
    fnrAggr_iter{r} = fnrAggr;
    EERNormIter(r) = EERNorm;
    EERAggrIter(r) = EERAggr;
    FMR1000NormIter(r) = FMR1000Norm;
    FMR1000AggrIter(r) = FMR1000Aggr;
    %Time for FPR FNR computation
    timeFPRFNR = toc;
    fprintf_pers(fidLogs, ['\t\tTime for FPR and FNR computation: ' num2str(timeFPRFNR) ' s\n']);
    fprintf_pers(fidLogs, ['\t\tEER at iteration n. ' num2str(r) ': %s%%\n'], num2str(EERNormIter(r)*100));
    fprintf_pers(fidLogs, ['\t\tFMR1000 at iteration n. ' num2str(r) ': %s%%\n'], num2str(FMR1000NormIter(r)*100));
    fprintf_pers(fidLogs, ['\t\tEER (aggregated over ' num2str(param.numScoreAggregate) ' scores) at iteration n. ' num2str(r) ': %s%%\n'], ...
        num2str(EERAggrIter(r)*100));
    fprintf_pers(fidLogs, ['\t\tFMR1000 (aggregated over ' num2str(param.numScoreAggregate) ' scores) at iteration n. ' num2str(r) ': %s%%\n'], ...
        num2str(FMR1000AggrIter(r)*100));
    
    
    %--------------------------------------
    %Save verification error measures
    if savefile
        save(fileSaveTest_iter, 'distMatrix', 'genuineInd', 'impostorInd', 'genuinesNorm', 'impostorsNorm', 'genuinesAggr', 'impostorsAggr', ...
            'fprNorm', 'fnrNorm', 'fprAggr', 'fnrAggr', 'EERNorm', 'EERAggr', 'FMR1000Norm', 'FMR1000Aggr', '-append');
    end %if savefile
    %Puliamo
    clear genuines impostors genuinesAggr impostorsAggr
    
    
    %--------------------------------------
    %Classification performance
    %1-NN classifier (Nearest Neighbor)
    fprintf_pers(fidLogs, '\tClassification... \n');
    %display
    fprintf_pers(fidLogs, ['\t\tNumber of features: ' num2str(numFeatures) '\n']);
    fprintf_pers(fidLogs, ['\t\tNumber of samples: ' num2str(sizeTest) '\n']);
    %time
    tic
    TestOutput = computekNNClassificationPerformance(ftest_all, TestLabels, sizeTest, distMatrix, stepPrint, numCoresKnn, param);
    %Time for feature extraction
    timeClass = toc;
    fprintf_pers(fidLogs, ['\t\tTime for classification: ' num2str(timeClass) ' s\n']);
    %Confusion matrix
    C_knn = confusionmat(TestLabels, TestOutput);
    %Error metrics
    err_knn = getNumberMisclassifiedSamples(C_knn);
    accuracy_knn = (sum(C_knn(:)) - err_knn) / sum(C_knn(:));
    accuracy_knnAll(r) = accuracy_knn;
    %Display
    fprintf_pers(fidLogs, ...
        ['\t\tAccuracy (perc. of correctly classified samples, at iteration n. ' num2str(r) '): %s%%\n'], num2str(accuracy_knn*100));
    
    
    %Puliamo
    clear ftest_all
    
    
    %--------------------------------------
    %Save
    if savefile
        save(fileSaveTest_iter, 'TestOutput', 'C_knn', 'err_knn', 'accuracy_knn', '-append');
    end %if savefile
    
    
    %--------------------------------------
    %Display progress
    fprintf_pers(fidLogs, '\n');
    
    
end %for r = 1 : param.numIterations


%--------------------------------------
%Average verification performance
%EER
%Normal
%Compute average fpr e fnr
EERNormMean = mean(EERNormIter);
EERNormStd = std(EERNormIter);
FMR1000NormMean = mean(FMR1000NormIter);
FMR1000NormStd = std(FMR1000NormIter);
%Display
fprintf_pers(fidLogs, ['Mean EER (computed from FPR and FNR, averaged over ' num2str(param.numIterations) ' iterations): %s%%\n'], num2str(EERNormMean*100));
fprintf_pers(fidLogs, ['Mean FMR1000 (computed from FPR and FNR, averaged over ' num2str(param.numIterations) ' iterations): %s%%\n'], num2str(FMR1000NormMean*100));
fprintf_pers(fidLogs, ['Std EER (computed from FPR and FNR, averaged over ' num2str(param.numIterations) ' iterations): %s%%\n'], num2str(EERNormStd*100));
fprintf_pers(fidLogs, ['Std FMR1000 (computed from FPR and FNR, averaged over ' num2str(param.numIterations) ' iterations): %s%%\n'], num2str(FMR1000NormStd*100));
%Aggr
EERAggrMean = mean(EERAggrIter);
EERAggrStd = std(EERAggrIter);
FMR1000AggrMean = mean(FMR1000AggrIter);
FMR1000AggrStd = std(FMR1000AggrIter);
%Compute average fpr e fnr
%Display
fprintf_pers(fidLogs, ['Mean EER (computed from FPR and FNR, averaged over ' num2str(param.numIterations) ...
    ' iterations, aggregated over ' num2str(param.numScoreAggregate) ' scores): %s%%\n'], num2str(EERAggrMean*100));
fprintf_pers(fidLogs, ['Mean FMR1000 (computed from FPR and FNR, averaged over ' num2str(param.numIterations) ...
    ' iterations, aggregated over ' num2str(param.numScoreAggregate) ' scores): %s%%\n'], num2str(FMR1000AggrMean*100));
fprintf_pers(fidLogs, ['Std EER (computed from FPR and FNR, averaged over ' num2str(param.numIterations) ...
    ' iterations, aggregated over ' num2str(param.numScoreAggregate) ' scores): %s%%\n'], num2str(EERAggrStd*100));
fprintf_pers(fidLogs, ['Std FMR1000 (computed from FPR and FNR, averaged over ' num2str(param.numIterations) ...
    ' iterations, aggregated over ' num2str(param.numScoreAggregate) ' scores): %s%%\n'], num2str(FMR1000AggrStd*100));


%--------------------------------------
%Average classification performance
%Error metrics
accuracy_knnMean = mean(accuracy_knnAll);
accuracy_knnStd = std(accuracy_knnAll);
%Display
fprintf_pers(fidLogs, '\n');
%knn
fprintf_pers(fidLogs, ...
    ['k-NN Mean accuracy (perc. of correctly classified samples, averaged over ' num2str(param.numIterations) ' iterations): %s%%\n'], ...
    num2str(accuracy_knnMean*100));
fprintf_pers(fidLogs, ...
    ['k-NN Std accuracy (std of perc. of correctly classified samples, averaged over ' num2str(param.numIterations) ' iterations): %s%%\n'], ...
    num2str(accuracy_knnStd*100));


%--------------------------------------
%Save
if savefile
    save(fileSaveResults, 'accuracy_knnMean', 'accuracy_knnStd', 'EERNormMean', 'EERNormStd', 'FMR1000NormMean', 'FMR1000NormStd', ...
        'EERAggrMean', 'EERAggrStd', 'FMR1000AggrMean', 'FMR1000AggrStd', 'param');
end %if savefile


%--------------------------------------
%Display progress
fprintf_pers(fidLogs, '\n');


%--------------------------------------
%Close file log
if savefile && logS
    fclose(fidLog);
end %if savefile && log
%         delete(gcp('nocreate'));
fclose('all');



