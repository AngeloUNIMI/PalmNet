function res = myConv2(h, tmpX, step)

%preparation. X consists of original image surounded by zeros
tmpImageSize = size(tmpX);
filterSize = size(h);

numFilter = ceil(((tmpImageSize(1) - filterSize(1))/2 + 1)/step) * 2 + 1;

imageSize = step * (numFilter - 1) + filterSize(1);
tmpZeros = zeros(imageSize);

sizeX = size(tmpX);
tx = imageSize / 2 - sizeX(1)/2 + 1: imageSize / 2 + sizeX(1)/2;
tmpZeros(tx,tx) = tmpX;
X = tmpZeros;

%
startingPoints(1,:) = 1: step: imageSize - filterSize(1) + 1;
startingPoints(2,:) = 1: step: imageSize - filterSize(2) + 1;

res = NaN(size(startingPoints,2));

for ii = 1: size(startingPoints,2)
    for jj = 1: size(startingPoints,2)
        
        offset(1) = startingPoints(1,ii);
        offset(2) = startingPoints(2,jj);
        
        filterLength(1,:) = 0: filterSize(1)-1;
        filterLength(2,:) = 0: filterSize(2)-1;
        
        Xind = offset(1) + filterLength(1,:);
        Yind = offset(2) + filterLength(2,:);
        
        tmpX = X(Xind, Yind);
        dotProd = sum(sum(tmpX .* h));
        
        res(ii,jj) = dotProd;
        
    end
end

