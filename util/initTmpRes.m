function tmpRes = initTmpRes(gaborBank, powerMapF)

tmpRes(numel(gaborBank)).value = 0;
for g = 1 : numel(gaborBank)
    %get size of current powermap
    currentSize = size(powerMapF(g).value);
    tmpRes(g).value = zeros(currentSize);
end %for g = 1 : numel(gaborBank)