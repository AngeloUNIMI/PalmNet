function step = computeStepFromScale(scale)

if scale == 0
    step = 2^scale;
else %if gaborBank(g).scale == 0
    step = 2^scale * 3/2;
end %if gaborBank(g).scale == 0