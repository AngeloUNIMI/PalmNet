function [] = printDescFile(fidDesc, ftest)

if issparse(ftest)
    ftest = full(ftest);
end %if isssparse(ftest)

for t = 1 : numel(ftest)
    fprintf(fidDesc, '%f\n', ftest(t));  
end %for t

