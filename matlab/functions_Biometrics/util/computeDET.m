<<<<<<< HEAD
function [FMR, FNMR] = computeDET(gmsVector, imsVector, REJngra, REJnira,  base)

for ii = 1:length(base)
    th = base(ii); % define threshold
    FMR(ii) = computeFMR(imsVector, REJnira, th);
    FNMR(ii) = computeFNMR(gmsVector, REJngra, th);
end

=======
function [FMR, FNMR] = computeDET(gmsVector, imsVector, REJngra, REJnira,  base)

for ii = 1:length(base)
    th = base(ii); % define threshold
    FMR(ii) = computeFMR(imsVector, REJnira, th);
    FNMR(ii) = computeFNMR(gmsVector, REJngra, th);
end

>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
