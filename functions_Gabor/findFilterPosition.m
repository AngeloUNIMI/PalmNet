function [posX, posY, posX_filter, posY_filter] = findFilterPosition(x,y,step,imageSize,filterSize)
    
    numFilter = ceil(((imageSize(1) - filterSize(1))/2 + 1)/step) * 2 + 1;
    tmpImageSize = step * (numFilter - 1) + filterSize(1);
    
    offset = - (tmpImageSize - imageSize) / 2;
    filterLength = 1: filterSize(1);
    
    posX = offset + step * (x-1) + filterLength;
    if 1 <= min(posX) && max(posX) <= imageSize
        posX_filter = filterLength;
    elseif min(posX) < 1
        posX(posX < 1) = [];
        posX_filter = filterSize(1) - length(posX) + 1: filterSize(1);
    elseif max(posX) > imageSize
        posX(posX > imageSize) = [];
        posX_filter = 1:length(posX);
    end
    
    posY = offset + step * (y-1) + filterLength;

    if 1 <= min(posY) && max(posY) <= imageSize
        posY_filter = filterLength;
    elseif min(posY) < 1
        posY(posY < 1) = [];
        posY_filter = filterSize(1) - length(posY) + 1: filterSize(1);
    elseif max(posY) > imageSize
        posY(posY > imageSize) = [];
        posY_filter = 1:length(posY);

    end
    
    if length(posX) > imageSize
        posX = 1: imageSize;
        posY = 1: imageSize;
        posX_filter = 1: imageSize;
        posY_filter = 1: imageSize;
    end
    
    