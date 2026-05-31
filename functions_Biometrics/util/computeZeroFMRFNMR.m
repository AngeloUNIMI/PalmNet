<<<<<<< HEAD
function [zeroFMR, zeroFNMR,  iFMR , iFNMR] = computeZeroFMRFNMR(FMR, FNMR)

[zeroFMR, iFMR] = min(FNMR(find(FMR == 0)));
[zeroFNMR, iFNMR] = min(FMR(find(FNMR == 0)));

% correction on indexes
if isempty(zeroFMR)
    zeroFMR = 1;
    iFMR = 0;
end
if isempty(zeroFNMR)
    zeroFNMR = 0;
    iFNMR = 0;
=======
function [zeroFMR, zeroFNMR,  iFMR , iFNMR] = computeZeroFMRFNMR(FMR, FNMR)

[zeroFMR, iFMR] = min(FNMR(find(FMR == 0)));
[zeroFNMR, iFNMR] = min(FMR(find(FNMR == 0)));

% correction on indexes
if isempty(zeroFMR)
    zeroFMR = 1;
    iFMR = 0;
end
if isempty(zeroFNMR)
    zeroFNMR = 0;
    iFNMR = 0;
>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
end