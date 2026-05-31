function [imagesCellTrain, filenameTrn] = loadImages(files, dirDB, allIndexes, indImagesTrain, numImagesTrain, plotta)

%init
vectorIndexTrain = allIndexes(indImagesTrain);
filenameTrn = cell(length(vectorIndexTrain), 1);
imagesCellTrain = cell(numImagesTrain, 1);

%loop
for i = 1 : length(vectorIndexTrain)
    
    filenameTrn{i} = files(vectorIndexTrain(i)).name;
    im = im2double(imread([dirDB filenameTrn{i}]));
     
    if size(im, 3) == 3
        imagesCellTrain{i, 1} = rgb2gray(im);
    else %if size
        imagesCellTrain{i, 1} = im;
    end %if size
end %for i = 1 : numImages

%display
if plotta
    numSample = min([144, numel(imagesCellTrain)]);
    indexM = randsample(numel(imagesCellTrain), numSample);
    figure,
    montage(imagesCellTrain(indexM), 'DisplayRange', [], 'Size', [9 16])
    title('Random subset of images');   
end %if plotta

