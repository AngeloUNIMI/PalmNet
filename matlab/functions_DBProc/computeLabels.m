function [labels, numImagesAll] = computeLabels(files)

numImagesAll = numel(files);
labels = zeros(numImagesAll, 1);
for i = 1 : numImagesAll
    filename = files(i).name;
    labels(i) = str2double(getIndName(filename));
end %for i