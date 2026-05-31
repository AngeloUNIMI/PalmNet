function ind = getIndName(filename)

[C, ~] = strsplit(filename, '_');
ind = [C{1:end-1}];