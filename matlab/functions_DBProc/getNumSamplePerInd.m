function numSamplePerInd = getNumSamplePerInd(filesProc)

%loop on files to compute num of samples for each ind
numSamplePerInd = zeros(numel(filesProc), 1); %larger init to be sure
for i = 1 : numel(filesProc) 
    filename = filesProc(i).name;
    ind = str2double(getIndName(filename));
    numSamplePerInd(ind) = numSamplePerInd(ind) + 1;  
end %for i

%remove excess
im = find(numSamplePerInd, 1, 'last');
numSamplePerInd(im+1 : end) = [];