function gaborBank = gaborArrayFromScales(imageSize, thetaVector, param, plotta)

%scaling factor
a0 = 2^(1/param.N);

%the number of scale (in 6 octaves)
m = ceil(log2(imageSize(1)/2)) * param.N;  

%%%%%%%%
% m = 2;
%%%%%%%%

%kai
kai  = sqrt(2*log(2)) * (2^param.phai+1) / (2^param.phai-1);

%init
%gabor filter counter
count = 1;
gaborBank((m+1)*length(thetaVector)).even = [];
gaborBank((m+1)*length(thetaVector)).odd = [];
gaborBank((m+1)*length(thetaVector)).scale = [];
gaborBank((m+1)*length(thetaVector)).theta = [];

%loop on scales
for ii = 0 : m
    
    %compute filtersize from scale
    filterSize = computeFilterSizeFromScale(ii);
    
    %coefficient dependent on scale
    ctr = ( 4 + 2^(-ii) ) / 2;
    
    %create meshgrid to compute filter
    tx = 1 : filterSize;
    ty = 1 : filterSize;
    [x, y] = meshgrid(tx, ty); 
    %x = x'; y = y';
    
    %multiply meshgrid with coefficients
    xx = a0^(-ii) * x - ctr * param.b0;
    yy = a0^(-ii) * y - ctr * param.b0;
    
    %loop on orientations
    for ll = 1 : length(thetaVector)
          
        %angle
        theta = thetaVector(ll);
        
        %rotate meshgrid with angle theta
        rotX =  xx * cos( theta ) + yy * sin( theta );
        rotY = -xx * sin( theta ) + yy * cos( theta );
        
        %compute filters
        %even
        gb_even = real(a0^(-ii) * (1/sqrt(2) * exp(-1/(2*param.aspectRatio^2) * (param.aspectRatio^2*rotX.^2 + rotY.^2)) .* (exp(1i*kai*rotX) - exp(-kai^2/2))));
        %odd
        gb_odd = imag(a0^(-ii) * (1/sqrt(2) * exp(-1/(2*param.aspectRatio^2) * (param.aspectRatio^2*rotX.^2 + rotY.^2)) .* (exp(1i*kai*rotX))));
        
        %save filter and related info
        gaborBank(count).even = gb_even;
        gaborBank(count).odd = gb_odd;
        gaborBank(count).scale = ii;
        gaborBank(count).theta = theta;
        
        %increment counter
        count = count + 1;
        
    end %for ll = 1 : length(thetaVector)
    
end %for ii = 0 : m


%display filters
if plotta
    
    fsfigure,
    %montage(real(gaborBank), 'DisplayRange', [], 'ThumbnailSize', [halfLength*2+1 halfLength*2+1])
    
    gaborBankPlot = gaborBank;
    maxFs = 4 * 2^m;
    for o = 1 : (m+1)*length(thetaVector)
        gaborBankPlot(o).even = imresize(gaborBankPlot(o).even, [maxFs maxFs]);
        gaborBankPlot(o).odd = imresize(gaborBankPlot(o).odd, [maxFs maxFs]);
    end %for o
    
    subplot(1,2,1)
    gaborMontageEven = reshape([gaborBankPlot.even], [maxFs, maxFs, (m+1)*length(thetaVector)]);
    montage(gaborMontageEven, 'DisplayRange', [])
    title('Computed Gabor filter bank (even)');
    
    subplot(1,2,2)
    gaborMontageOdd = reshape([gaborBankPlot.odd], [maxFs, maxFs, (m+1)*length(thetaVector)]);
    montage(gaborMontageOdd, 'DisplayRange', [])
    title('Computed Gabor filter bank (odd)');
    
    %pause
    
end %if plotta




