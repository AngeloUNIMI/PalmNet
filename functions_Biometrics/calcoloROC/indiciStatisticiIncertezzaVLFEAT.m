function [EER, deltaFMR_EER, deltaFNMR_EER, zeroFMR, FMR1000, fpr, fnr, eer_threshold, fmr1000_threshold] = ...
    indiciStatisticiIncertezzaVLFEAT(gen_lr, imp_lr, resultTag, dbname, dirResults, plottaROCs, savefile)

%transpose if needed
if size(gen_lr, 1) < size(gen_lr, 2)
    gen_lr = gen_lr';
    imp_lr = imp_lr';
end %if size

%create the structure for vl_roc
labelsGenuini = ones(size(gen_lr));
labelsImpostors = -1 * ones(size(imp_lr));

allLabels = [labelsGenuini; labelsImpostors];
allScores = [gen_lr; imp_lr];
allScoresOrd = sort(allScores, 'descend');

%calcolo roc
[tpr, tnr, info] = vl_roc(allLabels, allScores);
fpr = 1 - tnr;
fnr = 1 - tpr;

%s = max(find(tnr > tpr));
%EER = info.eer;
[EER, s, eer_threshold] = computeEER_classic_minDiffFprFnr(fpr, fnr, allScoresOrd);
[zeroFMR, zeroFNMR] = computeZeroFMRFNMR(fpr, fnr);
[FMR1000, ~, fmr1000_threshold] = computeFMR1000(fpr, fnr, allScoresOrd);

dFMR = 1.96 .* sqrt((fpr .* (1 - fpr)) / length(imp_lr));
dFNMR = 1.96 .* sqrt((fnr .* (1 - fnr)) / length(gen_lr));

deltaTMR_EER = 1.96 * sqrt((tpr(s) * (1 - tpr(s))) / length(allScores));
deltaTNMR_EER = 1.96 * sqrt((tnr(s) * (1 - tnr(s))) / length(allScores));
deltaFMR_EER = 1.96 * sqrt((fpr(s) * (1 - fpr(s))) / length(allScores));
deltaFNMR_EER = 1.96 * sqrt((fnr(s) * (1 - fnr(s))) / length(allScores));


%plot
if plottaROCs
    
    extFig = 'png';
    %dbnameThis = strrep(nIn, '_', '\_');
    dbnameThis = '';
    
    fsfigure,
    plot(fpr, fnr, 'LineWidth', 3, 'MarkerSize', 10);
    hold on
    plot(fpr+dFMR, fnr, '--r', 'LineWidth', 3, 'MarkerSize', 10);
    plot(fpr-dFMR, fnr, '--r', 'LineWidth', 3, 'MarkerSize', 10);
    axis([0 1 0 1])
    legend('Mean ROC', 'Gaussian bounds')
    xlabel('FMR'),
    ylabel('FNMR');
    title('ROC - False Match Rate Uncertainty Bound')
    set(gcf,'color','w');
    set(gca, 'FontSize', 24);
    if savefile
        export_fig([dirResults dbname, ' - ', resultTag ,' - deltaFMR.' extFig], '-q50');
    end %if savefile
    
    %pause
    
    fsfigure
    plot(fpr, fnr, 'LineWidth', 3, 'MarkerSize', 10);
    hold on
    plot(fpr, fnr+dFNMR, '--r', 'LineWidth', 3, 'MarkerSize', 10);
    plot(fpr, fnr-dFNMR, '--r', 'LineWidth', 3, 'MarkerSize', 10);
    axis([0 1 0 1])
    legend('Mean ROC', 'Gaussian bounds')
    xlabel('FMR');
    ylabel('FNMR');
    title('ROC - False Non Match Rate Uncertainty Bound')
    set(gcf, 'color', 'w');
    set(gca, 'FontSize', 24);
    if savefile
        export_fig([dirResults dbname, ' - ', resultTag ,' - deltaFNMR.' extFig])
    end %if savefile
    
    fsfigure
    histogram(gen_lr, 1000, 'DisplayStyle', 'stairs', 'EdgeColor', 'g', 'LineWidth', 2, 'Normalization', 'probability');
    hold on
    histogram(imp_lr, 1000, 'DisplayStyle', 'stairs', 'EdgeColor', 'r', 'LineWidth', 1, 'Normalization', 'probability');
    title({[sprintf('EER: %.4f%%',EER*100) '; ' sprintf('FMR1000: %.4f%%',FMR1000*100)], ['[(\Delta_{FRR} ' sprintf('%.7f%%',deltaTNMR_EER*100) ...
        '; \Delta_{FAR} ' sprintf('%.7f%%) @ 96%% Conf. Int.] [Gen.: %d; Imp.: %d]',deltaTMR_EER*100, length(gen_lr), length(imp_lr))]})
    set(gcf, 'color', 'w');
    set(gca, 'FontSize', 24);
    xlabel('Scores');
    ylabel('Probability');
    if savefile
        export_fig([dirResults dbname, ' - ', resultTag '.' extFig])
    end %if savefile
    
    fsfigure
    loglog(fpr, fnr, 'LineWidth', 3, 'MarkerSize', 10);
    hold on
    %plot(EER, EER, 'xr')
    plot(EER, EER, 'or', 'LineWidth', 3, 'MarkerSize', 15);
    axis([0. 1 0. 1]);
    xlabel('FMR');
    ylabel('FNMR');
    axis square
    grid on
    title({'ROC - log axes', ...
        [sprintf('EER: %.4f%%',EER*100) '; ' sprintf('FMR1000: %.4f%%',FMR1000*100)], ...
        ['[(\Delta_{FRR} ' sprintf('%.7f%%',deltaTNMR_EER*100) ...
        '; \Delta_{FAR} ' sprintf('%.7f%%) @ 96%% Conf. Int.] [Gen.: %d; Imp.: %d]',deltaTMR_EER*100, length(gen_lr), length(imp_lr))]})
    set(gca, 'FontSize', 24)
    set(gcf, 'color', 'w');
    if savefile
        export_fig([dirResults dbname, ' - ', resultTag ' - logroc.' extFig])
    end %if savefile
    
end %if plottaROCs



