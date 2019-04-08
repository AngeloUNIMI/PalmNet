
%------------------------------
%General parameters
param.numIterations = 5; %number of re-iterations.
param.kfold = 2; %k-1 partition used for training; 1 partitions for testing
%knn parameters
param.knn_neighbors = 1;
param.matchDistance = 'euclidean';
param.knnDistance = 'euclidean';
%param.matchDistance = 'chisq';
%param.knnDistance = 'chisq';
param.numScoreAggregate = 4; %4 usato in paper recenti
param.useDynamicNumFilters = 0;
param.RetainedVariance = [0.89 0.94];

%------------------------------
%Parameters orientation search
param.numBins = 45;
param.divTheta = 10; %orientamenti campionati
param.maxOrient = 10; %12 %orientamenti adattativi

%------------------------------
%Parameters Gabor from scales
param.N = 1; %sampling points per octave
param.b0 = 1; %the unit spatial interval
param.phai = 1.5; %band width of gabor [octave]
param.aspectRatio = 1;  %aspect ratio of the gabor filter

%------------------------------
%Parameters Gabor parametrized
param.divThetaParametrized = param.divTheta;
param.sigma = 5.6179; %used for generating Gabor filter
param.wavelength = 0.11; %used for generating Gabor filter

%------------------------------
%Parameters wavelet add
param.numWavelets = 10000;
param.minMSE = 0.005;
param.minCountW = 2000;
param.numBestWavelets = 5;

%------------------------------
%PCANet parameters
PalmNet.NumStages = 2; %2
PalmNet.PatchSize = [15, 15]; %(default  [5 5]) ([15 15] seems good for iitd)
PalmNet.NumFilters = [(param.divThetaParametrized + param.numBestWavelets), (param.divThetaParametrized + param.numBestWavelets)]; % (default [8 8]) ([10 10] seems good for iitd)
PalmNet.HistBlockSize = [23, 23]; %(default 15 15) ([23 23] seems good for iitd)
PalmNet.BlkOverLapRatio = 0;
PalmNet.Pyramid = [];






