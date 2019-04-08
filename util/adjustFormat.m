function [imagesCellTrain, imageSize] = adjustFormat(imagesCellTrain)

%compute image size
%image size must be a power of 2
im = imagesCellTrain{1};
closPow2 = pow2(floor(log2(size(im,1))));
imageSize = [closPow2 closPow2];

for i = 1 : numel(imagesCellTrain)
    
    %load
    im = imagesCellTrain{i};
    
    %back to rgb
    im = im2uint8(im);
    %cast
    im = double(im);
    %image size must be a power of 2
    im = imresize(im, imageSize);
    %subtract mean
    im = im - mean2(im);
    
    %assign
    imagesCellTrain{i} = im;
    
end %for i = 1 : numel(imagesCellTrain)