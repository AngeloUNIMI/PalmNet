<<<<<<< HEAD
function [ims, imsTime, imsTime_n] = createIMS(result_f, key_f, general)
% Calculate IMS
imsTime_n = 0;
imsTime = 0;
oldID = -1;
oldID_id = -1;
i_r = 0;

% Only for matching_function == 'library'.
% I load the library for better performance
if strcmp(general.MATCHING_function, 'library') == 1
    loadlibrary(general.MATCHING, [general.MATCHING, '.h'], 'alias', 'mydll');
end
for i=1:length(result_f)
    if oldID == cell2mat(result_f{i}(2))
    else
        i_r = i_r + 1;
        oldID = cell2mat(result_f{i}(2));
        oldID_id = cell2mat(result_f{i}(3));
        % optimize matching matrix for symmetric algorithm
        switch (general.MATCHING_type)
            case 'asymmetric'
                j = 1;
                j_r = 0;
            otherwise
                j = i + 1;
                j_r = i_r - 1;
        end
        for j=j:length(result_f)
            if (oldID_id == cell2mat(result_f{j}(3)))
                j_r = j_r + 1;
                LogWrite(['IMS: matching #', char(result_f{i}(1)), '# vs #', char(result_f{j}(1)), '#']);                                                
                if ((strcmp(result_f{i}{4},'')) | (strcmp(result_f{j}{4},'')))
                    ims(i_r,j_r) = -2;
                else
                    tic;
                    ims(i_r,j_r) = goMatching(result_f, key_f, i, j, general);
                end
                % Check matching result
                if ((ims(i_r,j_r) == -1) | (ims(i_r,j_r) == -2))
                    tmpTime = toc;
                else
                    imsTime_n = imsTime_n + 1;
                    imsTime = imsTime + toc;
                end
            end
        end
    end
end
% Only for matching_function == 'library'.
% I unload the library for better performance
if strcmp(general.MATCHING_function, 'library') == 1
    unloadlibrary('mydll');
=======
function [ims, imsTime, imsTime_n] = createIMS(result_f, key_f, general)
% Calculate IMS
imsTime_n = 0;
imsTime = 0;
oldID = -1;
oldID_id = -1;
i_r = 0;

% Only for matching_function == 'library'.
% I load the library for better performance
if strcmp(general.MATCHING_function, 'library') == 1
    loadlibrary(general.MATCHING, [general.MATCHING, '.h'], 'alias', 'mydll');
end
for i=1:length(result_f)
    if oldID == cell2mat(result_f{i}(2))
    else
        i_r = i_r + 1;
        oldID = cell2mat(result_f{i}(2));
        oldID_id = cell2mat(result_f{i}(3));
        % optimize matching matrix for symmetric algorithm
        switch (general.MATCHING_type)
            case 'asymmetric'
                j = 1;
                j_r = 0;
            otherwise
                j = i + 1;
                j_r = i_r - 1;
        end
        for j=j:length(result_f)
            if (oldID_id == cell2mat(result_f{j}(3)))
                j_r = j_r + 1;
                LogWrite(['IMS: matching #', char(result_f{i}(1)), '# vs #', char(result_f{j}(1)), '#']);                                                
                if ((strcmp(result_f{i}{4},'')) | (strcmp(result_f{j}{4},'')))
                    ims(i_r,j_r) = -2;
                else
                    tic;
                    ims(i_r,j_r) = goMatching(result_f, key_f, i, j, general);
                end
                % Check matching result
                if ((ims(i_r,j_r) == -1) | (ims(i_r,j_r) == -2))
                    tmpTime = toc;
                else
                    imsTime_n = imsTime_n + 1;
                    imsTime = imsTime + toc;
                end
            end
        end
    end
end
% Only for matching_function == 'library'.
% I unload the library for better performance
if strcmp(general.MATCHING_function, 'library') == 1
    unloadlibrary('mydll');
>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
end