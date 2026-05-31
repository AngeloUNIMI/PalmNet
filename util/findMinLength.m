function minV = findMinLength(fpr_iter, fnr_iter)

%init
minV = 1e9;

for i = 1 : numel(fpr_iter)
    l = length(fpr_iter{i});
    if l < minV
        minV = l;
    end %if l
end %for i

for i = 1 : numel(fnr_iter)
    l = length(fnr_iter{i});
    if l < minV
        minV = l;
    end %if l
end %for i
    

