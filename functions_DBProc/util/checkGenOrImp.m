function gen_or_imp = checkGenOrImp(fileName_1, fileName_2)

%IITD
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ind1 = getIndName_IITD(fileName_1);
ind2 = getIndName_IITD(fileName_2);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if strcmp(ind1, ind2) == 1
    gen_or_imp = 'gen';
else % if strcmp
    gen_or_imp = 'imp';
end %if strcmp

