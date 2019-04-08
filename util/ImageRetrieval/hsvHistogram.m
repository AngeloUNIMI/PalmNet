function hsvColorHistogram = hsvHistogram(image)
% input: image to be quantized in hsv color space into 8x2x2 equal bins
% output: 1x32 vector indicating the features extracted from hsv color
% space

[rows, cols, numOfBands] = size(image);
% totalPixelsOfImage = rows*cols*numOfBands;
image = rgb2hsv(image);

% split image into h, s & v planes
h = image(:, :, 1);
s = image(:, :, 2);
v = image(:, :, 3);

% quantize each h,s,v equivalently to 8x2x2
% Specify the number of quantization levels.
% thresholdForH = multithresh(h, 7);  % 7 thresholds result in 8 image levels
% thresholdForS = multithresh(s, 1);  % Computing one threshold will quantize ...
%                                     % the image into three discrete levels
% thresholdForV = multithresh(v, 1);  % 7 thresholds result in 8 image levels
%
% seg_h = imquantize(h, thresholdForH); % apply the thresholds to obtain segmented image
% seg_s = imquantize(s, thresholdForS); % apply the thresholds to obtain segmented image
% seg_v = imquantize(v, thresholdForV); % apply the thresholds to obtain segmented image

% quantize each h,s,v to 8x2x2
% Specify the number of quantization levels.
numberOfLevelsForH = 8;
numberOfLevelsForS = 2;
numberOfLevelsForV = 2;

% Find the max.
maxValueForH = max(h(:));
maxValueForS = max(s(:));
maxValueForV = max(v(:));

% create final histogram matrix of size 8x2x2
hsvColorHistogram = zeros(8, 2, 2);

% create col vector of indexes for later reference
index = zeros(rows*cols, 3);

% Put all pixels into one of the "numberOfLevels" levels.
count = 1;
for row = 1:size(h, 1)
    for col = 1 : size(h, 2)
        quantizedValueForH(row, col) = ceil(numberOfLevelsForH * h(row, col)/maxValueForH);
        quantizedValueForS(row, col) = ceil(numberOfLevelsForS * s(row, col)/maxValueForS);
        quantizedValueForV(row, col) = ceil(numberOfLevelsForV * v(row, col)/maxValueForV);
        
        % keep indexes where 1 should be put in matrix hsvHist
        index(count, 1) = quantizedValueForH(row, col);
        index(count, 2) = quantizedValueForS(row, col);
        index(count, 3) = quantizedValueForV(row, col);
        count = count+1;
    end
end

% put each value of h,s,v to matrix 8x2x2
% (e.g. if h=7,s=2,v=1 then put 1 to matrix 8x2x2 in position 7,2,1)
for row = 1:size(index, 1)
    if (index(row, 1) == 0 || index(row, 2) == 0 || index(row, 3) == 0)
        continue;
    end
    hsvColorHistogram(index(row, 1), index(row, 2), index(row, 3)) = ... 
        hsvColorHistogram(index(row, 1), index(row, 2), index(row, 3)) + 1;
end

% normalize hsvHist to unit sum
hsvColorHistogram = hsvColorHistogram(:)';
hsvColorHistogram = hsvColorHistogram/sum(hsvColorHistogram);

% clear workspace
clear('row', 'col', 'count', 'numberOfLevelsForH', 'numberOfLevelsForS', ...
    'numberOfLevelsForV', 'maxValueForH', 'maxValueForS', 'maxValueForV', ...
    'index', 'rows', 'cols', 'h', 's', 'v', 'image', 'quantizedValueForH', ...
    'quantizedValueForS', 'quantizedValueForV');

% figure('Name', 'Quantized leves for H, S & V');
% subplot(2, 3, 1);
% imshow(seg_h, []);
% subplot(2, 3, 2);
% imshow(seg_s, []);
% title('Quatized H,S & V by matlab function imquantize');
% subplot(2, 3, 3);
% imshow(seg_v, []);
% subplot(2, 3, 4);
% imshow(quantizedValueForH, []);
% subplot(2, 3, 5);
% imshow(quantizedValueForS, []);
% title('Quatized H,S & V by my function');
% subplot(2, 3, 6);
% imshow(quantizedValueForV, []);

end