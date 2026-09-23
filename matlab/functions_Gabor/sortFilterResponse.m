function [sortRes, sizeRes] = sortFilterResponse(gaborBank, powerMapF)

%put powermap info in one-d vector
%get number of pixels in powermap
sizeTmp = 0;
for g = 1 : numel(gaborBank)
    s = size(powerMapF(g).value);
    sizeTmp = sizeTmp + (s(1) * s(2));
end %for g = 1 : numel(gaborBank)
tmp = zeros(sizeTmp, 6);
%init counter
ind = 1;
%loop on filters
for o = 1 : numel(powerMapF)
    
    %get size of current powermap
    currentSize = size(powerMapF(o).value);
    
    %loop on rows
    for rows = 1 : currentSize(1)
        %loop on columns
        for cols = 1 : currentSize(2)
            tmp(ind, 1) = powerMapF(o).value(rows, cols);
            tmp(ind, 2) = gaborBank(o).scale;
            tmp(ind, 3) = gaborBank(o).theta;
            tmp(ind, 4) = cols; %x
            tmp(ind, 5) = rows; %y
            tmp(ind, 6) = o; %o
            %increment counter
            ind = ind + 1;
        end %for c = 1 : imageSize(2)
    end %for r = 1 : imageSize(1)
end %for o = 1 : length(orient_chosen)

%sort powerMap in descending order
[B, indSort] = sort(tmp(:,1), 'descend');
sortRes = zeros(size(tmp));
sortRes(:,1) = B;
sortRes(:,2) = tmp(indSort, 2);
sortRes(:,3) = tmp(indSort, 3);
sortRes(:,4) = tmp(indSort, 4);
sortRes(:,5) = tmp(indSort, 5);
sortRes(:,6) = tmp(indSort, 6);
sizeRes = size(sortRes, 1);
%sortRes(:, 1) = value
%sortRes(:, 2) = scale
%sortRes(:, 3) = theta
%sortRes(:, 4) = x
%sortRes(:, 5) = y
%sortRes(:, 6) = o

