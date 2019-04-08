function [bestWaveletsAll, PalmNet] = findBestWaveletsTesting(imagesCell, orient_default, orient_best, PalmNet, numImagesToUse, imageSize, param, stepPrint, plotta)

%init
bestWaveletsAll(param.numBestWavelets).filter = [];


%--------------------------------------
%Compute parametrized wavelets
parametrizedWavelets = gaborArrayParametrized(param.sigma, param.wavelength, deg2rad(orient_default));


%--------------------------------------
%Compute complete multi-scale Gabor filter bank
%fprintf_pers(fidLogs, '\t\tComputing Gabor array... \n')
gaborBank = gaborArrayFromScales(imageSize, deg2rad(unique([orient_default orient_best])), param, plotta);

%init counter for how many times each wavelet is chosen
o_counterAll = zeros(numel(gaborBank), 1);


    if plotta
        fsfigure
        for indf = 1 : param.divThetaParametrized
            %sum(real(parametrizedWavelets(indf).filter(:)))
            subplot(1,param.divThetaParametrized,indf)
            imshow(real(parametrizedWavelets(indf).filter),[])
            axis on
            axis image
        end %for indf
        suplabel([num2str(param.divThetaParametrized) ' filters fixed']);
        figure,
        imhist(real(parametrizedWavelets(indf).filter))
        pause
    end %if plotta



%loop on images
parfor j = 1 : numImagesToUse
% for j = 1 : numel(imagesCell)
    
    %get id of current worker
    t = getCurrentTask();
    
    %display progress
    if mod(j, stepPrint) == 0
        fprintf(1, ['\t\tCore ' num2str(t.ID) ': ' num2str(j) ' / ' num2str(numImagesToUse) '\n'])
    end %if mod(i, 100) == 0
    
    %get img
    im = imagesCell{j};
    
      
    %--------------------------------------
    %Perform reference Gabor filtering
    %fprintf_pers(fidLogs, '\t\tPerforming reference Gabor filtering... \n')
    resF = referenceGaborFilter(gaborBank, im);
    
    
    %--------------------------------------
    %create powerMap for all filters
    %fprintf_pers(fidLogs, '\t\tComputing powermaps... \n')
    powerMapF = computePowerMaps(resF, gaborBank);
    
    
    %--------------------------------------
    %Sort filter response information
    %fprintf_pers(fidLogs, '\t\tSorting filter response information... \n')
    [sortRes, sizeRes] = sortFilterResponse(gaborBank, powerMapF);
    
    
    %--------------------------------------
    %Compute most used wavelets
    %fprintf_pers(fidLogs, '\t\t\tComputing most used wavelets... \n')
    o_counter = getMostUsedWavelets(sortRes, gaborBank, powerMapF, param, sizeRes, plotta);
    
    %increment
    o_counterAll = o_counterAll + o_counter;
    
end %for j = 1 : length(vectorIndexTest)


%display most used filters
if plotta
    figure,
    bar(1:size(o_counterAll), o_counterAll)
    xlabel('Wavelet n.')
    ylabel('Perc. of occurence')
    title('Most used wavelets');
end %if plotta


%--------------------------------------
%sort most used filters counter
[~, ind_o_counter_All_sort] = sort(o_counterAll, 'descend');

%consider only best wavelets
ind_o_counter_All_sort = ind_o_counter_All_sort(1 : param.numBestWavelets);
bestWavelets = gaborBank(ind_o_counter_All_sort);

%display bestWavelets
if plotta
    fsfigure
    for indf = 1 : numel(bestWavelets)
        subplot(1, numel(bestWavelets),indf)
        imshow(bestWavelets(indf).even,[])
        axis on
        axis image
    end %for indf
    suplabel([num2str(numel(bestWavelets)) ' filters most used']);
end %if plotta


%--------------------------------------
%assign to global structure
countfilter = 1;

%parametrized
for o = 1 : numel(parametrizedWavelets)
    bestWaveletsAll(countfilter).filter = parametrizedWavelets(o).filter;
    countfilter = countfilter + 1;
end %for o

%dynamic
for o = 1 : numel(bestWavelets)
    bestWaveletsAll(countfilter).filter = complex(bestWavelets(o).even, bestWavelets(o).odd);
    countfilter = countfilter + 1;
end %for o

%display
%     if plotta
%         bestWaveletsCell = squeeze(struct2cell(bestWavelets));
%         figure,
%         subplot(1,2,1)
%         montage(bestWaveletsCell(1,:), 'DisplayRange', [])
%         axis on
%         axis image
%         title('Best wavelets: even');
%         subplot(1,2,2)
%         montage(bestWaveletsCell(2,:), 'DisplayRange', [])
%         title('Best wavelets: odd');
%         pause
%     end %if plotta


%--------------------------------------
%update number of filters
%assign updated number of filters to PCANet
PalmNet.NumFilters(end) = numel(bestWaveletsAll);




