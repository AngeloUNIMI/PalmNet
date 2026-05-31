<<<<<<< HEAD
function [EER, EERlow, EERhigh] = computeEER_classic(FAR,FRR)

% calcolo le posizioni di confine
t1 = min(find(FRR<=FAR));
t2 = max(find(FRR>=FAR));

% Controllo la combinazioni che da errore complessivo inferiore
if (FRR(t1) + FAR(t1)) <= (FRR(t2) + FAR(t2))
    EERlow = FRR(t1);
    EERhigh = FAR(t1);
else
    EERlow = FAR(t2);
    EERhigh = FRR(t2);
end

% Inserisco i valori delle variabili
EER = mean([EERlow, EERhigh]);
if isnan(EER)
    EER = 'n/a';
end
if isempty(EERlow)
    EERlow = 'n/a';
end
if isempty(EERhigh)
    EERhigh = 'n/a';
end





=======
function [EER, EERlow, EERhigh] = computeEER_classic(FAR,FRR)

% calcolo le posizioni di confine
t1 = min(find(FRR<=FAR));
t2 = max(find(FRR>=FAR));

% Controllo la combinazioni che da errore complessivo inferiore
if (FRR(t1) + FAR(t1)) <= (FRR(t2) + FAR(t2))
    EERlow = FRR(t1);
    EERhigh = FAR(t1);
else
    EERlow = FAR(t2);
    EERhigh = FRR(t2);
end

% Inserisco i valori delle variabili
EER = mean([EERlow, EERhigh]);
if isnan(EER)
    EER = 'n/a';
end
if isempty(EERlow)
    EERlow = 'n/a';
end
if isempty(EERhigh)
    EERhigh = 'n/a';
end





>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
