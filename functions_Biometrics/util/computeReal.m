<<<<<<< HEAD
function indexes = computeReal(indexes, MATCHING_t)

LogWrite('Compute indexes ...');
% calcolo DET
[indexes.FMR, indexes.FNMR] = computeDET(indexes.gmsVector, indexes.imsVector, indexes.REJngra, indexes.REJnira, MATCHING_t);
% calcolo EER
[indexes.EER, indexes.EERlow, indexes.EERhigh] = computeEER(indexes.FMR, indexes.FNMR);
% calcolo ZeroFMR e ZeroFNMR
=======
function indexes = computeReal(indexes, MATCHING_t)

LogWrite('Compute indexes ...');
% calcolo DET
[indexes.FMR, indexes.FNMR] = computeDET(indexes.gmsVector, indexes.imsVector, indexes.REJngra, indexes.REJnira, MATCHING_t);
% calcolo EER
[indexes.EER, indexes.EERlow, indexes.EERhigh] = computeEER(indexes.FMR, indexes.FNMR);
% calcolo ZeroFMR e ZeroFNMR
>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
[indexes.zeroFMR, indexes.zeroFNMR] = computeZeroFMRFNMR(indexes.FMR, indexes.FNMR);