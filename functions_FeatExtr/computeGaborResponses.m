function gaborResponses = computeGaborResponses(im, gabor, NumFilters)

%init
gaborResponses = zeros(size(im,1), size(im,2), NumFilters);

for oriIndex = 1 : NumFilters
    
    filter = real(gabor(oriIndex).filter);
    
    %normalize
    %%%%%%%%%%%%%%%%%%%%%
    filter = filter ./ max(filter(:));
    %%%%%%%%%%%%%%%%%%%%%
    
    gaborResponses(:, :, oriIndex) = imfilter(im, filter, 'replicate', 'same', 'conv');
    
    %gaborResponses(:, :, oriIndex) = abs(imfilter(im, gabor(oriIndex).filter, 'replicate', 'same', 'conv'));
    %gaborResponses(:, :, oriIndex) = gaborResponses(:, :, oriIndex) - mean2(gaborResponses(:, :, oriIndex));
    
%     figure,
%     imshow(gaborResponses(:, :, oriIndex), [])
%     pause

    
end %for oriIndex = 1 : param.divTheta

