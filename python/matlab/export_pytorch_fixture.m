function export_pytorch_fixture(input_image, V, PCANet, bestWaveletsAll, param, file_name)
% Export one PREPROCESSED image and exact learned filters for Python checking.
%
% Run from the original MATLAB workspace after training, with its folders on path:
%   export_pytorch_fixture(imagesCellTest{1}, V, PCANet, ...
%       bestWaveletsAll, param, 'parity_fixture.mat');
%
% Copy this function into the original MATLAB project first. This helper does
% not modify the model or its parameters. The -v7 file is readable by SciPy.

if nargin < 6
    file_name = 'parity_fixture.mat';
end
assert(PCANet.NumStages == 2, 'Only the active two-stage PCA-Gabor pipeline is supported.');
assert(ndims(input_image) == 2, 'Use one preprocessed grayscale image.');
assert(isempty(PCANet.Pyramid), 'The supplied active pipeline has no spatial pyramid.');

pca_vectors = V{1};
hist_block_size = PCANet.HistBlockSize;
block_overlap = PCANet.BlkOverLapRatio;
has_pyramid = ~isempty(PCANet.Pyramid);
gabor_kernels = cell(1, numel(bestWaveletsAll));
for i = 1:numel(bestWaveletsAll)
    gabor_kernels{i} = bestWaveletsAll(i).filter;
end

[first, ~] = PCA_output({input_image}, 1, PCANet.PatchSize(1), ...
    PCANet.NumFilters(1), V{1});
second = Gabor_output(first, bestWaveletsAll, PCANet.NumFilters(2));
pca_output = cat(3, first{:});
gabor_output = cat(3, second{:});
hash_codes = zeros(size(input_image, 1), size(input_image, 2), PCANet.NumFilters(1));
for branch = 1:PCANet.NumFilters(1)
    for j = 1:PCANet.NumFilters(2)
        index = (branch-1)*PCANet.NumFilters(2) + j;
        hash_codes(:,:,branch) = hash_codes(:,:,branch) + ...
            2^(PCANet.NumFilters(2)-j) * double(second{index} > 0);
    end
end
features = Gabor_FeaExt({input_image}, V, PCANet, bestWaveletsAll, param);
orientation_radians = ridgeorient(input_image, 0.1, 1.5, 1.5);

save(file_name, 'input_image', 'pca_vectors', 'gabor_kernels', ...
    'hist_block_size', 'block_overlap', 'has_pyramid', 'pca_output', ...
    'gabor_output', 'hash_codes', 'features', 'orientation_radians', '-v7');
fprintf('Saved parity fixture: %s\n', file_name);
end
