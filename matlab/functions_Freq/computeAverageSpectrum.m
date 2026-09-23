function Fimgdisp_all = computeAverageSpectrum(imagesCellTrain, plotta)

%freq
Fimgdisp_all = zeros(size(imagesCellTrain{1}));
for l = 1 : numel(imagesCellTrain)
    img = imagesCellTrain{l};
    
    %                 figure
    %                 imshow(img,[]);
    %                 title('Palm')
    
    Fimg = fft2(img-mean(img(:)));
    Fimgdisp = fftshift(abs(Fimg));
    
    Fimgdisp_all = Fimgdisp_all + Fimgdisp;
    
end %for l = 1 : numel(imagesCellTrain)

Fimgdisp_all = Fimgdisp_all ./ numel(imagesCellTrain);

if plotta
    figure,
    imshow(Fimgdisp_all, [0 100]);
    title('Average spectrum of training palm images')
end %if plotta