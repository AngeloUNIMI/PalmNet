<<<<<<< HEAD
function [FNMR] = computeFNMR_classic(gmsVector, REJngra, threshold)

FNMR = (length(find(sort(gmsVector) < threshold)) + REJngra) / (length(gmsVector) + REJngra);

=======
function [FNMR] = computeFNMR_classic(gmsVector, REJngra, threshold)

FNMR = (length(find(sort(gmsVector) < threshold)) + REJngra) / (length(gmsVector) + REJngra);

>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
