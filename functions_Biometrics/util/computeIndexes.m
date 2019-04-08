<<<<<<< HEAD
function indexes = computeIndexes(general)

% execute enroll
[result_f, indexes.enrollTime, errMessage] = goEnroll(general);

if not(strcmp(errMessage, ''))
    indexes = [];
    errordlg(errMessage);
    return;
end

switch (general.MATCHING_function)
    case 'biohashing'
        if isempty(general.BIOHASHING)
            key_f = zeros(1,lenght(result_f));
        else
            key_f = feval(general.BIOHASHING, result_f, general); 
        end
        % generazione di una chiave per il biohashing
    otherwise
        key_f = zeros(1,length(result_f));
end

LogWrite('Compute Helper Data');

% Calcolo GMS
[indexes.gms, indexes.gmsTime, indexes.gmsTime_n] = createGMS(result_f, key_f, general);
[indexes.ims, indexes.imsTime, indexes.imsTime_n] = createIMS(result_f, key_f, general);

[indexes.gmsVector, indexes.gmsVectorREJ, indexes.NGRA, indexes.REJngra] = gms2Vec(indexes.gms, general.MATCHING_type);
[indexes.imsVector, indexes.imsVectorREJ, indexes.NIRA, indexes.REJnira] = ims2Vec(indexes.ims, general.MATCHING_type);
if (indexes.NGRA < 1) | (indexes.NIRA < 1)
    errordlg('Not Enough data available to compute GMS or IMS distributions!');
    return
end

% save original gmsVector e imsVector
indexes.gmsVector_r = indexes.gmsVector;
indexes.imsVector_r = indexes.imsVector;

% calculate average time
if ((indexes.imsTime_n + indexes.gmsTime_n) > 0)
    indexes.matchTime = (indexes.imsTime + indexes.gmsTime)/(indexes.imsTime_n + indexes.gmsTime_n);
else
    indexes.matchTime = 'n/a';
end

% calculate Failure to Enroll & Failure to Match
indexes.FTE = (length(find(indexes.gmsVectorREJ == -2)) + length(find(indexes.imsVectorREJ == -2))) / (indexes.NGRA + indexes.REJngra + indexes.NIRA + indexes.REJnira);
indexes.FTM = (length(find(indexes.gmsVectorREJ == -1)) + length(find(indexes.imsVectorREJ == -1))) / (indexes.NGRA + indexes.REJngra + indexes.NIRA + indexes.REJnira);

% calculate variabile indexes
indexes = computeReal(indexes, general.MATCHING_t);
=======
function indexes = computeIndexes(general)

% execute enroll
[result_f, indexes.enrollTime, errMessage] = goEnroll(general);

if not(strcmp(errMessage, ''))
    indexes = [];
    errordlg(errMessage);
    return;
end

switch (general.MATCHING_function)
    case 'biohashing'
        if isempty(general.BIOHASHING)
            key_f = zeros(1,lenght(result_f));
        else
            key_f = feval(general.BIOHASHING, result_f, general); 
        end
        % generazione di una chiave per il biohashing
    otherwise
        key_f = zeros(1,length(result_f));
end

LogWrite('Compute Helper Data');

% Calcolo GMS
[indexes.gms, indexes.gmsTime, indexes.gmsTime_n] = createGMS(result_f, key_f, general);
[indexes.ims, indexes.imsTime, indexes.imsTime_n] = createIMS(result_f, key_f, general);

[indexes.gmsVector, indexes.gmsVectorREJ, indexes.NGRA, indexes.REJngra] = gms2Vec(indexes.gms, general.MATCHING_type);
[indexes.imsVector, indexes.imsVectorREJ, indexes.NIRA, indexes.REJnira] = ims2Vec(indexes.ims, general.MATCHING_type);
if (indexes.NGRA < 1) | (indexes.NIRA < 1)
    errordlg('Not Enough data available to compute GMS or IMS distributions!');
    return
end

% save original gmsVector e imsVector
indexes.gmsVector_r = indexes.gmsVector;
indexes.imsVector_r = indexes.imsVector;

% calculate average time
if ((indexes.imsTime_n + indexes.gmsTime_n) > 0)
    indexes.matchTime = (indexes.imsTime + indexes.gmsTime)/(indexes.imsTime_n + indexes.gmsTime_n);
else
    indexes.matchTime = 'n/a';
end

% calculate Failure to Enroll & Failure to Match
indexes.FTE = (length(find(indexes.gmsVectorREJ == -2)) + length(find(indexes.imsVectorREJ == -2))) / (indexes.NGRA + indexes.REJngra + indexes.NIRA + indexes.REJnira);
indexes.FTM = (length(find(indexes.gmsVectorREJ == -1)) + length(find(indexes.imsVectorREJ == -1))) / (indexes.NGRA + indexes.REJngra + indexes.NIRA + indexes.REJnira);

% calculate variabile indexes
indexes = computeReal(indexes, general.MATCHING_t);
>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
