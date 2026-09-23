"""Independent NumPy/SciPy references, not a substitute for MATLAB fixtures."""
import math
import numpy as np
import pytest
import torch
from scipy import sparse
from scipy.signal import correlate2d, convolve2d
from palmnet import PalmConfig, PalmPCAGabor
from palmnet.gabor import fixed_gabor_bank, multiscale_bank, select_wavelets
from palmnet.hashing import hashing_histogram
from palmnet.ops import correlate_valid, imfilter_conv_replicate, myconv2, ridge_orientation
from palmnet.preprocessing import preprocess_batch, read_uint8, resize_bicubic
from palmnet.evaluation import (evaluate, pairwise_distances, verification, aggregate_verification,
                                matlab_movmax, matlab_vl_roc, matlab_verification,
                                matlab_nearest_neighbor)
from palmnet.data import Record, discover, make_matlab_person_fold, make_split, matlab_identity_from_filename


torch.set_num_threads(2)


@pytest.fixture
def small_config():
    return PalmConfig(image_size=16, pca_patch_size=3, pca_filters=2,
                      default_orientations=3, adaptive_orientations=2,
                      selected_wavelets=1, fixed_half_size=3, hist_block_size=(4, 4),
                      orientation_histogram="fixed", num_wavelet_responses=25)


@pytest.fixture
def images():
    generator = np.random.default_rng(123)
    return [generator.integers(0, 256, (16, 16), dtype=np.uint8) for _ in range(4)]


@pytest.fixture
def fitted(small_config, images):
    return PalmPCAGabor(small_config, "cpu").fit(images)


@pytest.mark.parametrize("kernel_size", [3, 4, 15, 16])
@pytest.mark.parametrize("stride", [1, 3])
def test_fft_matches_direct_valid_correlation(kernel_size, stride):
    torch.manual_seed(7)
    x = torch.randn(2, 1, 29, 31, dtype=torch.float64)
    w = torch.randn(3, 1, kernel_size, kernel_size, dtype=torch.float64)
    direct = correlate_valid(x, w, stride, "direct")
    fft = correlate_valid(x, w, stride, "fft")
    torch.testing.assert_close(fft, direct, rtol=1e-11, atol=1e-11)
    expected = correlate2d(x[0, 0].numpy(), w[0, 0].numpy(), mode="valid")[::stride, ::stride]
    np.testing.assert_allclose(direct[0, 0], expected, rtol=1e-12, atol=1e-12)


@pytest.mark.parametrize("kernel_size", [3, 4, 8, 35])
def test_gabor_convolution_replicate_origin(kernel_size):
    rng = np.random.default_rng(0)
    image = rng.normal(size=(7, 9))
    kernel = rng.normal(size=(kernel_size, kernel_size))
    # Literal convolution using original kernel center floor((k+1)/2), one-based.
    origin = (kernel_size - 1) // 2
    reference = np.zeros_like(image)
    for r in range(image.shape[0]):
        for c in range(image.shape[1]):
            for u in range(kernel_size):
                for v in range(kernel_size):
                    rr = np.clip(r + origin - u, 0, image.shape[0] - 1)
                    cc = np.clip(c + origin - v, 0, image.shape[1] - 1)
                    reference[r, c] += kernel[u, v] * image[rr, cc]
    x = torch.from_numpy(image)[None, None]
    k = torch.from_numpy(kernel)[None, None]
    for backend in ("direct", "fft"):
        result = imfilter_conv_replicate(x, k, backend)[0, 0].numpy()
        np.testing.assert_allclose(result, reference, atol=2e-11, rtol=2e-11)


@pytest.mark.parametrize("scale", range(5))
def test_myconv2_matches_literal_matlab_loops(scale):
    rng = np.random.default_rng(2)
    image = rng.normal(size=(32, 32))
    k = 4 * 2 ** scale
    kernel = rng.normal(size=(k, k))
    step = 1 if scale == 0 else int(2 ** scale * 1.5)
    count = math.ceil(((32 - k) / 2 + 1) / step) * 2 + 1
    size = step * (count - 1) + k
    canvas = np.zeros((size, size))
    offset = (size - 32) // 2
    canvas[offset:offset + 32, offset:offset + 32] = image
    starts = list(range(0, size - k + 1, step))
    reference = np.array([[np.sum(canvas[i:i + k, j:j + k] * kernel) for j in starts] for i in starts])
    result = myconv2(torch.from_numpy(image)[None, None], torch.from_numpy(kernel)[None, None], scale, "direct")[0, 0]
    np.testing.assert_allclose(result, reference, rtol=1e-11, atol=1e-11)


def test_fixed_gabor_formula(small_config):
    kernels, metadata = fixed_gabor_bank(small_config)
    y, x = np.mgrid[-3:4, -3:4]
    theta = math.pi / 3
    expected = np.exp(-(x*x+y*y)/(2*small_config.sigma**2)) / (2*math.pi*small_config.sigma**2)
    expected *= np.cos(2*math.pi*small_config.spatial_frequency*(x*np.cos(theta)+y*np.sin(theta)))
    np.testing.assert_allclose(kernels[1], expected, rtol=1e-13, atol=1e-13)
    assert metadata[1]["orientation_deg"] == 60


def test_multiscale_formula(small_config):
    bank = list(multiscale_bank(16, [0, 37], small_config))
    scale, kernels, _ = bank[2]
    y, x = np.mgrid[1:17, 1:17]
    xx, yy = x/4 - (4+.25)/2, y/4 - (4+.25)/2
    theta = np.deg2rad(37)
    rx = xx*np.cos(theta)+yy*np.sin(theta)
    ry = -xx*np.sin(theta)+yy*np.cos(theta)
    kai = np.sqrt(2*np.log(2))*(2**1.5+1)/(2**1.5-1)
    env = .25/np.sqrt(2)*np.exp(-.5*(rx**2+ry**2))
    np.testing.assert_allclose(kernels[1,0], env*(np.cos(kai*rx)-np.exp(-kai*kai/2)), atol=1e-13)
    np.testing.assert_allclose(kernels[3,0], env*np.sin(kai*rx), atol=1e-13)
    assert scale == 2


def test_orientation_matches_numpy_reference():
    image = np.random.default_rng(9).normal(size=(16, 16))
    p = np.array([.037659, .249153, .426375, .249153, .037659])
    d = np.array([.109604, .276691, 0, -.276691, -.109604])
    gx = convolve2d(image, np.outer(p, d), mode="same")
    gy = convolve2d(image, np.outer(d, p), mode="same")
    y, x = np.mgrid[-4:5,-4:5]
    g = np.exp(-(x*x+y*y)/(2*1.5**2)); g /= g.sum()
    gxx = correlate2d(gx**2,g,mode="same")
    gxy = 2*correlate2d(gx*gy,g,mode="same")
    gyy = correlate2d(gy**2,g,mode="same")
    denominator = np.sqrt(gxy**2+(gxx-gyy)**2)+np.finfo(float).eps
    sine = correlate2d(gxy/denominator,g,mode="same")
    cosine = correlate2d((gxx-gyy)/denominator,g,mode="same")
    reference = np.pi/2+np.arctan2(sine,cosine)/2
    result = ridge_orientation(torch.from_numpy(image)[None,None])[0,0]
    np.testing.assert_allclose(result,reference,atol=1e-12,rtol=1e-12)


def test_pca_covariance_and_responses(fitted, images):
    x = fitted.preprocess(images).numpy()[:,0]
    k = 3
    all_patches = []
    for image in x:
        for c in range(14):
            for r in range(14):
                patch = image[r:r+k,c:c+k].reshape(-1,order="F")
                all_patches.append(patch-patch.mean())
    patches = np.stack(all_patches,axis=1)
    covariance = patches@patches.T/patches.shape[1]
    values, vectors = np.linalg.eigh(covariance)
    vectors = vectors[:,-2:][:,::-1]
    weights = fitted.pca_weight.detach().numpy()[:,0]
    learned = np.stack([weight.reshape(-1,order="F") for weight in weights],axis=1)
    np.testing.assert_allclose(learned@learned.T,vectors@vectors.T,atol=1e-11)
    np.testing.assert_allclose(fitted.fit_info["pca_eigenvalues"],values[::-1].clip(min=0),atol=1e-10)
    image = x[0]
    padded = np.pad(image,1)
    expected = np.empty((2,16,16))
    for r in range(16):
        for c in range(16):
            patch = padded[r:r+3,c:c+3]
            for j in range(2):
                expected[j,r,c] = np.sum(weights[j]*(patch-patch.mean()))
    result = fitted.pca_responses(fitted.preprocess([images[0]]))[0]
    np.testing.assert_allclose(result,expected,atol=1e-11)


@pytest.mark.parametrize("overlap", [0., .5])
def test_hashing_matlab_layout_and_normalization(overlap):
    cfg = PalmConfig(pca_filters=2, hist_block_size=(3, 2), block_overlap=overlap)
    codes = np.random.default_rng(3).integers(0,8,(2,2,7,8))
    output = hashing_histogram(torch.from_numpy(codes),3,cfg).to_dense().numpy()
    sy,sx = [int((1-overlap)*b+.5) for b in (3,2)]
    expected=[]
    for example in codes:
        branches=[]
        for image in example:
            blocks=[]
            for c in range(0,8-2+1,sx):
                for r in range(0,7-3+1,sy):
                    blocks.append(np.bincount(image[r:r+3,c:c+2].ravel(),minlength=8)*8/6)
            branches.append(np.stack(blocks,axis=1))
        # Literal equivalent of MATLAB vec([Bhist{:}]').
        expected.append(np.concatenate(branches,axis=1).T.ravel(order="F"))
    np.testing.assert_allclose(output,expected,atol=1e-14)


def test_code_bit_weights(fitted,images):
    x=fitted.preprocess(images[:2])
    first,second=fitted.intermediate_responses(x)
    expected=torch.zeros_like(first,dtype=torch.long)
    for j in range(fitted.num_gabor_filters):
        expected+=(second[:,:,j]>0).long()*2**(fitted.num_gabor_filters-j-1)
    torch.testing.assert_close(fitted.hash_codes(x),expected)


def test_sparse_dimension_default_does_not_allocate_dense():
    cfg=PalmConfig()
    codes=torch.zeros(1,15,128,128,dtype=torch.long)
    features=hashing_histogram(codes,15,cfg)
    assert features.shape==(1,12288000)
    assert features._nnz()==375
    assert features.values().unique().item()==32768


def test_checkpoint_roundtrip_and_batch_equivalence(fitted, images, tmp_path):
    before=fitted.transform(images,batch_size=1)
    checkpoint=tmp_path/'model.pt'
    fitted.save(checkpoint)
    restored=PalmPCAGabor.load(checkpoint,'cpu')
    after=restored.transform(images,batch_size=2)
    assert (before!=after).nnz==0
    assert restored.feature_dimension==fitted.feature_dimension
    assert restored.fit_info==fitted.fit_info


def test_dynamic_pca(small_config,images):
    small_config.retained_variance=.8
    model=PalmPCAGabor(small_config,'cpu').fit(images)
    assert model.fit_info['retained_variance']>=.8
    assert model.num_pca_filters<=9


def test_wavelet_selection_counts(small_config,images):
    angles=np.array([0.,60.,120.])
    kernels,selected,candidates=select_wavelets(images,angles,small_config,16,torch.float64,'cpu')
    assert sum(c['selection_count'] for c in candidates)==len(images)*small_config.num_wavelet_responses
    assert selected[0]['selection_count']==max(c['selection_count'] for c in candidates)
    assert len(kernels)==1


def test_uint8_conversion_and_resize():
    np.testing.assert_array_equal(read_uint8(np.array([[0.,.5,1.]])),[[0,128,255]])
    image=torch.full((19,27),42.,dtype=torch.float64)
    resized=resize_bicubic(image,16)
    torch.testing.assert_close(resized,torch.full((16,16),42.,dtype=torch.float64))
    x=preprocess_batch([np.full((19,27),42,dtype=np.uint8)],16)
    assert x.abs().max()<1e-12
    with pytest.raises(ValueError):
        read_uint8(np.array([[-1.,2.]]))


def test_sparse_distances():
    a=np.array([[0,2,0,4],[1,0,3,4]],dtype=float)
    b=np.array([[1,2,0,0],[0,2,2,3]],dtype=float)
    euclidean=pairwise_distances(sparse.csr_matrix(a),sparse.csr_matrix(b))
    np.testing.assert_allclose(euclidean,np.linalg.norm(a[:,None]-b[None],axis=2))
    chi=pairwise_distances(sparse.csr_matrix(a),sparse.csr_matrix(b),metric='chi2')
    expected=.5*np.sum(np.divide((a[:,None]-b[None])**2,a[:,None]+b[None],out=np.zeros((2,2,4)),where=(a[:,None]+b[None])>0),axis=2)
    np.testing.assert_allclose(chi,expected)


def test_verification_perfect_and_tied():
    metrics,_=verification([1,2],[3,4])
    assert metrics['eer']==0 and metrics['fnmr_at_fmr_0_001']==0
    metrics,_=verification([1,1],[1,1])
    assert metrics['eer']==.5
    with pytest.raises(ValueError):
        verification([], [1])


def test_identification_excludes_self():
    d=np.array([[0,4,1,3],[4,0,3,1],[1,3,0,4],[3,1,4,0]],dtype=float)
    labels=['a','a','b','b']
    metrics,_,pred=evaluate(d,labels)
    assert metrics['accuracy']==0
    assert pred.tolist()==['b','b','a','a']
    assert metrics['genuine_pairs']==2 and metrics['impostor_pairs']==4


def test_person_disjoint_and_gallery_splits(tmp_path):
    records=[Record(tmp_path/f'{i}_{j}.png',str(i)) for i in range(6) for j in range(4)]
    train,test=make_split(records,seed=4)
    assert not ({r.label for r in train}&{r.label for r in test})
    assert len(train)==len(test)==12
    train,test=make_split(records,protocol='gallery-probe',seed=4)
    assert {r.label for r in train}=={r.label for r in test}
    assert not ({r.path for r in train}&{r.path for r in test})


def test_no_silent_aggregation_reference_reuse():
    d=np.zeros((4,4))
    metrics,curves=aggregate_verification(d,['a','a','b','b'],k=4)
    assert metrics['status']=='insufficient_reference_samples'
    assert curves is None


def test_zero_variance_fails(small_config):
    with pytest.raises(ValueError,match='zero variance'):
        PalmPCAGabor(small_config,'cpu').fit([np.zeros((16,16),dtype=np.uint8)])


def test_model_parameters_are_not_trainable(fitted):
    assert list(fitted.parameters())==[]


def test_matlab_import_fixture(fitted, images, tmp_path):
    from scipy.io import savemat
    kernels=np.empty((1,fitted.num_gabor_filters),dtype=object)
    for group in fitted.gabor_groups:
        for i,kernel in zip(group.indices.tolist(),group.weights[:,0]):
            kernels[0,i]=kernel.numpy()
    vectors=np.stack([w.numpy().reshape(-1,order='F') for w in fitted.pca_weight[:,0]],axis=1)
    x=fitted.preprocess(images[:1])
    path=tmp_path/'fixture.mat'
    savemat(path,{'input_image':x[0,0].numpy(),'pca_vectors':vectors,'gabor_kernels':kernels,
                  'hist_block_size':np.array(fitted.config.hist_block_size),'block_overlap':0.,'has_pyramid':0})
    imported=PalmPCAGabor.from_matlab_fixture(path)
    assert (imported(x).to_dense()!=fitted(x).to_dense()).sum()==0


def test_end_to_end_fft_direct_codes(fitted, images):
    x=fitted.preprocess(images[:2])
    fitted.config.convolution_backend='direct'
    direct=fitted.hash_codes(x)
    first,second_direct=fitted.intermediate_responses(x)
    fitted.config.convolution_backend='fft'
    fft=fitted.hash_codes(x)
    _,second_fft=fitted.intermediate_responses(x)
    torch.testing.assert_close(second_direct,second_fft,rtol=1e-10,atol=1e-10)
    torch.testing.assert_close(direct,fft)


def test_repeated_fitting_is_deterministic(small_config, images):
    a=PalmPCAGabor(small_config,'cpu').fit(images)
    b=PalmPCAGabor(small_config,'cpu').fit(images)
    torch.testing.assert_close(a.pca_weight,b.pca_weight,rtol=0,atol=0)
    assert a.gabor_metadata==b.gabor_metadata
    assert (a.transform(images)!=b.transform(images)).nnz==0


def test_flat_filenames_auto_matlab_labels(tmp_path):
    from PIL import Image
    from palmnet.data import write_manifest
    for name in ['0001_0001.bmp','0001_0002.bmp','0002_0001.bmp']:
        Image.fromarray(np.zeros((8,8),dtype=np.uint8)).save(tmp_path/name)
    records=discover(tmp_path)
    assert [r.label for r in records]==['0001','0001','0002']
    assert matlab_identity_from_filename('0012_left_0003.bmp') == '0012left'
    path=tmp_path/'labels.csv'
    write_manifest(path,records)
    assert discover(manifest=path)==records


def test_float32_checkpoint(small_config,images,tmp_path):
    small_config.dtype='float32'
    a=PalmPCAGabor(small_config,'cpu').fit(images)
    path=tmp_path/'float32.pt'
    a.save(path)
    b=PalmPCAGabor.load(path,'cpu')
    assert b.dtype==torch.float32
    assert (a.transform(images)!=b.transform(images)).nnz==0


def test_distance_matching_compresses_unused_feature_columns():
    # The nominal feature width must not force a dense billion-element index.
    wide=sparse.csr_matrix(([2.,3.],([0,1],[7,999_999_999])),shape=(2,1_000_000_000))
    actual=pairwise_distances(wide)
    np.testing.assert_allclose(actual,[[0,np.sqrt(13)],[np.sqrt(13),0]])


def test_empty_tensor_batch_has_clear_error():
    from palmnet.preprocessing import as_image_list
    with pytest.raises(ValueError,match='No input images'):
        as_image_list(torch.empty(0,1,16,16))


def test_matlab_person_fold_keeps_identities_disjoint(tmp_path):
    records=[Record(tmp_path/f'{i:04d}_{j:04d}.bmp',f'{i:04d}') for i in range(1,13) for j in range(1,4)]
    train,test,assignment=make_matlab_person_fold(records,kfold=2,seed=7)
    assert not ({r.label for r in train} & {r.label for r in test})
    assert set(assignment)=={f'{i:04d}' for i in range(1,13)}
    assert all(assignment[r.label] != 1 for r in train)
    assert all(assignment[r.label] == 1 for r in test)


def test_matlab_vl_roc_indexing():
    labels=np.array([1,-1,1,-1])
    scores=np.array([4.,3.,2.,1.])
    tpr,tnr,fpr,fnr,_=matlab_vl_roc(labels,scores)
    np.testing.assert_allclose(tpr,[0,.5,.5,1])
    np.testing.assert_allclose(fpr,[0,0,.5,.5])
    np.testing.assert_allclose(tnr,1-fpr)
    np.testing.assert_allclose(fnr,1-tpr)


def test_matlab_movmax_even_window():
    # k=4 is centered about current and previous: [i-2, i-1, i, i+1].
    x=np.array([1.,4.,2.,3.,8.,0.])
    np.testing.assert_allclose(matlab_movmax(x,4),[4,4,4,8,8,8])


def test_matlab_verification_uses_directed_pairs_and_movmax():
    d=np.array([[0,1,5,6],[1,0,4,7],[5,4,0,2],[6,7,2,0]],dtype=float)
    labels=['0001','0001','0002','0002']
    normal,aggr,curves,aggr_curves=matlab_verification(d,labels,aggregate_k=4)
    assert normal['genuine_pairs']==4  # (0,1),(1,0),(2,3),(3,2)
    assert normal['impostor_pairs']==8
    assert aggr['movmax_window']==4
    assert len(aggr_curves['genuine_similarity_aggregated'])==4


def test_matlab_knn_second_sorted_value_then_first_equal_index():
    d=np.array([[0,4,1,3],[4,0,3,1],[1,3,0,4],[3,1,4,0]],dtype=float)
    labels=['a','a','b','b']
    assert matlab_nearest_neighbor(d,labels).tolist()==['b','b','a','a']


def test_optimized_backend_matches_reference_training(images, small_config):
    ref_cfg = PalmConfig(**small_config.to_dict())
    ref_cfg.execution_backend = 'reference'
    ref_cfg.convolution_backend = 'direct'
    opt_cfg = PalmConfig(**small_config.to_dict())
    opt_cfg.execution_backend = 'optimized'
    opt_cfg.convolution_backend = 'direct'
    opt_cfg.pca_image_batch_size = 3
    opt_cfg.orientation_batch_size = 3
    opt_cfg.gabor_tuning_batch_size = 2
    reference = PalmPCAGabor(ref_cfg, 'cpu').fit(images)
    optimized = PalmPCAGabor(opt_cfg, 'cpu').fit(images)
    # Covariance accumulation order differs, so compare the PCA subspace rather
    # than requiring bit-identical eigenvector coefficients.
    a = reference.pca_weight[:, 0].numpy().reshape(reference.num_pca_filters, -1)
    b = optimized.pca_weight[:, 0].numpy().reshape(optimized.num_pca_filters, -1)
    np.testing.assert_allclose(a.T @ a, b.T @ b, atol=1e-10, rtol=1e-10)
    np.testing.assert_array_equal(reference.fit_info['orientation_counts'], optimized.fit_info['orientation_counts'])
    assert [m['candidate_index'] for m in reference.gabor_metadata if m.get('kind') == 'adaptive'] == \
           [m['candidate_index'] for m in optimized.gabor_metadata if m.get('kind') == 'adaptive']
    assert (reference.transform(images, batch_size=2) != optimized.transform(images, batch_size=2)).nnz == 0


def test_parallel_path_loader_matches_serial(tmp_path, fitted, images):
    from PIL import Image
    paths = []
    for i, image in enumerate(images):
        path = tmp_path / f'{i:04d}_0001.bmp'
        Image.fromarray(image).save(path)
        paths.append(path)
    serial = fitted.transform(paths, batch_size=2, num_workers=0)
    parallel = fitted.transform(paths, batch_size=2, num_workers=2)
    assert (serial != parallel).nnz == 0


def test_fast_precision_keeps_pca_training_double(images, small_config):
    cfg = PalmConfig(**small_config.to_dict())
    cfg.dtype = 'float32'
    cfg.execution_backend = 'optimized'
    model = PalmPCAGabor(cfg, 'cpu').fit(images)
    assert model.dtype == torch.float32
    assert model.fit_info['pca_training_dtype'] == 'float64'
