function [EER, deltaFMR_EER, deltaFNMR_EER, zeroFMR, FMR1000] = ...
    indiciStatisticiIncertezza_fromFprFnr_VLFEAT(fpr, fnr, numGenuini_test, numImpostori_test, resultTag, dbname, dirResults, plottaROCs, savefile)


tnr = 1 - fpr;
tpr = 1 - fnr;


%s = max(find(tnr > tpr));
%[EER, EERlow, EERhigh, iEER] = computeEERIndex_classic(fpr, fnr);
[EER, s] = computeEER_classic_minDiffFprFnr(fpr, fnr);
[zeroFMR, zeroFNMR] = computeZeroFMRFNMR(fpr, fnr);
[FMR1000, ~] = computeFMR1000(fpr, fnr);


dFMR = 1.96 .* sqrt((fpr .* (1 - fpr)) / numImpostori_test);
dFNMR = 1.96 .* sqrt((fnr .* (1 - fnr)) / numGenuini_test);
deltaTMR_EER = 1.96 * sqrt((tpr(s) * (1 - tpr(s))) / (numImpostori_test+numGenuini_test));
deltaTNMR_EER = 1.96 * sqrt((tnr(s) * (1 - tnr(s))) / (numImpostori_test+numGenuini_test));
deltaFMR_EER = 1.96 * sqrt((fpr(s) * (1 - fpr(s))) / (numImpostori_test+numGenuini_test));
deltaFNMR_EER = 1.96 * sqrt((fnr(s) * (1 - fnr(s))) / (numImpostori_test+numGenuini_test));


%plot
if plottaROCs

    extFig = 'png';
    
    fsfigure
    plot(fpr, fnr, 'LineWidth', 3, 'MarkerSize', 10);
    hold on
    plot(fpr+dFMR, fnr, '--r', 'LineWidth', 3, 'MarkerSize', 10);
    plot(fpr-dFMR, fnr, '--r', 'LineWidth', 3, 'MarkerSize', 10);
    axis([0 1 0 1])
    legend('Mean ROC', 'Gaussian bounds')
    xlabel('FMR')
    ylabel('FNMR');
    title('ROC - False Match Rate Uncertainty Bound ')
    set(gcf,'color','w');
    set(gca, 'FontSize', 24);
    if savefile
        export_fig([dirResults dbname, ' - ', resultTag ,' - deltaFMR.' extFig], '-q50');
    end %if savefile
    
    fsfigure
    plot(fpr, fnr, 'LineWidth', 3, 'MarkerSize', 10);
    hold on
    plot(fpr, fnr+dFNMR, '--r', 'LineWidth', 3, 'MarkerSize', 10);
    plot(fpr, fnr-dFNMR, '--r', 'LineWidth', 3, 'MarkerSize', 10);
    axis([0 1 0 1])
    legend('Mean ROC', 'Gaussian bounds')
    xlabel('FMR'),
    ylabel('FNMR');
    title('ROC - False Non Match Rate Uncertainty Bound ')
    set(gcf, 'color', 'w');
    set(gca, 'FontSize', 24);
    if savefile
        export_fig([dirResults dbname, ' - ', resultTag ,' - deltaFNMR.' extFig])
    end %if savefile
    
    fsfigure
    loglog(fpr, fnr, 'LineWidth', 3, 'MarkerSize', 10);
    hold on
    plot(EER, EER, 'or', 'LineWidth', 3, 'MarkerSize', 15);
    axis([0. 1 0. 1]);
    xlabel('FMR');
    ylabel('FNMR');
    axis square
    set(gca,'FontSize',13)
    grid on
    title({'ROC - log axes', ...
        [sprintf('EER: %.4f%%',EER*100) '; ' sprintf('FMR1000: %.4f%%',FMR1000*100)], ...
        ['[(\Delta_{FRR} ' sprintf('%.7f%%',deltaTNMR_EER*100) ...
        '; \Delta_{FAR} ' sprintf('%.7f%%) @ 96%% Conf. Int.] [Gen.: %d; Imp.: %d]',deltaTMR_EER*100, numGenuini_test, numImpostori_test)]});
    set(gca, 'FontSize', 24)
    set(gcf, 'color', 'w');
    if savefile
        export_fig([dirResults dbname, ' - ', resultTag ' - logroc.' extFig])
    end %if savefile
    
end %if plottaROCs



