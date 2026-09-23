<<<<<<< HEAD
function plotFMRFNMR(FMR, FNMR, base, curAxes, numBins, optPlotFMR, optPlotFNMR)

narginchk(3,7);
% set the graphics handler
if nargin == 3 
    curAxes = figure;
end
% number of bins for distributions plot
if nargin <= 4
    numBins = 100;
end
% color and type of line
if nargin <= 5
    optPlotFMR = 'r-';
end
if nargin <= 6
    optPlotFNMR = 'g-';
end
axes(curAxes);


hold on, grid on, axis square;

set(gca, 'XScale', 'linear');
set(gca, 'YScale', 'linear');
plot(base, FMR, optPlotFMR)
plot(base, FNMR, optPlotFNMR)
axis([0, max(base), 0, 1.01])
xlabel('Threshold');
ylabel('FMR and FNMR');
=======
function plotFMRFNMR(FMR, FNMR, base, curAxes, numBins, optPlotFMR, optPlotFNMR)

narginchk(3,7);
% set the graphics handler
if nargin == 3 
    curAxes = figure;
end
% number of bins for distributions plot
if nargin <= 4
    numBins = 100;
end
% color and type of line
if nargin <= 5
    optPlotFMR = 'r-';
end
if nargin <= 6
    optPlotFNMR = 'g-';
end
axes(curAxes);


hold on, grid on, axis square;

set(gca, 'XScale', 'linear');
set(gca, 'YScale', 'linear');
plot(base, FMR, optPlotFMR)
plot(base, FNMR, optPlotFNMR)
axis([0, max(base), 0, 1.01])
xlabel('Threshold');
ylabel('FMR and FNMR');
>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
