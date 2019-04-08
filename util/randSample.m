function indexes = randSample(N, fac)

indexes = false(1, N);

for i = 1 : numel(indexes)
    if mod(i, fac) == 0
        indexes(i) = true;
    end %if mod
end %for i