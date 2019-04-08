function varargout = getarg( args, id, varargin )

if isstruct(id) || isobject(id)
        for f = fieldnames(id)'
                [args,val] = getarg(args,f{1});
                if ~isempty(val)
                        id.(f{1}) = val{1};
                end
        end
        if nargout == 1
                varargout{1} = id;
        else
                varargout{1} = args;
                varargout{2} = id;
        end
        return
end

val = {};
for i=1:numel(args)
        if ~ischar( args{i} ), continue, end
        if ~strcmpi( args{i}, id ), continue, end
        
        val = args(i+1);
        ind = true( size(args) );
        ind(i:i+1) = false;
        args = args(ind);
        break;
end

%ies 17-11-09. default value for argument, if not found
if isempty(val) && ~isempty(varargin)
    val = varargin(1);
end

if nargout == 1
        varargout{1} = val;
else
        varargout{1} = args;
        varargout{2} = val;
end