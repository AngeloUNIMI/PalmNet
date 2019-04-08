function confMat = confMatGet(desiredOutput, computedOutput)
%confMatGet: Get confusion matrix from recognition results
%
%	Usage:
%		confMat = confMatGet(desiredOutput, computedOutput)
%
%	Description:
%		confMatGet(desiredOutput, computedOutput) returns the confusion matrix of a given classifier based on
%		its desired output (ground truth) and computed output.
%
%	Example:
%		desired=[1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 4 5 5 5 5 5 5 5 5 5 5 5 5];
%		computed=[1 5 5 1 1 1 1 1 5 5 1 2 2 2 2 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 2 5 5 5 5 5 5 5 5 3 5 5 5];
%		confMat = confMatGet(desired, computed);
%		confMatPlot(confMat);
%
%	See also confMatPlot.

%	Category: Classification analysis
%	Roger Jang, 20060523, 20070504

if nargin<1, selfdemo; return; end

classCount=length(unique(desiredOutput));

confMat=zeros(classCount, classCount);
for i=1:classCount
	index=find(desiredOutput==i);
	roi=computedOutput(index);
	for j=1:classCount
		confMat(i,j)=length(find(roi==j));
	end
end

% ====== Self demo
function selfdemo
mObj=mFileParse(which(mfilename));
strEval(mObj.example);
