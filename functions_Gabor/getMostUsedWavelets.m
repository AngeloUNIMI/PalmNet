function o_counter = getMostUsedWavelets(sortRes, gaborBank, powerMapF, param, sizeRes, plotta)

%init matrix indicating if for each position a wavelet
%with orient and scale already used
tmpRes = initTmpRes(gaborBank, powerMapF);

%init counter for how many times each wavelet is chosen
o_counter = zeros(numel(gaborBank), 1);

%init counters
countW = 1; %wavelet counter
ind = 1; %sorted response counter
%loop on wavelet responses
while (countW <= param.numWavelets && ind <= sizeRes)
    
    %get information of corresponding wavelet
    currX = sortRes(ind, 4);
    currY = sortRes(ind, 5);
    currO = sortRes(ind, 6);
    
    %check if current wavelet at current position already
    %used
    if (tmpRes(currO).value(currY, currX) == 1)
        %increment counter
        ind = ind + 1;
        continue
    end %if (tmpRes(currY, currX, currO)
    
    %increment by 1 the corresponding wavelet index counter
    o_counter(currO) = o_counter(currO) + 1;
    tmpRes(currO).value(currY, currX) = 1;
    
    %increment counter
    countW = countW + 1;
    ind = ind + 1;
    
end %while (countW <= param.numWavelets && ind <= sizeRes)

%normalize most used filters counter
o_counterNorm = o_counter ./ sum(o_counter(:));

%display most used filters
if 0
    figure,
    bar(1:size(o_counterNorm), o_counterNorm)
    xlabel('Wavelet n.')
    ylabel('Perc. of occurence')
    title('Most used wavelets');
end %if plotta




