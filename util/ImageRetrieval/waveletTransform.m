function waveletMoments = waveletTransform(image, spaceColor)
% input: image to process and extract wavelet coefficients from
% output: 1x20 feature vector containing the first 2 moments of wavelet
% coefficients

if (strcmp(spaceColor, 'truecolor') == 1)
    imgGray = double(rgb2gray(image))/255;
    imgGray = imresize(imgGray, [256 256]);
elseif (strcmp(spaceColor, 'grayscale') == 1)
    imgGray = imresize(image, [256 256]);
end

coeff_1 = dwt2(imgGray', 'coif1');
coeff_2 = dwt2(coeff_1, 'coif1');
coeff_3 = dwt2(coeff_2, 'coif1');
coeff_4 = dwt2(coeff_3, 'coif1');

% construct the feaute vector
meanCoeff = mean(coeff_4);
stdCoeff = std(coeff_4);

waveletMoments = [meanCoeff stdCoeff];

end