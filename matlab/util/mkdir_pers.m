function mkdir_pers(directory, savefile)

if savefile
    if exist(directory, 'dir') ~= 7
        mkdir(directory);
    end %if exist
end %if savefile