function [indexesFold, allIndexes, indImagesTrain, indImagesTest, numImagesTrain, numImagesTest] = computeIndexesPersonFold(numImagesAll, labels, param)

indexesFold = personFold(numImagesAll, labels, param.kfold);
indImagesTrain = (indexesFold ~= 1); %1 or 2
indImagesTest = ~indImagesTrain;
allIndexes = 1 : numImagesAll;
numImagesTrain = numel(find(indImagesTrain));
numImagesTest = numel(find(indImagesTest));

