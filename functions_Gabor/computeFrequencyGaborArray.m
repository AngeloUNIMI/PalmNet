function totFreq = computeFrequencyGaborArray(gaborBank, plotta)

%init
gb_ex = gaborBank(end).even;
totFreq = zeros(size(gb_ex,1), size(gb_ex,2));

%compute spectrum of each filter
%all frequencies covered by fixed gabor bank
for v = 1 : numel(gaborBank)
    
    gbResize = imresize(gaborBank(v).even, [size(gb_ex,1) size(gb_ex,2)]);
    
    FV = fft2(gbResize);
    FVdisp = fftshift(abs(FV));
    
    %figure
    %imshow(FVdisp,[]);
    
    totFreq = max(totFreq, FVdisp);
    
end %for v = 1 : size(V,3)

%plot spectrum combined
if plotta
    figure
    imshow(totFreq, []);
    title('Combined spectrums of Gabor filters')
end %if plotta

