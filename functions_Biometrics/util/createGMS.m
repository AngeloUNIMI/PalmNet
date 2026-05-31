<<<<<<< HEAD
function [gms, gmsTime, gmsTime_n] = createGMS(result_f, key_f, general)
% Calculate GMS
gmsTime = 0;
gmsTime_n = 0;
oldID = -1;
w_r = 0;

% Only for matching_function == 'library'.
% I load the library for better performance
if strcmp(general.MATCHING_function, 'library') == 1
    loadlibrary(general.MATCHING, [general.MATCHING, '.h'], 'alias', 'mydll');
end
for w=1:length(result_f) 
    % Preserve the active users
    if oldID == cell2mat(result_f{w}(2))
    else
        w_r = w_r + 1;
        i_r = 0;
        oldID = cell2mat(result_f{w}(2));
        for i=1:length(result_f)
            % check only the image of the 'oldID' users
            if oldID == cell2mat(result_f{i}(2))
                i_r = i_r + 1;                
                % optimize matching matrix for symmetric algorithm
                switch (general.MATCHING_type)
                    case 'asymmetric'
                        j = 1;
                        j_r = 0;
                    otherwise
                        j = i;
                        j_r = i_r - 1;
                end
                for j=j:length(result_f)
                    if (oldID == cell2mat(result_f{j}(2)))
                        j_r = j_r + 1;
                        LogWrite(['GMS: match #', char(result_f{i}(1)), '# vs #', char(result_f{j}(1)), '#']);                       
                        if ((strcmp(result_f{i}{4},'')) | (strcmp(result_f{j}{4},'')))
                            gms{w_r}(i_r,j_r) = -2;
                        else
                            tic;
                            gms{w_r}(i_r,j_r) = goMatching(result_f, key_f, i, j, general);
                        end
                        % Check matching result
                        if ((gms{w_r}(i_r,j_r) == -1) | (gms{w_r}(i_r,j_r) == -2))
                            tmpTime = toc;
                        else
                            gmsTime_n = gmsTime_n + 1;
                            gmsTime = gmsTime + toc;
                        end
                    end
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
function [gms, gmsTime, gmsTime_n] = createGMS(result_f, key_f, general)
% Calculate GMS
gmsTime = 0;
gmsTime_n = 0;
oldID = -1;
w_r = 0;

% Only for matching_function == 'library'.
% I load the library for better performance
if strcmp(general.MATCHING_function, 'library') == 1
    loadlibrary(general.MATCHING, [general.MATCHING, '.h'], 'alias', 'mydll');
end
for w=1:length(result_f) 
    % Preserve the active users
    if oldID == cell2mat(result_f{w}(2))
    else
        w_r = w_r + 1;
        i_r = 0;
        oldID = cell2mat(result_f{w}(2));
        for i=1:length(result_f)
            % check only the image of the 'oldID' users
            if oldID == cell2mat(result_f{i}(2))
                i_r = i_r + 1;                
                % optimize matching matrix for symmetric algorithm
                switch (general.MATCHING_type)
                    case 'asymmetric'
                        j = 1;
                        j_r = 0;
                    otherwise
                        j = i;
                        j_r = i_r - 1;
                end
                for j=j:length(result_f)
                    if (oldID == cell2mat(result_f{j}(2)))
                        j_r = j_r + 1;
                        LogWrite(['GMS: match #', char(result_f{i}(1)), '# vs #', char(result_f{j}(1)), '#']);                       
                        if ((strcmp(result_f{i}{4},'')) | (strcmp(result_f{j}{4},'')))
                            gms{w_r}(i_r,j_r) = -2;
                        else
                            tic;
                            gms{w_r}(i_r,j_r) = goMatching(result_f, key_f, i, j, general);
                        end
                        % Check matching result
                        if ((gms{w_r}(i_r,j_r) == -1) | (gms{w_r}(i_r,j_r) == -2))
                            tmpTime = toc;
                        else
                            gmsTime_n = gmsTime_n + 1;
                            gmsTime = gmsTime + toc;
                        end
                    end
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