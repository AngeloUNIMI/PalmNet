function orient_chosen = searchGaborOrientation(imagesCellTrain, param, plotta)

%Output:
%orient_chosen: vector of angles (in degrees)

%init
histAll = zeros(1, param.numBins);

%parfor im_index = 1 : numel(imagesCellTrain)
for im_index = 1 : numel(imagesCellTrain)
    %for im_index = 1
    
    %select image
    img = imagesCellTrain{im_index};
    
    %orientation map
    [orientim, reliability] = ridgeorient(img, 0.1, 1.5, 1.5);
    
    %                 figure,
    %                 subplot(1,2,1)
    %                 imshow(img,[])
    %                 subplot(1,2,2)
    %                 imshow(orientim,[])
    
    %convert to deg
    orientim_deg = rad2deg(orientim);
    
    %                                 figure,
    %                                 histogram(orientim_deg, bins);
    %                                 pause
    
    [N, edges, bin] = histcounts(orientim_deg, param.numBins);
    
    %sum for all images
    histAll = histAll + N;
    
    %pause
    
end %for im_index = 1 : numel(imagesCellTrain)

%average hist
histAll = histAll ./ numel(imagesCellTrain);

%compute centers from edges
centers = (edges + circshift(edges, -1))/2;
centers(end) = [];

%remove last element (180=0)
histAll(end) = [];
centers(end) = [];

%convert to anti-cw
centers = 180 - centers;

%di solito si divide Pi/12
%un filtro ogni 15 gradi
%invece prendo i 12 orientamenti più rilevanti
%però devono essere spaziati, non ha senso prenderli troppo
%ravvicinati

%ordino bin per occorrenze
[histAll_sort, histAll_sort_ind] = sort(histAll, 'descend');

%ottengo gli ordinamenti più frequenti
orient_sort = centers(histAll_sort_ind);

%scelgo i primi 12
orient_chosen = orient_sort(1 : param.maxOrient);
%occorrenze corrispondenti
histAll_chosen = histAll_sort(1 : param.maxOrient);


%plotta
if plotta
    lw = 5;
    ms = 5;
    fs = 20;
    %plot polar histogram of average angle occurrences
    figure,
    %polarplot(0:pi/(param.numBins-1): (pi-(pi/param.numBins)), histAll./max(histAll), 'b-o', 'LineWidth', 3, 'MarkerSize', 3);
    polarplot(deg2rad(centers), histAll*100./sum(histAll(:)), 'b-o', 'LineWidth', lw, 'MarkerSize', ms);
    hold on
    polarplot(deg2rad(orient_chosen), histAll_chosen*100./sum(histAll(:)), 'ro', 'LineWidth', lw, 'MarkerSize', ms);
    set(gcf, 'Color', 'w')
    set(gca, 'fontsize', fs)
    set(gca, 'fontweight', 'bold')
    legend({'Occurences of orientations', 'Chosen orientations'}, 'Location', 'South');
    rtickformat('percentage')
    ax = gca;
    ax.RAxisLocation = 120;
    title('Average most frequent orientations');
    %set(gca, 'linewidth', 3)
end %if plotta



