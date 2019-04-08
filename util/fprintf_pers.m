function fprintf_pers(fidCell, string, paramString)

for c = 1 : numel(fidCell)
    fid = fidCell{c};
    if nargin == 3
        fprintf(fid, string, paramString);
    else %if nargin == 3
        fprintf(fid, string);
    end %if nargin == 3
end %for c