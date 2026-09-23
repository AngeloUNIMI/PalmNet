function [imagesCellTrain, filenameTrnPCA] = loadImagesTrainingColor(files, dirDB, allIndexes, indImagesTrain, numImagesTrain)

%init
vectorIndexTrain = allIndexes(indImagesTrain);
filenameTrnPCA = cell(length(vectorIndexTrain), 1);
imagesCellTrain = cell(numImagesTrain, 1);
for i = 1 : length(vectorIndexTrain)
    filenameTrnPCA{i} = files(vectorIndexTrain(i)).name;
    im = im2double(imread([dirDB filenameTrnPCA{i}]));
    imagesCellTrain{i, 1} = im;
end %for i = 1 : numImages