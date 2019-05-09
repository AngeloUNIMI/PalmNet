# PalmNet

Matlab source code for the paper:

A. Genovese, V. Piuri, K. N. Plataniotis, and F. Scotti,<br/>
"PalmNet: Gabor-PCA Convolutional Networks for Touchless Palmprint Recognition",<br/>
IEEE Transactions on Information Forensics and Security, 2019.<br/>
DOI: 10.1109/TIFS.2019.2911165<br/>
https://ieeexplore.ieee.org/document/8691498
	
Project page:

[http://iebil.di.unimi.it/palmnet/index.htm](http://iebil.di.unimi.it/palmnet/index.htm)
    
Outline:
![Outline](http://iebil.di.unimi.it/palmnet/imgs/outline.jpg "Outline")

Citation:

	@Article{tifs19,
		author = {A. Genovese and V. Piuri and K. N. Plataniotis and F. Scotti},
		title = {PalmNet: Gabor-PCA Convolutional Networks for Touchless Palmprint Recognition},
		journal = {IEEE Transactions on Information Forensics and Security},
		year = {2019},}

Main files:

- launch_PalmNet.m: main file
- ./params/paramsPalmNet.m: parameter file

Required files:

- ./images: Database of images, with filenames in the format "NNNN_SSSS.ext", 
    where NNNN is the 4-digit individual id, SSSS is the 4-digit sample id, and ext is the extension. 
    For example: "0001_0001.bmp" is the first sample of the first individual. 
    In the paper, left and right palms of the same person are considered as different individuals.

Part of the code uses the Matlab source code of the paper:

T. Chan, K. Jia, S. Gao, J. Lu, Z. Zeng and Y. Ma, <br/>
"PCANet: A Simple Deep Learning Baseline for Image Classification?," <br/>
in IEEE Transactions on Image Processing, vol. 24, no. 12, pp. 5017-5032, Dec. 2015.<br/>
DOI: 10.1109/TIP.2015.2475625<br/>
[http://mx.nthu.edu.tw/~tsunghan/Source%20codes.html](http://mx.nthu.edu.tw/~tsunghan/Source%20codes.html)
	
the VLFeat library:

A. Vedaldi and B. Fulkerson, <br/>
"VLFeat: An Open and Portable Library of Computer Vision Algorithms", 2008, <br/>
[http://www.vlfeat.org](http://www.vlfeat.org/)
	
and the functions by Peter Kovesi:

Peter Kovesi, <br/>
"MATLAB and Octave Functions for Computer Vision and Image Processing", <br/>
[https://www.peterkovesi.com/matlabfns](https://www.peterkovesi.com/matlabfns/)
	
The databases used in the paper can be obtained at:

- CASIA:<br/>
http://www.cbsr.ia.ac.cn/english/Palmprint%20Databases.asp
- IITD:<br/>
http://www4.comp.polyu.edu.hk/~csajaykr/IITD/Database_Palm.htm
- REST:<br/>
http://www.regim.org/publications/databases/regim-sfax-tunisian-hand-database2016-rest2016/
- Tongji:<br/>
http://sse.tongji.edu.cn/linzhang/cr3dpalm/cr3dpalm.htm
	
The segmentation algorithm can be found at:

[https://github.com/AngeloUNIMI/PalmSeg](https://github.com/AngeloUNIMI/PalmSeg)
	
