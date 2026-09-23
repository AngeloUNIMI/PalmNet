function files = checkMinNumSamplePerInd(files)


%init
indexrem = [];
numSamplePerInd = zeros(numel(files), 1); %larger init to be sure

%loop on files to compute num of samples for each ind
for i = 1 : numel(files)
    
    filename = files(i).name;
    ind = str2double(getIndName(filename)); %IITD
    
    numSamplePerInd(ind) = numSamplePerInd(ind) + 1;
        
%     sampNum = getSampleNumber(filename);
%     if sampNum > numSamplePerInd(ind)
%         %numSamplePerInd(ind) = sampNum;
%     end %if sampNum
    
end %for i

%remove excess
im = find(numSamplePerInd, 1, 'last');
numSamplePerInd(im+1 : end) = [];

%loop again to remove samples without minimum number
for i = 1 : numel(files)
    
    filename = files(i).name;
    ind = str2double(getIndName(filename)); %IITD
    
    if numSamplePerInd(ind) == 1
        indexrem = [indexrem i];
    end %if numSamplePerInd(ind) == 1
    
end %for i

%remove
files(indexrem) = [];

