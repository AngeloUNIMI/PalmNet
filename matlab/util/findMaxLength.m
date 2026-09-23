function maxV = findMaxLength(fpr_iter, fnr_iter)

%init
maxV = -1;

for i = 1 : numel(fpr_iter)
    l = length(fpr_iter{i});
    if l > maxV
        maxV = l;
    end %if l
end %for i

for i = 1 : numel(fnr_iter)
    l = length(fnr_iter{i});
    if l > maxV
        maxV = l;
    end %if l
end %for i
    

