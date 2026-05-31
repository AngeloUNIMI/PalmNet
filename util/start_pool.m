function start_pool(poolsize_set)

% poolsize_set = 2;

%If no pool, do not create new one
poolobj = gcp('nocreate'); 

if isempty(poolobj)
    
    parpool(poolsize_set);
    
else %if isempty(poolobj)
    
    %current poolsize
    poolsize = poolobj.NumWorkers;
    
    if poolsize ~= poolsize_set
        
        delete(gcp('nocreate'));
        parpool(poolsize_set);
        
    end %if poolsize ~= 2
    
end %if isempty(poolobj)