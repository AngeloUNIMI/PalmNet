function [ftest_all, numFeatures] = ...
    featExtrGaborAdapt(imagesCellTest, PalmNet, bestWavelets, param, numImagesTest, stepPrint, numCoresFeatExtr)

%one iteration to get size and init
ftest = Gabor_FeaExt(imagesCellTest(1), PalmNet, bestWavelets, param);
numFeatures = size(ftest,1);
%init feature matrix
ftest_all = sparse(numFeatures, numImagesTest);
ftest_all(:, 1) = ftest;

start_pool(numCoresFeatExtr);
%start pool
%parto da 2 perchè 1 ho già fatto
parfor j = 2 : numel(imagesCellTest)
% for j = 2 : length(vectorIndexTest)
    
    %get id of current worker
%     t = getCurrentTask();
    
    %display progress
    if mod(j, stepPrint) == 0
%         fprintf(1, ['\t\tCore ' num2str(t.ID) ': ' num2str(j) ' / ' num2str(numImagesTest) '\n'])
    end %if mod(i, 100) == 0
    
    %imt = im2double(imread([dirDB filenameTest{j}]));
    %image size must be a power of 2
    %imt = imresize(imt, imageSize);
    
    %get image
    im = imagesCellTest(j);
    
    %PCANet output
    ftest = Gabor_FeaExt(im, PalmNet, bestWavelets, param);
    
    %whos ftest
    
    %save descriptor
    %w/out wpca
    ftest_all(:, j) = ftest;
    
end %parfor i = 1 : numImagesTest



