function [EER, FMR1000, fpr_mean, fnr_mean] = computeAverageEER_FMR1000(fpr_iter, fnr_iter, genuinesAggr_iter, impostorsAggr_iter, dbname, dirResults, plotta, savefile, param)

% %init
% minLength = findMinLength(fpr_iter, fnr_iter);
% fpr_mean = zeros(minLength, 1)';
% fnr_mean = zeros(minLength, 1)';
% 
% %compute average fpr fnr
% for l = 1 : param.numIterations
%     fpr_mean = fpr_mean + fpr_iter{l}(1 : minLength);
%     fnr_mean = fnr_mean + fnr_iter{l}(1 : minLength);
% end %for l

%interpolation to common size
maxLength = findMaxLength(fpr_iter, fnr_iter) * 2;
for l = 1 : param.numIterations
    step = length(fpr_iter{1}) / maxLength;
    fpr_iter{l} = interp1(1:length(fpr_iter{1}), fpr_iter{1}, 1:step:length(fpr_iter{1}));
    step = length(fnr_iter{1}) / maxLength;
    fnr_iter{l} = interp1(1:length(fnr_iter{1}), fnr_iter{1}, 1:step:length(fnr_iter{1}));
end %for l

%clip
minLength = findMinLength(fpr_iter, fnr_iter);
fpr_mean = zeros(minLength, 1)';
fnr_mean = zeros(minLength, 1)';

%compute average fpr fnr
for l = 1 : param.numIterations
    fpr_mean = fpr_mean + fpr_iter{l}(1 : minLength);
    fnr_mean = fnr_mean + fnr_iter{l}(1 : minLength);
end %for l

fpr_mean = fpr_mean ./ param.numIterations;
fnr_mean = fnr_mean ./ param.numIterations;

numGenuines_test = length(genuinesAggr_iter{1});
numImpostors_test = length(impostorsAggr_iter{1});

%error metrics
[EER, deltaFMR_EER, deltaFNMR_EER, zeroFMR, FMR1000] = indiciStatisticiIncertezza_fromFprFnr_VLFEAT(fpr_mean, fnr_mean, numGenuines_test, numImpostors_test, ...
<<<<<<< HEAD
    [num2str(param.numScoreAggregate) ' scores aggregated'], dbname, dirResults, plotta, savefile);
=======
    [num2str(param.numScoreAggregate) ' scores aggregated'], dbname, dirResults, plotta, savefile);
    
>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
