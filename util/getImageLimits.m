function clim = getImageLimits(im)

if max(abs(im(:))) == 0
    clim = [-1 1];
else
    clim = max(abs(im(:))) * [-1 1];
end