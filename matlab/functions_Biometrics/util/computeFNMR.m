<<<<<<< HEAD
function [FNMR] = computeFNMR(gmsVector, REJngra, threshold)

%FNMR = (length(find(sort(gmsVector) < threshold)) + REJngra) / (length(gmsVector) + REJngra);


%distribuzione con valori grandi tipici degli  impostori (es. iride)
=======
function [FNMR] = computeFNMR(gmsVector, REJngra, threshold)

%FNMR = (length(find(sort(gmsVector) < threshold)) + REJngra) / (length(gmsVector) + REJngra);


%distribuzione con valori grandi tipici degli  impostori (es. iride)
>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
FNMR = (length(find(sort(gmsVector) > threshold)) + REJngra) / (length(gmsVector) + REJngra);