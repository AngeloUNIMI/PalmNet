function resF = referenceGaborFilter(gaborBank, im)

%filter image with all filters
%init
resF(numel(gaborBank)).even = [];
resF(numel(gaborBank)).odd = [];
for g = 1 : numel(gaborBank)
    
    %normal filtering
    %resF(g).even = imfilter(im, gaborBank(g).even, 'replicate', 'same', 'conv');
    %resF(g).odd = imfilter(im, gaborBank(g).odd, 'replicate', 'same', 'conv');
    
    %filtering according to paper
    step = computeStepFromScale(gaborBank(g).scale);
    resF(g).even = myConv2(gaborBank(g).even, im, step);
    resF(g).odd = myConv2(gaborBank(g).odd, im, step);
    
    %display
    %                     figure(1)
    %                     subplot(2,2,1)
    %                     imshow(resF(g).even,[])
    %                     subplot(2,2,2)
    %                     imshow(resF(g).odd,[])
    %                     subplot(2,2,3)
    %                     imshow(gaborBank(g).even,[])
    %                     subplot(2,2,4)
    %                     imshow(gaborBank(g).odd,[])
    %                     pause
    
end %for g = 1 : numel(gaborBank)