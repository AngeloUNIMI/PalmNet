<<<<<<< HEAD
function msVector = rebuildMs(msN, msX)

msVector = [];
% trasformi i vettori di frequenza in un vettore lineare
for i = 1:length(msX)
    for j = 1:msN(i)
        msVector = [msVector msX(i)];
    end
=======
function msVector = rebuildMs(msN, msX)

msVector = [];
% trasformi i vettori di frequenza in un vettore lineare
for i = 1:length(msX)
    for j = 1:msN(i)
        msVector = [msVector msX(i)];
    end
>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
end