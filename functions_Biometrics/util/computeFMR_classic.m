<<<<<<< HEAD
function [FMR] = computeFMR_classic(imsVector, REJnira, threshold)

FMR = length(find (sort(imsVector) >= threshold)) / (length(imsVector));

=======
function [FMR] = computeFMR_classic(imsVector, REJnira, threshold)

FMR = length(find (sort(imsVector) >= threshold)) / (length(imsVector));

>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
