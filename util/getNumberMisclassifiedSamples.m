function err = getNumberMisclassifiedSamples(C)

%init
err = 0;

%loop on confusion matrix
for f1 = 1 : size(C, 1)
    for f2 = 1 : size(C, 2)
        if f1 ~= f2
            err = err + C(f1, f2);
        end %if f1 ~= f2
    end %for f1
end %for f2