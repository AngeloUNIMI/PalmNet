function [f, BlkIdx] = Gabor_FeaExt(InImg, PalmNet, bestWavelets, param)
% =======INPUT=============
% InImg     Input images (cell)
% V         given PCA filter banks (cell)
% PCANet    PCANet parameters (struct)
%       .PCANet.NumStages
%           the number of stages in PCANet; e.g., 2
%       .PatchSize
%           the patch size (filter size) for square patches; e.g., [5 3]
%           means patch size equalt to 5 and 3 in the first stage and second stage, respectively
%       .NumFilters
%           the number of filters in each stage; e.g., [16 8] means 16 and
%           8 filters in the first stage and second stage, respectively
%       .HistBlockSize
%           the size of each block for local histogram; e.g., [10 10]
%       .BlkOverLapRatio
%           overlapped block region ratio; e.g., 0 means no overlapped
%           between blocks, and 0.3 means 30% of blocksize is overlapped
%       .Pyramid
%           spatial pyramid matching; e.g., [1 2 4], and [] if no Pyramid
%           is applied
% =======OUTPUT============
% f         PCANet features (each column corresponds to feature of each image)
% BlkIdx    index of local block from which the histogram is compuated
% =========================

% addpath('./Utils')

if length(PalmNet.NumFilters)~= PalmNet.NumStages
    fprintf('Length(GNet.NumFilters)~=GNet.NumStages\n')
    return
end

NumImg = length(InImg);

OutImg = InImg;
ImgIdx = (1:NumImg)';
clear InImg;

for stage = 1:PalmNet.NumStages
    
    if stage == 1
        
        %gabor output
        OutImg = Gabor_output(OutImg, bestWavelets, PalmNet.NumFilters(stage));
        OutImgIdx = kron(ImgIdx, ones(PalmNet.NumFilters(stage),1));
        
    else %if stage == 1
        
        %gabor output
        OutImg = Gabor_output(OutImg, bestWavelets, PalmNet.NumFilters(stage));
        OutImgIdx = kron(OutImgIdx, ones(PalmNet.NumFilters(end),1));
        
    end %if stage == 1
    
end %for stage

[f, BlkIdx] = HashingHist(PalmNet, OutImgIdx, OutImg);

% assignin('base', 'OutImg', OutImg);
% assignin('base', 'PCANet', PCANet);
% assignin('base', 'ImgIdx', ImgIdx);
% pause



