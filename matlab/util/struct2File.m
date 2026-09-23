function struct2File( s, fileName, varargin )
%Write struct to text file. The data in the struct can be both numbers and
%strings. The first line in the file will be a row with the headers/names
%of the columns.
%Ex: struct2File( s, 'c:/test.txt' );
%Ex: struct2File( s, 'c:/test.txt', 'precision', 3 ); %specify precision
%Ex: struct2File( s, 'c:/test.txt', 'promptOverWrite', false );


[varargin,align]=getarg(varargin,'align',false);
align=align{:};
[varargin,delimiter]=getarg(varargin,'delimiter','\t');
delimiter=delimiter{:};
[varargin,units]=getarg(varargin,'units','');
units=units{:};
[varargin,promptOverWrite]=getarg(varargin,'promptOverWrite',false);
promptOverWrite=promptOverWrite{:};
[varargin,precision]=getarg(varargin,'precision',6);
precision=precision{:};
[varargin,Sort]=getarg(varargin,'sort',true);
Sort=Sort{:};

if ~isempty(varargin)
    error('Unknown optional arguments specified');
end

fields = fieldnames(s)';

if ~isempty(units)
    if numel(units)~=numel(fields)
        error('The number of units specified doesn not match the number of fields in the struct');
    end
end

if exist(fileName,'file')==2 && promptOverWrite
    res = questdlg('File exists, overwrite?','', ...
        'Yes', 'No', 'Yes');
    if strcmpi(res,'No')
        disp('Aborted');
        return;
    end
end

data=cell(numel(s),numel(fields));
for k=1:numel(fields)
    fn=fields{k};
    data(:,k) = {s.(fn)};
end
if size(units,2)==1
    units = units';
end
if ~isempty(units)
    data=[units;data];
end
data=[fields;data];

if Sort
    [fields,ind] = sort(fields);
    data = data(:,ind);
end

%ex1 = {'a' 1 12 123; 'ab' 4 5 6; 'abc' 7 8 9};
ex_func3 = @(input)ex_func(input,precision);
ex2 = cellfun(ex_func3,data,'UniformOutput',0);
if align
    size_ex2 = cellfun(@length,ex2,'UniformOutput',0);
    str_length = max(max(cell2mat(size_ex2)))+1;
    ex2 = cellfun(@(x) ex_func2(x,str_length),ex2,'uniformoutput',0);
    ex2 = cell2mat(ex2);
end

fid = fopen(fileName,'wt');
if fid==-1
    error('Could not open %s');
end

if iscell(ex2)
    [m,n]=size(ex2);
    for i=1:m
        for j=1:n
            fprintf(fid,'%s',ex2{i,j});
            if j<n
                fprintf(fid,delimiter);
            end
        end
        if i<m
            fprintf(fid,'\n');
        end
    end
else
    m=size(ex2,1);
    for i=1:m
        fprintf(fid,'%s',strtrim(ex2(i,:)));
        if i<m
            fprintf(fid,'\n');
        end
    end
end
fclose(fid);




function [ out ] = ex_func( in, prec )

if iscell(in)
    in = in{:};
end

in_datatype = class(in);

switch in_datatype
    case 'char'
        out = in;
    case 'double'
        out = num2str(in, prec);
    otherwise
        error('Unknown type');
end

function [ out ] = ex_func2( in, str_length )

a = length(in);
out = [char(32*ones(1,str_length-a)), in];