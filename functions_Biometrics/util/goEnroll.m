<<<<<<< HEAD
function [result_f, enrolltime, errMessage] = goEnroll(general)

% reset some indexes
errMessage = '';
enrolltime = 0;
enrolltime_n = 0;
result_f = [];
bolSkip = false;

files = getFileList(general.PATH_IMAGE);

% if no files, exit
if (length(files) == 0)
    errMessage = 'No valid images found! Check configuration file!';
    return;
end

% if the connection is ok and enroll si forced delete all the old template
if ((general.db.force) & (general.db.status))
    sql = ['DELETE * FROM template WHERE template_enroll=''', general.ENROLL_function, ''' AND template_tag=''', general.db.tag, ''''];
    [rs, general.db, errMessage] = getSelect(sql, general.db); 
end

j = 1;
for i=1:length(files)
    [result{j} result_n{j}, result_e{j}] = sscanf(char(files(i)),general.FILE_FORMAT);
    if ((cell2mat(result_n(j)) == 2) && (strcmp(result_e(j),'') == 1))
        LogWrite(['Enroll #', char(files(i)), '#']);
        drawnow;
        
        % save standard information
        result_f{j}(1) = files(i);
        result_f{j}(2:3) = num2cell(sscanf(char(files(i)),general.FILE_FORMAT));
        
        % load data from database only if there are a connection, a enroll function and is not forced a new enroll
        if ((general.db.status) & not(strcmp(general.ENROLL_function, '')) & not(general.db.force))
            bolSkip = false;
            sql = ['SELECT template_value FROM template WHERE template_file=''', cell2mat(result_f{j}(1)), ''' AND template_enroll=''', general.ENROLL_function, ''' AND template_tag=''', general.db.tag, ''''];
            [rs, general.db, errMessage] = getSelect(sql, general.db);
            if not(strcmp(errMessage,''))
                return;    
            end
            % if not EOF then skip che enroll
            if (not(rs.EOF)) 
                % check mat file existance
                if (exist(char(rs.data(1,1))) == 2)
                    % load mat file in result_tmp
                    load([general.db.save, '\', char(rs.data(1,1))]);
                    result_f{j}{4} = result_tmp;
                    bolSkip = true;
                end
            end
        end
        
        % if the database load is succefful skip the enroll
        if (not(bolSkip))
            if (strcmp(general.ENROLL_function, ''))
                result_f{j}{4} = [];
            else
                % check the enroll time
                tic;
                result_f{j}{4} = createTemplate(result_f{j}, general); % TO-DO
                if (strcmp(result_f{j}{4},''))
                    tmpTime = toc;
                else
                    enrolltime = enrolltime + toc;
                    enrolltime_n = enrolltime_n + 1;
                    
                    % save the data to database
                    if (general.db.status)
                        % prepare saving filename and query
                        result_tmp = result_f{j}{4};
                        result_filename = ['file_', general.ENROLL_function, '_', general.db.tag, '_', num2str(result_f{j}{2}), '_', num2str(result_f{j}{3}), '.mat'];
                        general.db = getInsert(general.db, 'template', {'template_file', 'template_enroll', 'template_tag', 'template_value'}, {cell2mat(result_f{j}(1)), general.ENROLL_function, general.db.tag, result_filename});
                        save([general.db.save, '\', result_filename], 'result_tmp');
                    end
                end                
            end            
        end
        j = j + 1;
    end
end

% calculate average enroll time
if (enrolltime_n > 0) 
    enrolltime = enrolltime / enrolltime_n;
else
    enrolltime = 'n/a'; 
=======
function [result_f, enrolltime, errMessage] = goEnroll(general)

% reset some indexes
errMessage = '';
enrolltime = 0;
enrolltime_n = 0;
result_f = [];
bolSkip = false;

files = getFileList(general.PATH_IMAGE);

% if no files, exit
if (length(files) == 0)
    errMessage = 'No valid images found! Check configuration file!';
    return;
end

% if the connection is ok and enroll si forced delete all the old template
if ((general.db.force) & (general.db.status))
    sql = ['DELETE * FROM template WHERE template_enroll=''', general.ENROLL_function, ''' AND template_tag=''', general.db.tag, ''''];
    [rs, general.db, errMessage] = getSelect(sql, general.db); 
end

j = 1;
for i=1:length(files)
    [result{j} result_n{j}, result_e{j}] = sscanf(char(files(i)),general.FILE_FORMAT);
    if ((cell2mat(result_n(j)) == 2) && (strcmp(result_e(j),'') == 1))
        LogWrite(['Enroll #', char(files(i)), '#']);
        drawnow;
        
        % save standard information
        result_f{j}(1) = files(i);
        result_f{j}(2:3) = num2cell(sscanf(char(files(i)),general.FILE_FORMAT));
        
        % load data from database only if there are a connection, a enroll function and is not forced a new enroll
        if ((general.db.status) & not(strcmp(general.ENROLL_function, '')) & not(general.db.force))
            bolSkip = false;
            sql = ['SELECT template_value FROM template WHERE template_file=''', cell2mat(result_f{j}(1)), ''' AND template_enroll=''', general.ENROLL_function, ''' AND template_tag=''', general.db.tag, ''''];
            [rs, general.db, errMessage] = getSelect(sql, general.db);
            if not(strcmp(errMessage,''))
                return;    
            end
            % if not EOF then skip che enroll
            if (not(rs.EOF)) 
                % check mat file existance
                if (exist(char(rs.data(1,1))) == 2)
                    % load mat file in result_tmp
                    load([general.db.save, '\', char(rs.data(1,1))]);
                    result_f{j}{4} = result_tmp;
                    bolSkip = true;
                end
            end
        end
        
        % if the database load is succefful skip the enroll
        if (not(bolSkip))
            if (strcmp(general.ENROLL_function, ''))
                result_f{j}{4} = [];
            else
                % check the enroll time
                tic;
                result_f{j}{4} = createTemplate(result_f{j}, general); % TO-DO
                if (strcmp(result_f{j}{4},''))
                    tmpTime = toc;
                else
                    enrolltime = enrolltime + toc;
                    enrolltime_n = enrolltime_n + 1;
                    
                    % save the data to database
                    if (general.db.status)
                        % prepare saving filename and query
                        result_tmp = result_f{j}{4};
                        result_filename = ['file_', general.ENROLL_function, '_', general.db.tag, '_', num2str(result_f{j}{2}), '_', num2str(result_f{j}{3}), '.mat'];
                        general.db = getInsert(general.db, 'template', {'template_file', 'template_enroll', 'template_tag', 'template_value'}, {cell2mat(result_f{j}(1)), general.ENROLL_function, general.db.tag, result_filename});
                        save([general.db.save, '\', result_filename], 'result_tmp');
                    end
                end                
            end            
        end
        j = j + 1;
    end
end

% calculate average enroll time
if (enrolltime_n > 0) 
    enrolltime = enrolltime / enrolltime_n;
else
    enrolltime = 'n/a'; 
>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
end