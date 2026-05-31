function Indexes = personFold(numSamples, labels, folds)


%number of people
% numPeople = numel(unique(labels));

%number of people per each fold
% IndPerFold = ceil(numPeople / folds);

%assign fold number for each person
%compute fold per person for each possible person
%(there might be missing individuals)
allPeople = 1 : max(labels);
foldPerPerson = randi(folds, length(allPeople), 1);

%init
Indexes = zeros(numSamples, 1);

% currFold = 1;
% for n = 1 : numSamples
%         
%     if labels(n) <= IndPerFold * currFold
%         Indexes(n) = currFold;
%     end %if label
%     
%     if labels(n) > IndPerFold * currFold
%         currFold = currFold + 1;
%         Indexes(n) = currFold;
%     end %if labels
%     
% end %for k

for n = 1 : numSamples
        
    fold = foldPerPerson(labels(n));
    Indexes(n) = fold;
    
end %for k

