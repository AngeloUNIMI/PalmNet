<<<<<<< HEAD
function matchresult = goMatching(result_f, key_f, i, j, general)
% in base la tipo di funzione passo più o meno parametri alla funzione
drawnow;
switch (general.MATCHING_function)
    case 'library'
         % converto la cella in struct perchè il C non capisce altro
         result_a = struct('pFileName', result_f{i}(1), 'intPersona', result_f{i}(2),'intImmagine', result_f{i}(3),'pBioCode', result_f{i}{4});
         result_b = struct('pFileName', result_f{j}(1), 'intPersona', result_f{j}(2),'intImmagine', result_f{j}(3),'pBioCode', result_f{j}{4});
         %loadlibrary(matching, [matching, '.h'], 'alias', 'mydll');
         matchresult = calllib('mydll', general.MATCHING, result_a, result_b);
         %unloadlibrary('mydll');
    case 'biohashing'
         matchresult = feval(general.MATCHING, result_f{i}, key_f{i}, result_f{j}, key_f{j}, general);
    otherwise % anche per tipo 'normal'
         matchresult = feval(general.MATCHING, result_f{i}, result_f{j}, general);
=======
function matchresult = goMatching(result_f, key_f, i, j, general)
% in base la tipo di funzione passo più o meno parametri alla funzione
drawnow;
switch (general.MATCHING_function)
    case 'library'
         % converto la cella in struct perchè il C non capisce altro
         result_a = struct('pFileName', result_f{i}(1), 'intPersona', result_f{i}(2),'intImmagine', result_f{i}(3),'pBioCode', result_f{i}{4});
         result_b = struct('pFileName', result_f{j}(1), 'intPersona', result_f{j}(2),'intImmagine', result_f{j}(3),'pBioCode', result_f{j}{4});
         %loadlibrary(matching, [matching, '.h'], 'alias', 'mydll');
         matchresult = calllib('mydll', general.MATCHING, result_a, result_b);
         %unloadlibrary('mydll');
    case 'biohashing'
         matchresult = feval(general.MATCHING, result_f{i}, key_f{i}, result_f{j}, key_f{j}, general);
    otherwise % anche per tipo 'normal'
         matchresult = feval(general.MATCHING, result_f{i}, result_f{j}, general);
>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
end