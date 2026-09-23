function powerMapF = computePowerMaps(resF, gaborBank)

powerMapF(numel(gaborBank)).value = [];
for g = 1 : numel(gaborBank)
    powerMapF(g).value = (resF(g).even .^2) + (resF(g).odd .^ 2);
end %for g = 1 : numel(gaborBank)
